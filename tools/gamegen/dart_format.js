'use strict';

/** Renders a Dart string literal, matching the source file's quoting style
 * (single-quote by default, double-quote when the text contains an
 * apostrophe so it doesn't need escaping). */
function dartString(value) {
  if (value.includes("'") && !value.includes('"')) {
    return `"${value}"`;
  }
  return `'${value.replace(/\\/g, '\\\\').replace(/'/g, "\\'")}'`;
}

function dartList(strings) {
  return `[${strings.map(dartString).join(', ')}]`;
}

module.exports = { dartString, dartList };
