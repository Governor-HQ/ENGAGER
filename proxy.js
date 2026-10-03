import { createServerClient } from '@supabase/ssr';
import { NextResponse } from 'next/server';
import { withSecureCookieOptions } from './lib/supabase/cookie-options';
import { buildCsp, createNonce } from './lib/csp';

const AUTH_PAGES = ['/login', '/signup'];

// Refreshes the Supabase session cookie on every request, redirects between
// the auth pages and the dashboard, and sets a per-request CSP nonce.
export async function proxy(request) {
  const csp = buildCsp(createNonce());
  // Next.js reads the nonce from the request header and applies it to its scripts.
  request.headers.set('Content-Security-Policy', csp);

  let response = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
          response = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, withSecureCookieOptions(options))
          );
        },
      },
    }
  );

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { pathname } = request.nextUrl;
  const isAuthPage = AUTH_PAGES.includes(pathname);

  let redirectTo = null;
  if (!user && !isAuthPage) redirectTo = '/login';
  if (user && (isAuthPage || pathname === '/')) redirectTo = '/dashboard';

  if (redirectTo) {
    const redirect = NextResponse.redirect(new URL(redirectTo, request.url));
    // Keep any refreshed session cookies on the redirect.
    response.cookies.getAll().forEach((cookie) => redirect.cookies.set(cookie));
    redirect.headers.set('Content-Security-Policy', csp);
    return redirect;
  }

  response.headers.set('Content-Security-Policy', csp);
  return response;
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico|opengraph-image|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico)$).*)'],
};
