import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["test/**/*.test.ts"],

    // These share one Firestore emulator and clear it between tests, so they
    // cannot run at the same time — the same reason rules-tests serialises.
    fileParallelism: false,
    sequence: { concurrent: false },
  },
});
