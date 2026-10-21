import test from 'node:test';
import assert from 'node:assert/strict';
import { safeNext } from '../lib/safe-next.js';

test('accepts same-site join paths', () => {
  for (const ok of ['/join', '/join/K7M29QXB', '/join/k7m2%209qxb', '/join/k7m2-9qxb']) {
    assert.equal(safeNext(ok), ok);
  }
});

test('rejects everything else', () => {
  const bad = [
    'https://evil.test', '//evil.test', '/dashboard', '/join/../x', '/join?x=1', '/join#x',
    '/join/a/b', '/join/', '\\join', '/join\\x', '/\\evil.test', '', null, undefined, 42,
    `/join/${'A'.repeat(61)}`,
  ];
  for (const value of bad) assert.equal(safeNext(value), null, String(value));
});
