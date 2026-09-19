import fs from 'node:fs';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';

const source = fs.readFileSync('GestaltEdit/GestaltAccess.m', 'utf8').replace(/\r/g, '');
const start = source.indexOf('    if (![self connectWithError:error]) return NO;', source.indexOf('- (BOOL)saveGestalt:'));
const end = source.indexOf('\n}\n', start);
const writer = source.slice(start, end).replace(/\n#endif$/, '');
// Original bca57fd save body: serialization, inode write, fallback and verification.
assert.equal(crypto.createHash('sha256').update(writer).digest('hex'),
  '633438f74c651d8fe9361df90a1dd8d055da1d225345b15b890b62699a1c4268');
console.log('PASS: original MobileGestalt write algorithm hash unchanged');
const automation = fs.readFileSync('GestaltEdit/AutomationCommand.swift', 'utf8');
assert(automation.indexOf('guard GestaltAccess.areWritesEnabled()') < automation.indexOf('try access.connect()'));
const view = fs.readFileSync('GestaltEdit/ContentView.swift', 'utf8');
assert(!view.includes('.task { viewModel.load() }'));
assert(!view.includes('.refreshable { viewModel.load() }'));
assert(view.includes('if !GestaltAccess.isReadOnlyProbeBuild() { viewModel.load() }'));
const model = fs.readFileSync('GestaltEdit/GestaltViewModel.swift', 'utf8');
const save = model.slice(model.indexOf('    private func save('));
assert(save.indexOf('guard GestaltAccess.areWritesEnabled()') < save.indexOf('try access.readGestaltData()'));
assert(model.includes('guard !GestaltAccess.isReadOnlyProbeBuild() || plist != nil'));
const project = fs.readFileSync('GestaltEdit.xcodeproj/project.pbxproj', 'utf8');
assert.equal((project.match(/PRODUCT_BUNDLE_IDENTIFIER = me\.ssus\.gestaltedit\.readonlyprobe;/g) || []).length, 2);
assert(!project.includes('PRODUCT_BUNDLE_IDENTIFIER = me.ssus.gestaltedit;'));
const release = fs.readFileSync('.github/workflows/release-unsigned.yml', 'utf8');
assert(release.includes("if: github.repository == 'frs0n/GestaltEdit'"));
console.log('PASS: source regression assertions for UI/automation/identity/release gates');
