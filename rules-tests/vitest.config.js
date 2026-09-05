import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    // Every file shares one emulator and clears it between tests, so they
    // must not run at the same time.
    fileParallelism: false,
    // Emulator round-trips are slower than unit tests.
    testTimeout: 15000,
    hookTimeout: 30000,
  },
});
