import { afterEach, describe, expect, it, vi } from 'vitest';
import { GET } from '@/app/health/route';

const fixedTime = '2026-01-02T03:04:05.000Z';

afterEach(() => {
  vi.useRealTimers();
  vi.unstubAllEnvs();
});

describe('GET /health', () => {
  it('returns a healthy response with the fallback version and an ISO timestamp', async () => {
    vi.stubEnv('NEXT_PUBLIC_APP_VERSION', undefined);
    vi.useFakeTimers();
    vi.setSystemTime(new Date(fixedTime));

    const response = await GET();

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({
      status: 'healthy',
      version: 'unknown',
      timestamp: fixedTime,
    });
  });

  it('returns the configured version', async () => {
    vi.stubEnv('NEXT_PUBLIC_APP_VERSION', '1.2.3');

    const response = await GET();

    expect(response.status).toBe(200);
    expect((await response.json()).version).toBe('1.2.3');
  });
});
