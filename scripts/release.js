#!/usr/bin/env node
import { execSync } from 'child_process';
import { readFileSync } from 'fs';
import readline from 'readline';
import { toMooncakesVersion, suggestNextNpmVersion } from './version-utils.js';

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

async function ask(question) {
  return new Promise(resolve => {
    rl.question(question, answer => resolve(answer));
  });
}

function runCommand(cmd, description, options = {}) {
  try {
    console.log(`\n▸ ${description}`);
    execSync(cmd, { stdio: 'inherit', ...options });
    return true;
  } catch (error) {
    console.error(`❌ ${description} failed:`, error.message);
    return false;
  }
}

function runCommandSilent(cmd) {
  try {
    return execSync(cmd, { encoding: 'utf8' }).trim();
  } catch {
    return null;
  }
}

async function main() {
  // Check if npm login is configured
  const npmUser = runCommandSilent('npm whoami');
  if (!npmUser) {
    console.error('❌ npm login required');
    console.error('Please run: npm login');
    rl.close();
    process.exit(1);
  }

  const packageJson = JSON.parse(readFileSync('package.json', 'utf8'));
  const currentVersion = packageJson.version;
  const suggestedVersion = suggestNextNpmVersion();
  const suggestedMooncakesVersion = toMooncakesVersion(suggestedVersion);
  const currentMooncakesVersion = toMooncakesVersion(currentVersion);

  console.log(`\n✓ Logged in as: ${npmUser}`);
  console.log(`📦 Current version: ${currentVersion} (npm), ${currentMooncakesVersion} (mooncakes)`);
  console.log(`📅 Suggested next version: ${suggestedVersion} (npm), ${suggestedMooncakesVersion} (mooncakes)`);
  console.log('');

  let versionToUse = await ask(`Enter new version (default: ${suggestedVersion}): `);

  versionToUse = versionToUse || suggestedVersion;

  if (!versionToUse) {
    console.log('❌ No version provided');
    rl.close();
    return;
  }

  const mooncakesVersion = toMooncakesVersion(versionToUse);

  console.log('');
  console.log('Release plan:');
  console.log(`  1. Update package.json to ${versionToUse}`);
  console.log(`  2. Update moon.mod.json to ${mooncakesVersion}`);
  console.log(`  3. Sync examples/package.json`);
  console.log(`  4. Build (moon build → rolldown → types)`);
  console.log(`  5. npm publish`);
  console.log(`  6. Update examples/pnpm-lock.yaml`);
  console.log(`  7. Git commit, tag, and push`);
  console.log(`  8. Create GitHub Release (optional)`);
  console.log('');

  const confirm = await ask('Continue? (y/N): ');

  if (confirm.toLowerCase() !== 'y') {
    console.log('❌ Cancelled');
    rl.close();
    return;
  }

  try {
    // 1. Update package.json, moon.mod.json & examples/package.json
    if (!runCommand(`node scripts/sync-version.js ${versionToUse}`, 'Updating version files')) {
      throw new Error('Failed to update version files');
    }

    // 3. Build
    console.log('\n━━━ Build Phase ━━━');

    if (!runCommand('pnpm run build', 'Building package (moon → rolldown → types)')) {
      throw new Error('Build failed');
    }

    // Verify build outputs
    const requiredFiles = ['dist/index.mjs', 'dist/index.cjs', 'dist/index.d.ts'];
    for (const file of requiredFiles) {
      try {
        readFileSync(file);
      } catch {
        throw new Error(`Build verification failed: ${file} not found`);
      }
    }
    console.log('✓ Build outputs verified');

    // 4. Git commit (version files)
    console.log('\n━━━ Git Phase (Version Files) ━━━');

    if (!runCommand(
      'git add package.json moon.mod.json examples/package.json',
      'Staging version files'
    )) {
      throw new Error('Failed to stage version files');
    }

    if (!runCommand(
      `git commit -m "chore(release): bump version to ${versionToUse}"`,
      'Creating git commit for version bump'
    )) {
      throw new Error('Failed to create git commit');
    }

    // 5. npm publish
    console.log('\n━━━ Publish Phase ━━━');

    if (!runCommand('pnpm publish --otp $(op item get "npmjs" --otp)', 'Publishing to npm')) {
      throw new Error('npm publish failed');
    }

    // Verify publish
    console.log('\n▸ Verifying npm publish...');
    await new Promise(resolve => setTimeout(resolve, 3000)); // Wait for registry
    const npmVersion = runCommandSilent(`npm view jww-parser version`);
    if (npmVersion === versionToUse) {
      console.log(`✓ Verified: jww-parser@${versionToUse} is live on npm`);
    } else {
      console.log(`⚠ Registry shows ${npmVersion}, expected ${versionToUse} (may need time to propagate)`);
    }

    // 6. Update examples/pnpm-lock.yaml
    console.log('\n━━━ Examples Update Phase ━━━');

    if (!runCommand('pnpm install --filter examples', 'Updating examples/pnpm-lock.yaml')) {
      console.log('⚠ Failed to update examples lock file (continuing anyway)');
    }

    // 7. Git commit (lock file) + tag + push
    console.log('\n━━━ Git Phase (Tag & Push) ━━━');

    // Check if lock file changed
    const lockChanged = runCommandSilent('git diff --name-only examples/pnpm-lock.yaml');
    if (lockChanged) {
      if (!runCommand(
        'git add examples/pnpm-lock.yaml',
        'Staging examples/pnpm-lock.yaml'
      )) {
        throw new Error('Failed to stage lock file');
      }

      if (!runCommand(
        `git commit -m "chore(release): update examples lock file for ${versionToUse}"`,
        'Creating git commit for lock file'
      )) {
        throw new Error('Failed to create git commit for lock file');
      }
    }

    if (!runCommand(`git tag v${versionToUse}`, `Creating git tag v${versionToUse}`)) {
      throw new Error('Failed to create git tag');
    }

    if (!runCommand('git push', 'Pushing commits to GitHub')) {
      throw new Error('Failed to push commits');
    }

    if (!runCommand(`git push origin v${versionToUse}`, 'Pushing git tag')) {
      throw new Error('Failed to push git tag');
    }

    // 7. Create GitHub Release (optional)
    console.log('\n━━━ GitHub Release ━━━');

    const createRelease = await ask('Create GitHub Release? (y/N): ');

    if (createRelease.toLowerCase() === 'y') {
      const releaseCreated = runCommand(
        `gh release create v${versionToUse} --generate-notes`,
        'Creating GitHub Release'
      );

      if (!releaseCreated) {
        console.log('');
        console.log('⚠️  GitHub Release creation failed');
        console.log(`   Create manually: https://github.com/f4ah6o/jww_parser.mbt/releases/new?tag=v${versionToUse}`);
      }
    } else {
      console.log('Skipping GitHub Release creation');
    }

    // Success summary
    console.log('');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('✅ Release complete!');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('');
    console.log('Published:');
    console.log(`  📦 npm: https://www.npmjs.com/package/jww-parser/v/${versionToUse}`);
    console.log(`  🏷️  Tag: v${versionToUse}`);
    console.log(`  🔗 Repo: https://github.com/f4ah6o/jww_parser.mbt`);

  } catch (error) {
    console.error('\n❌ Release failed:', error.message);
    console.log('\nRollback suggestions:');
    console.log(`  git tag -d v${versionToUse}           # Delete local tag (if created)`);
    console.log(`  git reset --soft HEAD~1             # Undo last commit (if created)`);
    console.log(`  git checkout package.json moon.mod.json examples/package.json`);
    console.log('');
    console.log('If npm publish succeeded, you may need to deprecate the version:');
    console.log(`  npm deprecate jww-parser@${versionToUse} "Released in error"`);
  }

  rl.close();
}

main();
