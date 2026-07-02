import { defineConfig } from 'vitest/config';
import path from 'path';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    // Pin the timezone so any test that evaluates server-local time is
    // deterministic across dev machines and CI (GitHub runners are UTC).
    env: { TZ: 'UTC' },
    include: ['test/**/*.test.ts', 'src/**/*.test.ts'],
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
});
