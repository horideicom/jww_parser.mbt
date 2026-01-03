#!/usr/bin/env node
import { execSync } from 'child_process';
import { readFileSync, writeFileSync, existsSync, unlinkSync } from 'fs';
import readline from 'readline';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const rootDir = join(__dirname, '..');

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

  console.log(`\n✓ Logged in as: ${npmUser}`);
  console.log(`📦 Current version: ${currentVersion}`);
  console.log('');

  const newVersion = await ask('Enter new version (e.g., 0.2.0): ');

  if (!newVersion) {
    console.log('❌ No version provided');
    rl.close();
    return;
  }

  console.log('');
  console.log('Release plan:');
  console.log(`  1. Update package.json to ${newVersion}`);
  console.log(`  2. Sync moon.mod.json & examples/package.json`);
  console.log(`  3. Build (moon build → rolldown → types)`);
  console.log(`  4. Update examples/pnpm-lock.yaml (using local tarball)`);
  console.log(`  5. npm publish`);
  console.log(`  6. Git commit, tag, and push`);
  console.log(`  7. Create GitHub Release (optional)`);
  console.log('');

  const confirm = await ask('Continue? (y/N): ');

  if (confirm.toLowerCase() !== 'y') {
    console.log('❌ Cancelled');
    rl.close();
    return;
  }

  try {
    // 1. Update package.json
    if (!runCommand(`pnpm version ${newVersion} --no-git-tag-version`, 'Updating package.json')) {
      throw new Error('Failed to update package.json');
    }

    // 2. Sync moon.mod.json & examples/package.json
    if (!runCommand('node scripts/sync-version.js', 'Syncing moon.mod.json & examples/package.json')) {
      throw new Error('Failed to sync versions');
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

    // 4. Update examples/pnpm-lock.yaml using local tarball
    console.log('\n━━━ Examples Lock Update Phase ━━━');

    const tarballName = `jww-parser-${newVersion}.tgz`;
    const tarballPath = join(rootDir, tarballName);
    const examplesPackagePath = join(rootDir, 'examples', 'package.json');

    // Clean up old tarball if exists
    if (existsSync(tarballPath)) {
      unlinkSync(tarballPath);
    }

    // Create tarball
    if (!runCommand('pnpm pack', `Creating tarball: ${tarballName}`)) {
      throw new Error('Failed to create tarball');
    }

    // Temporarily modify examples/package.json to use local tarball
    const examplesPackageJson = JSON.parse(readFileSync(examplesPackagePath, 'utf8'));
    const originalJwwParserVersion = examplesPackageJson.dependencies['jww-parser'];
    examplesPackageJson.dependencies['jww-parser'] = `file:../${tarballName}`;
    writeFileSync(examplesPackagePath, JSON.stringify(examplesPackageJson, null, 2) + '\n');
    console.log(`  Temporarily set examples/package.json to use file:../${tarballName}`);

    // Update lock file
    if (!runCommand('pnpm install --filter examples', 'Updating examples/pnpm-lock.yaml')) {
      throw new Error('Failed to update examples lock file');
    }

    // Restore examples/package.json to use registry version
    examplesPackageJson.dependencies['jww-parser'] = `^${newVersion}`;
    writeFileSync(examplesPackagePath, JSON.stringify(examplesPackageJson, null, 2) + '\n');
    console.log(`  Restored examples/package.json to use jww-parser@^${newVersion}`);

    // Clean up tarball
    unlinkSync(tarballPath);
    console.log(`  Cleaned up ${tarballName}`);

    // 5. Git commit (version files + lock)
    console.log('\n━━━ Git Phase (Version Files) ━━━');

    if (!runCommand(
      'git add package.json moon.mod.json examples/package.json examples/pnpm-lock.yaml',
      'Staging version files and lock file'
    )) {
      throw new Error('Failed to stage version files');
    }

    if (!runCommand(
      `git commit -m "chore(release): bump version to ${newVersion}"`,
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
    if (npmVersion === newVersion) {
      console.log(`✓ Verified: jww-parser@${newVersion} is live on npm`);
    } else {
      console.log(`⚠ Registry shows ${npmVersion}, expected ${newVersion} (may need time to propagate)`);
    }

    // 6. Git tag + push
    console.log('\n━━━ Git Phase (Tag & Push) ━━━');

    if (!runCommand(`git tag v${newVersion}`, `Creating git tag v${newVersion}`)) {
      throw new Error('Failed to create git tag');
    }

    if (!runCommand('git push', 'Pushing commits to GitHub')) {
      throw new Error('Failed to push commits');
    }

    if (!runCommand(`git push origin v${newVersion}`, 'Pushing git tag')) {
      throw new Error('Failed to push git tag');
    }

    // 7. Create GitHub Release (optional)
    console.log('\n━━━ GitHub Release ━━━');

    const createRelease = await ask('Create GitHub Release? (y/N): ');

    if (createRelease.toLowerCase() === 'y') {
      const releaseCreated = runCommand(
        `gh release create v${newVersion} --generate-notes`,
        'Creating GitHub Release'
      );

      if (!releaseCreated) {
        console.log('');
        console.log('⚠️  GitHub Release creation failed');
        console.log(`   Create manually: https://github.com/f4ah6o/jww_parser.mbt/releases/new?tag=v${newVersion}`);
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
    console.log(`  📦 npm: https://www.npmjs.com/package/jww-parser/v/${newVersion}`);
    console.log(`  🏷️  Tag: v${newVersion}`);
    console.log(`  🔗 Repo: https://github.com/f4ah6o/jww_parser.mbt`);

  } catch (error) {
    console.error('\n❌ Release failed:', error.message);
    console.log('\nRollback suggestions:');
    console.log(`  git tag -d v${newVersion}           # Delete local tag (if created)`);
    console.log(`  git reset --soft HEAD~1             # Undo last commit (if created)`);
    console.log(`  git checkout package.json moon.mod.json examples/package.json`);
    console.log('');
    console.log('If npm publish succeeded, you may need to deprecate the version:');
    console.log(`  npm deprecate jww-parser@${newVersion} "Released in error"`);
  }

  rl.close();
}

main();
