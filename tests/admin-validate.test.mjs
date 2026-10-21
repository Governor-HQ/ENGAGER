import test from 'node:test';
import assert from 'node:assert/strict';
import { isUuid, cleanName, mapDbError, MESSAGES } from '../app/admin/validate.js';

test('isUuid accepts real ids and rejects look-alikes', () => {
  assert.equal(isUuid('00000000-0000-4000-8000-00000000a001'), true);
  for (const bad of ['', 'g1', "1'; drop table groups;--", '00000000-0000-4000-8000-0000000000a00', null, 7]) {
    assert.equal(isUuid(bad), false, String(bad));
  }
});

test('cleanName trims and enforces 1 to 80 characters', () => {
  assert.deepEqual(cleanName('  Group B  '), { value: 'Group B' });
  assert.ok(cleanName('   ').error);
  assert.ok(cleanName(undefined).error);
  assert.deepEqual(cleanName('x'.repeat(80)), { value: 'x'.repeat(80) });
  assert.ok(cleanName('x'.repeat(81)).error);
});

test('mapDbError gives friendly text and flags unexpected errors', () => {
  assert.equal(mapDbError({ code: '42501' }).message, MESSAGES.notAdmin);
  assert.equal(mapDbError({ code: '23505' }).message, MESSAGES.duplicateGroup);
  assert.equal(mapDbError({ code: 'P0002' }).message, MESSAGES.notFound);
  assert.equal(mapDbError({ code: '22023', message: 'Source and target group are the same' }).message, MESSAGES.sameGroup);
  assert.equal(mapDbError({ code: '22023', message: 'Admin accounts cannot be group members' }).message, MESSAGES.adminMember);
  assert.equal(mapDbError({ code: '22023', message: 'something else' }).message, MESSAGES.badInput);
  assert.deepEqual(mapDbError({ code: 'XX000' }), { message: MESSAGES.generic, unexpected: true });
  assert.deepEqual(mapDbError(null), { message: MESSAGES.generic, unexpected: true });
});
