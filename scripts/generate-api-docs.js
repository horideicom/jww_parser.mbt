#!/usr/bin/env node
/**
 * MoonBit API Documentation Generator
 * Generates AGENTS.md compatible API documentation from MoonBit source files
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';
import { parseMbti } from './lib/mbti-parser.js';
import { extractDocstrings, createDocstringMap } from './lib/mbt-docstring.js';
import { generateApiMarkdown, generateUsageExample, appendToAgentsMd } from './lib/markdown-gen.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const rootDir = path.resolve(__dirname, '..');

/**
 * Read a file synchronously
 */
function readFile(filePath) {
  return fs.readFileSync(filePath, 'utf8');
}

/**
 * Find all .mbt files in a directory recursively
 */
function findMbtFiles(dir, excludeDirs) {
  excludeDirs = excludeDirs || ['target', '.mooncakes', 'node_modules'];
  var files = [];

  function traverse(currentDir) {
    try {
      var entries = fs.readdirSync(currentDir, { withFileTypes: true });

      for (var i = 0; i < entries.length; i++) {
        var entry = entries[i];
        var fullPath = path.join(currentDir, entry.name);

        if (entry.isDirectory()) {
          if (excludeDirs.indexOf(entry.name) < 0) {
            traverse(fullPath);
          }
        } else if (entry.isFile() && entry.name.endsWith('.mbt')) {
          // Skip test files
          if (!entry.name.endsWith('_test.mbt') && !entry.name.endsWith('_wbtest.mbt')) {
            files.push(fullPath);
          }
        }
      }
    } catch (e) {
      // Directory may not be readable
    }
  }

  traverse(dir);
  return files;
}

/**
 * Find .mbti files in the build directory
 */
function findMbtiFiles(dir) {
  var files = [];

  function traverse(currentDir) {
    try {
      var entries = fs.readdirSync(currentDir, { withFileTypes: true });

      for (var i = 0; i < entries.length; i++) {
        var entry = entries[i];
        var fullPath = path.join(currentDir, entry.name);

        if (entry.isDirectory()) {
          traverse(fullPath);
        } else if (entry.isFile() && entry.name.endsWith('.mbti')) {
          files.push(fullPath);
        }
      }
    } catch (e) {
      // Directory may not be readable
    }
  }

  traverse(dir);
  return files;
}

/**
 * Merge arrays avoiding duplicates by key
 */
function mergeUnique(arr1, arr2, key) {
  var result = arr1.slice();
  var existingKeys = {};

  for (var i = 0; i < arr1.length; i++) {
    existingKeys[arr1[i][key]] = true;
  }

  for (var j = 0; j < arr2.length; j++) {
    if (!existingKeys[arr2[j][key]]) {
      result.push(arr2[j]);
      existingKeys[arr2[j][key]] = true;
    }
  }

  return result;
}

/**
 * Main generation function
 */
