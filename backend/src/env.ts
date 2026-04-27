import { existsSync } from "node:fs";
import path from "node:path";
import { config } from "dotenv";

let loaded = false;

export const loadEnv = (): void => {
  if (loaded) {
    return;
  }

  const candidates = [
    process.env.DOTENV_CONFIG_PATH,
    path.resolve(process.cwd(), ".env"),
    path.resolve(import.meta.dir, "../.env"),
    path.resolve(import.meta.dir, "../../.env"),
  ].filter((value): value is string => Boolean(value));

  for (const envPath of candidates) {
    if (!existsSync(envPath)) {
      continue;
    }

    config({ path: envPath, override: false });
  }

  loaded = true;
};
