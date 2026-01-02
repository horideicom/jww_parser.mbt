/**
 * MoonBit .mbti interface file parser
 * Parses the generated interface files to extract API information
 */

/**
 * Parse .mbti file content
 * @param {string} content - .mbti file content
 * @returns {object} Parsed API information
 */
function parseMbti(content) {
  var result = {
    package: '',
    imports: [],
    functions: [],
    structs: [],
    enums: [],
    typeAliases: [],
    traits: []
  };

  var lines = content.split('\n');
  var currentSection = null;
  var currentStruct = null;
  var currentEnum = null;

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim();

    // Package declaration
    var pkgMatch = line.match(/^package\s+"([^"]+)"/);
    if (pkgMatch) {
      result.package = pkgMatch[1];
      continue;
    }

    // Import section
    if (line === 'import(') {
      currentSection = 'import';
      continue;
    }
    if (currentSection === 'import' && line === ')') {
      currentSection = null;
      continue;
    }
    if (currentSection === 'import' && line.indexOf('"') === 0) {
      var importMatch = line.match(/^"([^"]+)"/);
      if (importMatch) {
        result.imports.push(importMatch[1]);
      }
      continue;
    }

    // Section headers
    if (line === '// Values') {
      currentSection = 'values';
      continue;
    }
    if (line === '// Types and methods') {
      currentSection = 'types';
      continue;
    }
    if (line === '// Errors') {
      currentSection = 'errors';
      continue;
    }
    if (line === '// Type aliases') {
      currentSection = 'aliases';
      continue;
    }
    if (line === '// Traits') {
      currentSection = 'traits';
      continue;
    }

    // Comments and empty lines
    if (line === '' || line.indexOf('//') === 0) {
      continue;
    }

    // Deprecated annotation
    if (line === '#deprecated') {
      continue;
    }

    // Function definitions
    var fnMatch = line.match(/^(?:pub\s+)?fn\s+(?:([\w:]+)\s*::\s*)?(\w+)\s*\(([^)]*)\)\s*(?:->\s*(.+))?/);
    if (fnMatch) {
      var typeName = fnMatch[1];
      var fnName = fnMatch[2];
      var params = fnMatch[3];
      var returnType = fnMatch[4];

      if (typeName) {
        // Method: fn TypeName::method(...)
        if (currentStruct) {
          currentStruct.methods.push({
            name: fnName,
            fullName: typeName + '::' + fnName,
            params: parseParams(params),
            returnType: returnType || 'Unit'
          });
        }
      } else {
        // Top-level function
        result.functions.push({
          name: fnName,
          params: parseParams(params),
          returnType: returnType || 'Unit'
        });
      }
      continue;
    }

    // Struct definitions: pub struct Name {
    var structStartMatch = line.match(/^(?:pub\(all\)\s+)?pub\s+struct\s+(\w+)\s*\{?$/);
    if (structStartMatch) {
      var name = structStartMatch[1];
      // Collect multi-line struct definition
      var fieldsStr = '';
      var braceCount = line.indexOf('{') >= 0 ? 1 : 0;
      var j = i + 1;

      if (braceCount === 0) {
        // Opening brace on next line
        while (j < lines.length && braceCount === 0) {
          var nextLine = lines[j].trim();
          if (nextLine === '') {
            j++;
            continue;
          }
          if (nextLine.indexOf('{') >= 0) {
            braceCount++;
            if (nextLine.indexOf('}') >= 0) {
              braceCount--; // Both on same line
            }
            fieldsStr += nextLine + '\n';
          }
          j++;
        }
      }

      // Read until closing brace
      while (j < lines.length && braceCount > 0) {
        var nextLine = lines[j];
        fieldsStr += nextLine + '\n';

        // Count braces
        for (var k = 0; k < nextLine.length; k++) {
          if (nextLine[k] === '{') braceCount++;
          if (nextLine[k] === '}') braceCount--;
        }

        j++;
        i = j - 1; // Update main loop index
      }

      currentStruct = {
        name: name,
        fields: parseFields(fieldsStr),
        methods: []
      };
      result.structs.push(currentStruct);
      continue;
    }

    // Enum definitions: pub enum Name {
    var enumStartMatch = line.match(/^(?:pub\(all\)\s+)?pub\s+enum\s+(\w+)\s*\{?$/);
    if (enumStartMatch) {
      var enumName = enumStartMatch[1];
      // Collect multi-line enum definition
      var variantsStr = '';
      var braceCount = line.indexOf('{') >= 0 ? 1 : 0;
      var j = i + 1;

      if (braceCount === 0) {
        while (j < lines.length && braceCount === 0) {
          var nextLine = lines[j].trim();
          if (nextLine === '') {
            j++;
            continue;
          }
          if (nextLine.indexOf('{') >= 0) {
            braceCount++;
            if (nextLine.indexOf('}') >= 0) {
              braceCount--;
            }
            variantsStr += nextLine + '\n';
          }
          j++;
        }
      }

      while (j < lines.length && braceCount > 0) {
        var nextLine = lines[j];
        variantsStr += nextLine + '\n';

        for (var k = 0; k < nextLine.length; k++) {
          if (nextLine[k] === '{') braceCount++;
          if (nextLine[k] === '}') braceCount--;
        }

        j++;
        i = j - 1;
      }

      currentEnum = {
        name: enumName,
        variants: parseEnumVariants(variantsStr)
      };
      result.enums.push(currentEnum);
      continue;
    }

    // Type aliases
    var aliasMatch = line.match(/^pub\s+typealias\s+(.+)\s+as\s+(\w+)/);
    if (aliasMatch && currentSection === 'aliases') {
      result.typeAliases.push({
        name: aliasMatch[2],
        type: aliasMatch[1]
      });
      continue;
    }

    // Type declarations (without pub(all))
    var typeMatch = line.match(/^type\s+(\w)/);
    if (typeMatch && currentSection === 'errors') {
      result.types = result.types || [];
      result.types.push({ name: typeMatch[1] });
      continue;
    }

    // Trait definitions
    var traitMatch = line.match(/^pub\(open\)\s+trait\s+(\w+)\s*\{([^}]*)\}/);
    if (traitMatch) {
      result.traits.push({
        name: traitMatch[1],
        methods: parseTraitMethods(traitMatch[2])
      });
      continue;
    }

    // Impl declarations
    var implMatch = line.match(/^impl\s+(.+)\s+for\s+(\w+)/);
    if (implMatch) {
      // Store implementation info if needed
      continue;
    }
  }

  return result;
}

