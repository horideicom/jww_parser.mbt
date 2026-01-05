/**
 * MoonBit .mbt file docstring extractor
 * Extracts documentation comments from MoonBit source files
 */

/**
 * Extract docstrings from .mbt file content
 * @param {string} content - .mbt file content
 * @returns {Map} Map of docstrings keyed by name
 */
export function extractDocstrings(content) {
  var result = {};

  // Split by block separator ///|
  var blocks = content.split('///|');

  for (var i = 0; i < blocks.length; i++) {
    var block = blocks[i];
    var lines = block.split('\n').map(function(l) { return l.trimEnd(); });
    var docLines = [];
    var targetName = null;
    var targetType = null;
    var fieldComments = [];

    for (var j = 0; j < lines.length; j++) {
      var line = lines[j];
      var trimmed = line.trim();

      // Collect docstring lines
      if (trimmed.indexOf('///') === 0) {
        var docText = trimmed.replace(/^\/\/\/\s*/, '');
        docLines.push(docText);
        continue;
      }

      // Empty line within docstring
      if (docLines.length > 0 && trimmed === '') {
        docLines.push('');
        continue;
      }

      // Look for definitions after docstrings
      if (docLines.length > 0) {
        // pub fn name(...)
        var fnMatch = trimmed.match(/^pub\s+fn\s+(\w+)/);
        if (fnMatch) {
          targetName = fnMatch[1];
          targetType = 'function';
          break;
        }

        // pub struct Name
        var structMatch = trimmed.match(/^pub\s+struct\s+(\w+)/);
        if (structMatch) {
          targetName = structMatch[1];
          targetType = 'struct';
          // Collect field comments for structs
          extractFieldComments(lines.slice(j), fieldComments);
          break;
        }

        // pub enum Name
        var enumMatch = trimmed.match(/^pub\s+enum\s+(\w+)/);
        if (enumMatch) {
          targetName = enumMatch[1];
          targetType = 'enum';
          // Collect variant comments for enums
          extractVariantComments(lines.slice(j), fieldComments);
          break;
        }

        // pub type alias
        var typeMatch = trimmed.match(/^pub\s+type/);
        if (typeMatch) {
          targetName = 'type_' + Math.random().toString(36).substr(2, 9);
          targetType = 'type';
          break;
        }
      }
    }

    if (targetName && docLines.length > 0) {
      // Remove trailing empty lines
      while (docLines.length > 0 && docLines[docLines.length - 1] === '') {
        docLines.pop();
      }

      result[targetName] = {
        name: targetName,
        type: targetType,
        docstring: docLines.join('\n'),
        fields: fieldComments
      };
    }
  }

  return result;
}

/**
 * Extract field comments from struct definition
 * @param {string[]} lines - Lines to search
 * @param {Array} fieldComments - Array to populate
 */
function extractFieldComments(lines, fieldComments) {
  for (var i = 0; i < lines.length; i++) {
    var trimmed = lines[i].trim();

    // Stop at closing brace or end of struct
    if (trimmed === '}' || trimmed.indexOf('} derive') === 0) {
      break;
    }

    // Field comment: /// comment
    if (trimmed.indexOf('///') === 0) {
      var comment = trimmed.replace(/^\/\/\/\s*/, '');
      // Peek at next non-comment line to get field name
      continue;
    }

    // Field definition: name : Type
    var fieldMatch = trimmed.match(/^(\w+)\s*:/);
    if (fieldMatch && fieldComments.length > 0) {
      // Associate with previous comment if exists
      var fieldName = fieldMatch[1];
      var lastComment = fieldComments[fieldComments.length - 1];
      if (lastComment && !lastComment.field) {
        lastComment.field = fieldName;
      }
    }

    // Check for inline comment
    var inlineMatch = trimmed.match(/^(\w+)\s*:\s+\w+\s*\/\/\s*(.+)$/);
    if (inlineMatch) {
      fieldComments.push({
        field: inlineMatch[1],
        comment: inlineMatch[2]
      });
    }
  }
}

/**
 * Extract variant comments from enum definition
 * @param {string[]} lines - Lines to search
 * @param {Array} variantComments - Array to populate
 */
function extractVariantComments(lines, variantComments) {
  for (var i = 0; i < lines.length; i++) {
    var trimmed = lines[i].trim();

    // Stop at closing brace
    if (trimmed === '}' || trimmed.indexOf('} derive') === 0) {
      break;
    }

    // Variant comment: /// comment
    if (trimmed.indexOf('///') === 0) {
      var comment = trimmed.replace(/^\/\/\/\s*/, '');
      variantComments.push({ comment: comment });
      continue;
    }

    // Variant definition: Name or Name(Type)
    var variantMatch = trimmed.match(/^(\w+)(?:\s*\(|,|$)/);
    if (variantMatch && variantComments.length > 0) {
      var lastComment = variantComments[variantComments.length - 1];
      if (lastComment && !lastComment.variant) {
        lastComment.variant = variantMatch[1];
      }
    }
  }
}

/**
 * Get docstring for a specific name
 * @param {object} docstrings - Docstrings object
 * @param {string} name - Name to look up
 * @returns {string|null} Docstring or null
 */
export function getDocstring(docstrings, name) {
  var info = docstrings[name];
  if (!info) {
    return null;
  }
  return info.docstring;
}

/**
 * Get field comment for a struct field
 * @param {object} docstrings - Docstrings object
 * @param {string} structName - Struct name
 * @param {string} fieldName - Field name
 * @returns {string|null} Field comment or null
 */
export function getFieldComment(docstrings, structName, fieldName) {
  var info = docstrings[structName];
  if (!info || !info.fields) {
    return null;
  }
  for (var i = 0; i < info.fields.length; i++) {
    if (info.fields[i].field === fieldName) {
      return info.fields[i].comment;
    }
  }
  return null;
}

/**
 * Create a Map-like object from docstrings for compatibility
 * @param {object} docstrings - Docstrings object
 * @returns {object} Map-like object with get method
 */
export function createDocstringMap(docstrings) {
  return {
    _data: docstrings,
    get: function(key) {
      return this._data[key];
    },
    has: function(key) {
      return this._data.hasOwnProperty(key);
    }
  };
}
