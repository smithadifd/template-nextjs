import { NextResponse } from 'next/server';

/**
 * GET /health — public health check (no auth).
 * Used by the Docker healthcheck and scripts/deploy.sh's health poll.
 *
 * The template returns a static-OK response so it works with no DB/env. In a
 * real app, add a DB connectivity probe (import { getDb } from '@/db') and
 * report degraded/unhealthy accordingly — still returning 200 while the process
 * is up so the load balancer distinguishes "up" from "reachable but degraded".
 */
export async function GET() {
  return NextResponse.json({
    status: 'healthy',
    version: process.env.NEXT_PUBLIC_APP_VERSION ?? 'unknown',
    timestamp: new Date().toISOString(),
  });
}
