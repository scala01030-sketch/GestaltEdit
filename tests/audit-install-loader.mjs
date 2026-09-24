import fs from 'node:fs';
import assert from 'node:assert/strict';

// dlsym is also used by Clang's OS-version availability runtime. Permit only
// call sites attributed by the link map to that specific runtime function.
// Unknown call sites, owners or disassembly formats remain blocking failures.
export function auditLoader(linkMap, disassembly, symbols) {
  const objects = new Map();
  const ranges = [];
  let inSymbols = false;
  for (const line of linkMap.split(/\r?\n/)) {
    if (line.startsWith('# Dead Stripped Symbols:')) break;
    if (line.startsWith('# Symbols:')) { inSymbols = true; continue; }
    const object = line.match(/^\[\s*(\d+)\]\s+(.+)$/);
    if (object) objects.set(object[1], object[2]);
    const symbol = inSymbols && line.match(/^(0x[\da-f]+)\s+(0x[\da-f]+)\s+\[\s*(\d+)\]\s+(.+)$/i);
    if (symbol) ranges.push({ start: BigInt(symbol[1]), size: BigInt(symbol[2]), owner: symbol[3], name: symbol[4] });
  }
  let calls = 0;
  for (const line of disassembly.split(/\r?\n/)) {
    if (!line.includes('_dlsym')) continue;
    const call = line.match(/^\s*([\da-f]+)\s+bl\s+.*; symbol stub for: _dlsym\s*$/i);
    assert(call, 'Unrecognized dlsym reference requires review');
    const address = BigInt('0x' + call[1]);
    const owners = ranges.filter(r => address >= r.start && address < r.start + r.size);
    assert.equal(owners.length, 1, 'Missing or ambiguous call-site ownership');
    const owner = owners[0];
    assert.equal(owner.name, '__initializeAvailabilityCheck', 'dlsym call outside approved runtime function');
    assert.match(objects.get(owner.owner) || '', /\/usr\/lib\/clang\/[^/]+\/lib\/darwin\/libclang_rt\.ios\.a\(os_version_check\.c\.o\)$/,
      'dlsym call does not belong to the Clang OS-version runtime');
    calls++;
  }
  if (/\bU\s+_dlsym\s*$/m.test(symbols)) assert(calls > 0, 'dlsym import has no audited call sites');
  return calls;
}

if (process.argv[2] === '--self-test') {
  const map = '[ 1] /Xcode/usr/lib/clang/21/lib/darwin/libclang_rt.ios.a(os_version_check.c.o)\n# Symbols:\n0x1000 0x100 [ 1] __initializeAvailabilityCheck\n';
  const asm = '0000000000001004\tbl\t0x2000 ; symbol stub for: _dlsym';
  const syms = ' U _dlsym\n';
  assert.equal(auditLoader(map, asm, syms), 1);
  assert.equal(auditLoader('', '', ''), 0);
  assert.throws(() => auditLoader(map.replace('os_version_check.c.o', 'unknown.o'), asm, syms));
  assert.throws(() => auditLoader(map.replace('__initializeAvailabilityCheck', '_appCode'), asm, syms));
  assert.throws(() => auditLoader(map, asm.replace('0000000000001004', '0000000000003000'), syms));
  assert.throws(() => auditLoader(map, 'unrecognized _dlsym reference', syms));
  assert.throws(() => auditLoader(map, '', syms));
  assert.throws(() => auditLoader('', asm, syms));
  console.log('PASS: 8 loader-audit positive/negative assertions');
} else {
  const paths = process.argv.slice(2);
  assert.equal(paths.length, 3, 'Expected link map, disassembly and symbol paths');
  const count = auditLoader(...paths.map(path => fs.readFileSync(path, 'utf8')));
  console.log(`PASS: ${count} dlsym call sites belong only to Clang os_version_check.c.o::__initializeAvailabilityCheck`);
}
