/**
 * Auth-gate proxy (Next 16 renamed `middleware.ts` → `proxy.ts`; same API,
 * Node runtime).
 *
 * This is a STUB. It lets everything through and only demonstrates the shape:
 *   - a set of public paths that bypass auth,
 *   - a per-request check that would redirect/401 unauthenticated requests.
 *
 * Wire in your real auth (e.g. a session-cookie check) where marked. Keep the
 * check here — server components read data directly, so the proxy is the gate.
 */

import { NextResponse, type NextRequest } from 'next/server';

// Paths that never require auth.
const PUBLIC_PATHS = ['/login', '/health', '/api/health'];

const STATIC_PREFIXES = ['/_next', '/favicon.ico', '/icons'];

function isPublicPath(pathname: string): boolean {
  return (
    PUBLIC_PATHS.some((p) => pathname === p || pathname.startsWith(p + '/')) ||
    STATIC_PREFIXES.some((p) => pathname === p || pathname.startsWith(p))
  );
}

export function proxy(request: NextRequest): NextResponse {
  const { pathname } = request.nextUrl;

  if (isPublicPath(pathname)) {
    return NextResponse.next();
  }

  // TODO: replace with a real session check, e.g.:
  //   const session = getSessionCookie(request);
  //   if (!session) { ...redirect to /login or return 401 for /api... }
  //
  // Template stub: auth is not enforced yet, so let the request through.
  const authenticated = true;

  if (!authenticated) {
    if (pathname.startsWith('/api/')) {
      return NextResponse.json({ error: 'Authentication required' }, { status: 401 });
    }
    const loginUrl = new URL('/login', request.url);
    loginUrl.searchParams.set('callbackUrl', pathname);
    return NextResponse.redirect(loginUrl);
  }

  return NextResponse.next();
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|.*\\.(?:ico|png|jpg|jpeg|svg|webp|woff2?)$).*)'],
};
