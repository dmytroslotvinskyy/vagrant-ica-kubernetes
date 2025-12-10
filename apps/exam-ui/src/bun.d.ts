/// <reference types="bun-types" />

// Bun global types are provided by bun-types
// This file ensures TypeScript recognizes Bun's global API

declare global {
  const Bun: typeof import("bun");
}

export {};