function generate(options) {
  options = options || {};
  var output = options.output !== undefined ? options.output : 'API.md';
  var appendTo = options.appendTo;
  var verbose = options.verbose || false;

  // Step 1: Read moon.pkg.json for exports
  var pkgPath = path.join(rootDir, 'moon.pkg.json');
  var exports = [];

  if (fs.existsSync(pkgPath)) {
    var pkgJson = JSON.parse(readFile(pkgPath));
    exports = pkgJson.link && pkgJson.link.js ? (pkgJson.link.js.exports || []) : [];
    if (verbose) console.log('Found exports: ' + exports.join(', '));
  } else {
    console.warn('Warning: moon.pkg.json not found');
  }

  // Step 2: Parse .mbti files if they exist
  var apiInfo = {
    package: '',
    imports: [],
    functions: [],
    structs: [],
    enums: [],
    typeAliases: [],
    traits: []
  };

  var mbtiFiles = findMbtiFiles(path.join(rootDir, 'target'));
  if (mbtiFiles.length > 0) {
    if (verbose) console.log('Found ' + mbtiFiles.length + ' .mbti files');
    for (var i = 0; i < mbtiFiles.length; i++) {
      var mbtiPath = mbtiFiles[i];
      var mbtiContent = readFile(mbtiPath);
      var parsed = parseMbti(mbtiContent);
      // Merge parsed info (avoiding duplicates)
      apiInfo.package = apiInfo.package || parsed.package;
      apiInfo.functions = mergeUnique(apiInfo.functions, parsed.functions, 'name');
      apiInfo.structs = mergeUnique(apiInfo.structs, parsed.structs, 'name');
      apiInfo.enums = mergeUnique(apiInfo.enums, parsed.enums, 'name');
      apiInfo.typeAliases = mergeUnique(apiInfo.typeAliases, parsed.typeAliases, 'name');
      apiInfo.traits = mergeUnique(apiInfo.traits, parsed.traits, 'name');
    }
  } else {
    if (verbose) console.log('No .mbti files found. Run "moon info" first.');
  }

  // Also check for .mbti files in root and subdirectories
  var rootMbtiFiles = findMbtiFiles(rootDir);
  for (var i = 0; i < rootMbtiFiles.length; i++) {
    if (rootMbtiFiles[i].indexOf('/target/') < 0) {
      var mbtiContent = readFile(rootMbtiFiles[i]);
      var parsed = parseMbti(mbtiContent);
      apiInfo.package = apiInfo.package || parsed.package;
      apiInfo.functions = mergeUnique(apiInfo.functions, parsed.functions, 'name');
      apiInfo.structs = mergeUnique(apiInfo.structs, parsed.structs, 'name');
      apiInfo.enums = mergeUnique(apiInfo.enums, parsed.enums, 'name');
      apiInfo.typeAliases = mergeUnique(apiInfo.typeAliases, parsed.typeAliases, 'name');
      apiInfo.traits = mergeUnique(apiInfo.traits, parsed.traits, 'name');
    }
  }

  // Step 3: Extract docstrings from .mbt files
  var mbtFiles = findMbtFiles(rootDir);
  if (verbose) console.log('Found ' + mbtFiles.length + ' .mbt source files');

  var docstrings = {};
  for (var i = 0; i < mbtFiles.length; i++) {
    var mbtPath = mbtFiles[i];
    var relativePath = mbtPath.replace(rootDir + '/', '');
    var content = readFile(mbtPath);
    var extracted = extractDocstrings(content);

    for (var name in extracted) {
      if (extracted.hasOwnProperty(name)) {
        // Store with relative path as key context
        extracted[name].file = relativePath;
        docstrings[name] = extracted[name];

        // Also store with file prefix
        var moduleName = relativePath.split('/').pop().replace('.mbt', '');
        var prefixedName = moduleName + '/' + name;
        docstrings[prefixedName] = extracted[name];
      }
    }
  }

  // Step 4: Generate Markdown
  var markdown = generateApiMarkdown(apiInfo, createDocstringMap(docstrings), exports, {
    title: 'API Reference',
    includeTypes: true,
    includeInternal: false
  });

  // Step 5: Add usage example
  var usageExample = generateUsageExample(exports);
  var finalMarkdown = markdown + usageExample;

  // Step 6: Write output
  var outputPath = path.join(rootDir, output);

  if (appendTo && fs.existsSync(path.join(rootDir, appendTo))) {
    // Append to existing file
    var existingContent = readFile(path.join(rootDir, appendTo));
    var combined = appendToAgentsMd(existingContent, finalMarkdown);
    fs.writeFileSync(path.join(rootDir, appendTo), combined);
    console.log('Updated ' + appendTo);
  } else {
    // Write to new file
    fs.writeFileSync(outputPath, finalMarkdown);
    console.log('Generated ' + output);
  }

  if (verbose) {
    console.log('  Package: ' + (apiInfo.package || '(unknown)'));
    console.log('  Functions: ' + apiInfo.functions.length);
    console.log('  Structs: ' + apiInfo.structs.length);
    console.log('  Enums: ' + apiInfo.enums.length);
    var docstringCount = Object.keys(docstrings).length;
    console.log('  Docstrings: ' + docstringCount);
  }

  return outputPath;
}

/**
 * CLI entry point
 */
function main() {
  var args = process.argv.slice(2);
  var options = {
    output: 'API.md',
    appendTo: null,
    verbose: false
  };

  for (var i = 0; i < args.length; i++) {
    var arg = args[i];

    if (arg === '-o' || arg === '--output') {
      options.output = args[++i];
    } else if (arg === '-a' || arg === '--append') {
      options.appendTo = args[++i];
    } else if (arg === '-v' || arg === '--verbose') {
      options.verbose = true;
    } else if (arg === '-h' || arg === '--help') {
      console.log('\nUsage: generate-api-docs.js [options]\n');
      console.log('Options:');
      console.log('  -o, --output <file>     Output file (default: API.md)');
      console.log('  -a, --append <file>     Append to existing file instead of overwriting');
      console.log('  -v, --verbose           Verbose output');
      console.log('  -h, --help              Show this help\n');
      console.log('Examples:');
      console.log('  node scripts/generate-api-docs.js');
      console.log('  node scripts/generate-api-docs.js --output docs/API.md');
      console.log('  node scripts/generate-api-docs.js --append AGENTS.md');
      console.log('  node scripts/generate-api-docs.js -v\n');
      process.exit(0);
    }
  }

  try {
    generate(options);
  } catch (e) {
    console.error('Error: ' + e.message);
    process.exit(1);
  }
}

// Run if called directly
main();

export { generate };
