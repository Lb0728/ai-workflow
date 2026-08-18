/**
 * Copy the canonical AI Workflow skills from the repository root (skills/)
 * into this bundle's packaged skill directory (integrations/dsh/skills/).
 *
 * The canonical sources stay the repository's own skills/; this script only
 * materializes them for npm packaging, and `prepack` keeps the copy in sync
 * at publish time.
 */

import { cp, mkdir, readdir, rm } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO_SKILLS = join(HERE, "..", "..", "..", "skills");
const BUNDLE_SKILLS = join(HERE, "..", "skills");

const SHIPPED = [
	"grill-me",
	"grill-with-docs",
	"to-prd",
	"to-task-cards",
	"handoff",
];

await rm(BUNDLE_SKILLS, { recursive: true, force: true });
await mkdir(BUNDLE_SKILLS, { recursive: true });

for (const skill of SHIPPED) {
	const source = join(REPO_SKILLS, skill);
	await cp(source, join(BUNDLE_SKILLS, skill), { recursive: true });
}

const leftovers = (await readdir(BUNDLE_SKILLS)).filter(
	(skill) => !SHIPPED.includes(skill),
);
if (leftovers.length > 0) {
	throw new Error(`unexpected skill entries: ${leftovers.join(", ")}`);
}

console.log(`copied ${SHIPPED.length} skills into ${BUNDLE_SKILLS}`);
