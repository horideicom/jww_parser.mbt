/**
 * Markdown generator for MoonBit API documentation
 * Generates AGENTS.md compatible API documentation
 */

/**
 * Format a type string for display
 * @param {string} type - Type string
 * @returns {string} Formatted type
 */
export function formatType(type) {
  if (!type) return 'Unit';

  // Clean up type notation
  return type
    .replace(/@core\./g, '')          // Remove module prefix
    .replace(/@list\./g, 'List[')     // Clean list notation
    .replace(/@[\w.]+\//g, '')        // Remove other module prefixes
    .replace(/</g, '[')               // Generic syntax
    .replace(/>/g, ']');
}

/**
 * Format function signature
 * @param {object} fn - Function object
 * @returns {string} Formatted signature
 */
export function formatFunctionSignature(fn) {
  const params = fn.params.map(function(p) {
    const formattedType = formatType(p.type);
    if (p.name) {
      return p.name + ': ' + formattedType;
    }
    return formattedType;
  }).join(', ');

  const returnType = formatType(fn.returnType);
  return '(' + params + ') -> ' + returnType;
}

/**
 * Generate function documentation
 * @param {object} fn - Function object
 * @param {string} docstring - Docstring content
 * @returns {string} Markdown
 */
export function generateFunctionDoc(fn, docstring) {
  var md = '#### `' + fn.name + formatFunctionSignature(fn) + '`\n\n';

  if (docstring) {
    md += docstring + '\n\n';
  }

  // Parameters
  if (fn.params && fn.params.length > 0) {
    md += '**Parameters:**\n\n';
    md += '| Name | Type | Description |\n';
    md += '|------|------|-------------|\n';
    for (var i = 0; i < fn.params.length; i++) {
      var p = fn.params[i];
      var type = formatType(p.type);
      var name = p.name || '-';
      var labeled = p.labeled ? ' (labeled)' : '';
      md += '| `' + name + labeled + '` | `' + type + '` | |\n';
    }
    md += '\n';
  }

  // Return type
  if (fn.returnType && fn.returnType !== 'Unit') {
    md += '**Returns:**\n\n';
    md += '- `' + formatType(fn.returnType) + '`\n\n';
  }

  return md;
}

/**
 * Generate struct documentation
 * @param {object} struct - Struct object
 * @param {object} docInfo - Docstring info
 * @returns {string} Markdown
 */
export function generateStructDoc(struct, docInfo) {
  var md = '#### `' + struct.name + '`\n\n';

  if (docInfo && docInfo.docstring) {
    md += docInfo.docstring + '\n\n';
  }

  // Fields
  if (struct.fields && struct.fields.length > 0) {
    md += '| Field | Type | Description |\n';
    md += '|-------|------|-------------|\n';
    for (var i = 0; i < struct.fields.length; i++) {
      var field = struct.fields[i];
      var type = formatType(field.type);
      var name = field.name || (struct.isTuple ? '_' + i : '-');

      // Try to get field comment from docInfo
      var comment = '';
      if (docInfo && docInfo.fields) {
        for (var j = 0; j < docInfo.fields.length; j++) {
          if (docInfo.fields[j].field === name) {
            comment = docInfo.fields[j].comment;
            break;
          }
        }
      }

      md += '| `' + name + '` | `' + type + '` | ' + comment + ' |\n';
    }
    md += '\n';
  }

  // Methods
  if (struct.methods && struct.methods.length > 0) {
    md += '**Methods:**\n\n';
    for (var i = 0; i < struct.methods.length; i++) {
      var method = struct.methods[i];
      md += '- `' + method.name + formatFunctionSignature(method) + '`\n';
    }
    md += '\n';
  }

  return md;
}

/**
 * Generate enum documentation
 * @param {object} enum_ - Enum object
 * @param {object} docInfo - Docstring info
 * @returns {string} Markdown
 */
export function generateEnumDoc(enum_, docInfo) {
  var md = '#### `' + enum_.name + '`\n\n';

  if (docInfo && docInfo.docstring) {
    md += docInfo.docstring + '\n\n';
  }

  if (enum_.variants && enum_.variants.length > 0) {
    md += '| Variant | Type | Description |\n';
    md += '|---------|------|-------------|\n';
    for (var i = 0; i < enum_.variants.length; i++) {
      var variant = enum_.variants[i];
      var type = variant.type ? formatType(variant.type) : '-';

      // Try to get variant comment from docInfo
      var comment = '';
      if (docInfo && docInfo.fields) {
        for (var j = 0; j < docInfo.fields.length; j++) {
          if (docInfo.fields[j].variant === variant.name) {
            comment = docInfo.fields[j].comment;
            break;
          }
        }
      }

      md += '| `' + variant.name + '` | `' + type + '` | ' + comment + ' |\n';
    }
    md += '\n';
  }

  return md;
}

/**
 * Generate API documentation Markdown
 * @param {object} apiInfo - Parsed API information from mbti-parser
 * @param {Map} docstrings - Docstrings from mbt-docstring
 * @param {Array} exports - Exported function names from moon.pkg.json
 * @param {object} options - Generation options
 * @returns {string} Complete Markdown documentation
 */
export function generateApiMarkdown(apiInfo, docstrings, exports, options) {
  options = options || {};
  var title = options.title !== undefined ? options.title : 'API Reference';
  var includeTypes = options.includeTypes !== undefined ? options.includeTypes : true;
  var includeInternal = options.includeInternal !== undefined ? options.includeInternal : false;

  var md = '[//]: # (AUTO-GENERATED: Do not edit manually)\n';
  md += '[//]: # (Generated by scripts/generate-api-docs.js)\n\n';

  // Package info
  if (apiInfo.package) {
    md += '**Package:** `' + apiInfo.package + '`\n\n';
  }

  md += '## ' + title + '\n\n';

  // Exported Functions section
  var exportedFunctions = apiInfo.functions.filter(function(fn) {
    return exports.indexOf(fn.name) >= 0;
  });

  if (exportedFunctions.length > 0) {
    md += '### Exported Functions\n\n';
    md += 'The following functions are exported in the JavaScript/Wasm target:\n\n';

    for (var i = 0; i < exportedFunctions.length; i++) {
      var fn = exportedFunctions[i];
      var doc = docstrings.get(fn.name) || docstrings.get('top/' + fn.name);
      var docstring = doc ? doc.docstring : null;
      md += generateFunctionDoc(fn, docstring);
    }
  }

  // Internal Functions (optional)
  if (includeInternal && apiInfo.functions.length > exportedFunctions.length) {
    var internalFunctions = apiInfo.functions.filter(function(fn) {
      return exports.indexOf(fn.name) < 0;
    });

    if (internalFunctions.length > 0) {
      md += '### Internal Functions\n\n';
      for (var i = 0; i < internalFunctions.length; i++) {
        var fn = internalFunctions[i];
        var doc = docstrings.get(fn.name);
        var docstring = doc ? doc.docstring : null;
        md += generateFunctionDoc(fn, docstring);
      }
    }
  }

  // Types section
  if (includeTypes) {
    var hasTypes = apiInfo.structs.length > 0 || apiInfo.enums.length > 0;
    if (hasTypes) {
      md += '### Types\n\n';

      // Structs
      if (apiInfo.structs.length > 0) {
        for (var i = 0; i < apiInfo.structs.length; i++) {
          var struct = apiInfo.structs[i];
          var doc = docstrings.get(struct.name) || docstrings.get('types/' + struct.name);
          md += generateStructDoc(struct, doc);
        }
      }

      // Enums
      if (apiInfo.enums.length > 0) {
        for (var i = 0; i < apiInfo.enums.length; i++) {
          var enum_ = apiInfo.enums[i];
          var doc = docstrings.get(enum_.name) || docstrings.get('types/' + enum_.name);
          md += generateEnumDoc(enum_, doc);
        }
      }
    }
  }

  // Type Aliases section
  if (apiInfo.typeAliases && apiInfo.typeAliases.length > 0) {
    md += '### Type Aliases\n\n';
    for (var i = 0; i < apiInfo.typeAliases.length; i++) {
      var alias = apiInfo.typeAliases[i];
      md += '- `' + alias.name + '` = `' + formatType(alias.type) + '`\n';
    }
    md += '\n';
  }

  return md;
}

/**
 * Append documentation to existing AGENTS.md
 * @param {string} existingContent - Current AGENTS.md content
 * @param {string} newDocs - New API documentation
 * @returns {string} Combined content
 */
export function appendToAgentsMd(existingContent, newDocs) {
  var marker = '## API Reference';

  // If API Reference section exists, replace it
  if (existingContent.indexOf(marker) >= 0) {
    var before = existingContent.split(marker)[0];
    return before + newDocs;
  }

  // Otherwise, append at the end
  return existingContent + '\n\n' + newDocs;
}

/**
 * Generate TypeScript usage example
 * @param {Array} exports - Exported function names
 * @returns {string} Usage example
 */
export function generateUsageExample(exports) {
  var md = '## Usage Example\n\n';
  md += '```typescript\n';
  md += 'import { ' + exports.slice(0, 2).join(', ') + ' } from \'jww-parser\';\n\n';
  md += '// Parse JWW file\n';
  md += 'const fileData = await fetch(\'drawing.jww\').then(r => r.arrayBuffer());\n';
  md += 'const doc = parse(new Uint8Array(fileData));\n\n';
  md += 'console.log(\'Version:\', doc.version);\n';
  md += 'console.log(\'Entities:\', doc.entities.length);\n';
  md += '```\n\n';

  return md;
}
