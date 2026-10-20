// Pure helpers for the admin screens. No imports, so they are easy to test.

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function isUuid(value) {
  return typeof value === 'string' && UUID_RE.test(value);
}

// Trims, then requires 1 to 80 characters. Returns { value } or { error }.
export function cleanName(raw) {
  const value = typeof raw === 'string' ? raw.trim() : '';
  if (value.length === 0) return { error: 'Please enter a name.' };
  if (value.length > 80) return { error: 'Names can be at most 80 characters.' };
  return { value };
}

export const MESSAGES = {
  notAdmin: 'Only the admin can do that.',
  duplicateGroup: 'That group name is already used in this classroom.',
  notFound: 'That person or group was not found.',
  sessionExpired: 'Your session has expired. Please log in again.',
  badInput: 'Something was missing or not valid. Reload the page and try again.',
  sameGroup: 'Pick a different group to move them to.',
  adminMember: 'Admin accounts cannot be group members.',
  generic: 'Something went wrong, try again.',
};

// Maps a Postgres error from supabase-js to friendly text.
// Returns { message, unexpected }. unexpected is true when the caller should log it.
export function mapDbError(error) {
  const code = error && error.code;
  const text = String((error && error.message) || '');
  if (code === '42501') return { message: MESSAGES.notAdmin, unexpected: false };
  if (code === '23505') return { message: MESSAGES.duplicateGroup, unexpected: false };
  if (code === 'P0002') return { message: MESSAGES.notFound, unexpected: false };
  if (code === '22023') {
    if (/same/i.test(text)) return { message: MESSAGES.sameGroup, unexpected: false };
    if (/admin/i.test(text)) return { message: MESSAGES.adminMember, unexpected: false };
    return { message: MESSAGES.badInput, unexpected: false };
  }
  return { message: MESSAGES.generic, unexpected: true };
}