/**
 * Parse function parameters
 * @param {string} paramsStr - Parameter string
 * @returns {Array} Parsed parameters
 */
function parseParams(paramsStr) {
  if (!paramsStr || paramsStr.trim() === '') {
    return [];
  }

  var params = [];
  var parts = paramsStr.split(',').map(function(p) { return p.trim(); });

  for (var i = 0; i < parts.length; i++) {
    var part = parts[i];
    if (!part) continue;

    // Named parameter: name : Type
    var namedMatch = part.match(/^(\w+)\s*:\s*(.+)$/);
    if (namedMatch) {
      params.push({
        name: namedMatch[1],
        type: namedMatch[2],
        labeled: false
      });
      continue;
    }

    // Labeled parameter: name~ : Type
    var labeledMatch = part.match(/^(\w+)~\s*:\s*(.+)$/);
    if (labeledMatch) {
      params.push({
        name: labeledMatch[1],
        type: labeledMatch[2],
        labeled: true
      });
      continue;
    }

    // Anonymous parameter (just type)
    params.push({
      name: null,
      type: part,
      labeled: false
    });
  }

  return params;
}

/**
 * Parse struct fields
 * @param {string} fieldsStr - Fields string (multi-line)
 * @returns {Array} Parsed fields
 */
function parseFields(fieldsStr) {
  if (!fieldsStr || fieldsStr.trim() === '' || fieldsStr.trim() === '...') {
    return [];
  }

  var fields = [];
  var lines = fieldsStr.split('\n');

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim();
    if (!line || line === '{' || line === '}' || line.indexOf('//') === 0) continue;

    // Remove trailing braces or commas
    line = line.replace(/[\},].*$/, '');

    // Skip empty lines after cleanup
    if (!line || line === '...') continue;

    // Field: name : Type
    var fieldMatch = line.match(/^(\w+)\s*:\s+(.+)$/);
    if (fieldMatch) {
      fields.push({
        name: fieldMatch[1],
        type: fieldMatch[2].trim()
      });
    }
  }

  return fields;
}

/**
 * Parse enum variants
 * @param {string} variantsStr - Variants string (multi-line)
 * @returns {Array} Parsed variants
 */
function parseEnumVariants(variantsStr) {
  if (!variantsStr || variantsStr.trim() === '') {
    return [];
  }

  var variants = [];
  var lines = variantsStr.split('\n');

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim();
    if (!line || line === '{' || line === '}' || line.indexOf('//') === 0) continue;

    // Remove trailing braces or commas
    line = line.replace(/[\},].*$/, '');

    // Skip empty lines after cleanup
    if (!line) continue;

    // Variant with type: Name(Type)
    var typedMatch = line.match(/^(\w+)\s*\((.+)\)$/);
    if (typedMatch) {
      variants.push({
        name: typedMatch[1],
        type: typedMatch[2]
      });
      continue;
    }

    // Simple variant: just name
    if (line.match(/^\w+$/)) {
      variants.push({
        name: line,
        type: null
      });
    }
  }

  return variants;
}

/**
 * Parse trait methods
 * @param {string} methodsStr - Methods string
 * @returns {Array} Parsed methods
 */
function parseTraitMethods(methodsStr) {
  if (!methodsStr || methodsStr.trim() === '') {
    return [];
  }

  var methods = [];
  var methodLines = methodsStr.split('\n');

  for (var i = 0; i < methodLines.length; i++) {
    var trimmed = methodLines[i].trim();
    if (!trimmed || trimmed.indexOf('//') === 0) continue;

    // Method signature: fn name(...) -> Type
    var fnMatch = trimmed.match(/^fn\s+(\w+)\s*\(([^)]*)\)\s*(?:->\s*(.+))?/);
    if (fnMatch) {
      methods.push({
        name: fnMatch[1],
        params: parseParams(fnMatch[2]),
        returnType: fnMatch[3] || 'Unit'
      });
    }
  }

  return methods;
}

module.exports = {
  parseMbti: parseMbti
};
