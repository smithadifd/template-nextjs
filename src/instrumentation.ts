/**
 * Next.js instrumentation hook — runs once on server startup (Node runtime).
 *
 * Two boot responsibilities:
 *   1. Apply pending DB migrations (prod-gated, see src/db/migrate.ts).
 *   2. Register + start scheduled background tasks (node-cron), but only when
 *      the scheduler is enabled — off in dev unless ENABLE_SCHEDULER=true.
 *
 * The dynamic imports keep server-only modules out of the edge/build bundle.
 */

export async function register() {
  if (process.env.NEXT_RUNTIME !== 'nodejs') return;

  const { env } = await import('@/config/env');
  const { runMigrations } = await import('@/db/migrate');

  // 1. Migrations (no-op outside production).
  runMigrations();

  // 2. Scheduler — enabled in production, or in dev when ENABLE_SCHEDULER=true.
  const schedulerEnabled = env.NODE_ENV === 'production' || env.ENABLE_SCHEDULER;
  if (!schedulerEnabled) {
    console.log('[instrumentation] scheduler disabled (set ENABLE_SCHEDULER=true to enable in dev)');
    return;
  }

  // TODO: register your cron tasks here. Example shape:
  //
  //   const cron = await import('node-cron');
  //   cron.schedule('0 * * * *', async () => {
  //     const { runHourlyJob } = await import('@/jobs/hourly');
  //     await runHourlyJob();
  //   });
  //
  // Add `node-cron` (and `@types/node-cron`) to package.json when you wire this up.
  console.log('[instrumentation] scheduler enabled — register cron tasks here');
}
