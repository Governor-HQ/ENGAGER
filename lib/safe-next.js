// Only same-site join paths may be used as a post-login destination:
// /join or /join/<code>. No scheme, no //, no backslash, no query string.
const SAFE_NEXT = /^\/join(\/[A-Za-z0-9 %-]{1,60})?$/;

export function safeNext(value) {
  if (typeof value !== 'string') return null;
  return SAFE_NEXT.test(value) ? value : null;
}
