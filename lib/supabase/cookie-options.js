// Flags forced onto every Supabase auth cookie. Supabase's own options
// (maxAge, expires, etc.) are kept; these override only what they set.
const FORCED_COOKIE_OPTIONS = {
  httpOnly: true,
  sameSite: 'lax',
  path: '/',
  secure: process.env.NODE_ENV === 'production',
};

export function withSecureCookieOptions(options) {
  return { ...options, ...FORCED_COOKIE_OPTIONS };
}
