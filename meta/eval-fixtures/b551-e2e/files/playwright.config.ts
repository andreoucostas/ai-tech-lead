import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: 'e2e',
  reporter: 'list',
  retries: 0,
  use: {
    baseURL: 'http://localhost:4300',
    actionTimeout: 5000,
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
  webServer: [
    {
      command: 'node api/server.mjs',
      url: 'http://localhost:4301/health',
      reuseExistingServer: !process.env.CI,
    },
    {
      command: 'npm run start -- --port 4300',
      url: 'http://localhost:4300',
      timeout: 180000,
      reuseExistingServer: !process.env.CI,
    },
  ],
});
