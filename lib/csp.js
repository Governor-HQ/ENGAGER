// Content-Security-Policy builder. The proxy calls this once per request
// with a fresh nonce; Next.js reads the policy from the request header and
// adds the nonce to its own script tags.

export function createNonce() {
  return Buffer.from(crypto.randomUUID()).toString('base64');
}

export function buildCsp(nonce) {
  const isDev = process.env.NODE_ENV === 'development';

  const directives = [
    "default-src 'self'",
    // React refresh needs eval in development only.
    `script-src 'self' 'nonce-${nonce}' 'strict-dynamic'${isDev ? " 'unsafe-eval'" : ''}`,
    "style-src 'self' 'unsafe-inline'",
    "img-src 'self' data:",
    "font-src 'self'",
    "connect-src 'self'",
    "object-src 'none'",
    "base-uri 'self'",
    "form-action 'self'",
    "frame-ancestors 'none'",
  ];

  // Breaks http://localhost in development, so production only.
  if (!isDev) directives.push('upgrade-insecure-requests');

  return directives.join('; ');
}
