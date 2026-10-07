// Pure formatters for references exported by the shipped Dart interfaces.
export function protocolViews(reference) {
  if (reference.schemaVersion !== 1) throw new Error('Unsupported protocol schemaVersion');
  const { http, mcp } = reference.examples;
  const tool = reference.tools.find((item) => item.name === mcp.params.name);
  if (!tool) throw new Error(`Unknown MCP example tool: ${mcp.params.name}`);
  const properties = tool.inputSchema.properties;
  for (const argument of Object.keys(mcp.params.arguments)) {
    if (!Object.hasOwn(properties, argument)) throw new Error(`Unknown MCP argument: ${argument}`);
  }
  for (const required of tool.inputSchema.required ?? []) {
    if (!Object.hasOwn(mcp.params.arguments, required)) throw new Error(`Missing MCP argument: ${required}`);
  }
  const body = JSON.stringify(http.body, null, 2).replaceAll("'", "'\\''");
  return {
    http: [
      `curl -X ${http.method} "$FLUVIE_API_URL${http.path}"`,
      '  -H "Authorization: Bearer $FLUVIE_API_TOKEN"',
      '  -H "Content-Type: application/json"',
      `  --data '${body}'`,
    ].join(' \\\n'),
    mcp: JSON.stringify(mcp, null, 2),
    tools: reference.tools.map((item) => {
      const required = new Set(item.inputSchema.required ?? []);
      const fields = Object.entries(item.inputSchema.properties).map(([name, schema]) =>
        `\`${name}\`${required.has(name) ? ' (required)' : ''}${schema.enum ? `: ${schema.enum.map((value) => `\`${value}\``).join(', ')}` : ''}`);
      return `| \`${item.name}\` | ${fields.join('; ') || 'none'} | ${item.description.replaceAll('|', '\\|')} |`;
    }).join('\n'),
  };
}

export function capabilityViews(reference) {
  if (reference.schemaVersion !== 1) throw new Error('Unsupported capabilities schemaVersion');
  if (!reference.backends?.length) throw new Error('Capabilities need backends');
  const fields = [
    ['Export formats', 'exportModes'], ['Video codecs', 'videoCodecs'],
    ['Pixel formats', 'pixelFormats'], ['Audio', 'audio'],
    ['Owned snapshot host', 'snapshots'], ['Exact clip presentation timing', 'exactClipTiming'],
    ['Target bitrate', 'targetBitRate'], ['CRF control', 'crf'], ['Encoder presets', 'presets'],
  ];
  const rows = fields.map(([label, field]) => `| ${label} | ${reference.backends.map((backend) => {
    const value = backend[field];
    if (typeof value === 'boolean') return value ? 'yes' : 'no';
    if (!Array.isArray(value)) throw new Error(`Missing capability ${backend.backend}.${field}`);
    return value.map((choice) => `\`${choice}\``).join(', ');
  }).join(' | ')} |`);
  return {
    table: `| Capability | ${reference.backends.map((backend) => backend.backend).join(' | ')} |\n` +
      `| --- | ${reference.backends.map(() => '---').join(' | ')} |\n${rows.join('\n')}`,
    notes: reference.backends.map((backend) =>
      `### ${backend.backend}\n\n${backend.notes.map((note) => `- ${note}`).join('\n')}\n\n` +
      `Regression evidence: ${backend.evidence.map((path) => `[${path}](https://github.com/SimonErich/fluvie/blob/main/${path})`).join(', ')}.`).join('\n\n'),
  };
}
