import { defineConfig, devices } from '@playwright/test';

const port = Number(process.env.ADMIN_E2E_PORT ?? 3101);
const baseURL = process.env.ADMIN_E2E_BASE_URL ?? `http://127.0.0.1:${port}`;

export default defineConfig({
  testDir: './e2e',
  fullyParallel: false,
  timeout: 30_000,
  expect: {
    timeout: 10_000,
  },
  reporter: process.env.CI ? [['github'], ['html', { open: 'never' }]] : 'list',
  use: {
    baseURL,
    trace: 'on-first-retry',
  },
  webServer: {
    command: `pnpm dev --hostname 127.0.0.1 --port ${port}`,
    url: baseURL,
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
    env: {
      ADMIN_E2E_AUTH_BYPASS: '1',
      NEXT_PUBLIC_FASTAPI_URL: 'https://api.e2e.test',
      NEXT_PUBLIC_SUPABASE_ANON_KEY: 'e2e-anon-key',
      NEXT_PUBLIC_SUPABASE_URL: 'https://example.supabase.co',
    },
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
});
