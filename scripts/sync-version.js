#!/usr/bin/env node
import { readFileSync, writeFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { toMooncakesVersion } from './version-utils.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const rootDir = join(__dirname, '..');

// Read package.json
const packagePath = join(rootDir, 'package.json');
const packageJson = JSON.parse(readFileSync(packagePath, 'utf8'));

// Get version from argument or package.json
const argVersion = process.argv[2];
const npmVersion = argVersion || packageJson.version;

// Update package.json if version argument provided
if (argVersion) {
  packageJson.version = argVersion;
  writeFileSync(packagePath, JSON.stringify(packageJson, null, 2) + '\n');
}

// Read moon.mod.json
const moonModPath = join(rootDir, 'moon.mod.json');
const moonModJson = JSON.parse(readFileSync(moonModPath, 'utf8'));

// Read examples/package.json
const examplesPackagePath = join(rootDir, 'examples', 'package.json');
const examplesPackageJson = JSON.parse(readFileSync(examplesPackagePath, 'utf8'));

// Convert npm version to mooncakes version for moon.mod.json
const mooncakesVersion = toMooncakesVersion(npmVersion);

// Update versions
moonModJson.version = mooncakesVersion;
examplesPackageJson.dependencies['jww-parser'] = `^${npmVersion}`;

// Write back
writeFileSync(moonModPath, JSON.stringify(moonModJson, null, 2) + '\n');
writeFileSync(examplesPackagePath, JSON.stringify(examplesPackageJson, null, 2) + '\n');

console.log(`Synced versions:`);
console.log(`   - package.json: ${npmVersion}`);
console.log(`   - moon.mod.json: ${mooncakesVersion}`);
console.log(`   - examples/package.json: ^${npmVersion}`);
