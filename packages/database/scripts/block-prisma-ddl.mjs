#!/usr/bin/env node
const blocked = process.argv[2] ?? "unknown";

console.error(`[BLOCKED] "${blocked}" is disabled.`);
console.error("");
console.error("Schema authority: Alembic (apps/api/alembic).");
console.error("DDL 변경 방법:");
console.error("  cd apps/api");
console.error('  uv run alembic revision --autogenerate -m "your migration"');
console.error("  uv run alembic upgrade head");
console.error("");
console.error("Prisma 동기화:");
console.error("  cd packages/database");
console.error("  pnpm db:sync");
process.exit(1);
