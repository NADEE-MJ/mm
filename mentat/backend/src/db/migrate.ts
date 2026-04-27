// Standalone migration script for manual use (e.g. CI / pre-deploy checks).
// The application also runs migrations automatically at startup via db/index.ts.
import { db } from "./index";

console.log("Migrations applied");
void db; // importing db triggers migrations via the migrate() call in index.ts
