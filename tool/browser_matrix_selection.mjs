export const browserNames = ['chrome', 'firefox', 'webkit-linux'];

// An empty or misspelled filter must fail rather than report a zero-engine pass.
export function selectBrowsers(filter) {
  if (filter === undefined) return [...browserNames];
  const requested = filter.split(',').map(name => name.trim());
  if (requested.some(name => !browserNames.includes(name))) {
    throw Error(`FLUVIE_BROWSERS must contain only: ${browserNames.join(', ')}; received ${JSON.stringify(filter)}`);
  }
  return [...new Set(requested)];
}
