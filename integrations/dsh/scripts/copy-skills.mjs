/**
 * Copy the canonical AI Workflow skills from the repository root (skills/)
 * into this bundle's packaged skill directory (integrations/dsh/skills/).
 *
 * The canonical sources stay the repository's own skills/; this script only
 * materializes them for npm packaging, and `prepack` keeps the copy in sync
 * at publish time.
 *
 * Only the SHIPPED list is managed: each entry is refreshed from the
 * repository. The `ai-workflow` meta skill is authored inside this bundle
 * (BUNDLE_OWNED) and is never removed or overwritten by this script.
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

// The meta skill authored inside this bundle; never removed by the sync.
const BUNDLE_OWNED = ["ai-workflow"];

await mkdir(BUNDLE_SKILLS, { recursive: true });

for (const skill of SHIPPED) {
	const target = join(BUNDLE_SKILLS, skill);
	await rm(target, { recursive: true, force: true });
	await cp(join(REPO_SKILLS, skill), target, { recursive: true });
}

const entries = await readdir(BUNDLE_SKILLS);
const unexpected = entries.filter(
	(skill) => !SHIPPED.includes(skill) && !BUNDLE_OWNED.includes(skill),
);
if (unexpected.length > 0) {
	throw new Error(`unexpected skill entries: ${unexpected.join(", ")}`);
}

console.log(
	`synced ${SHIPPED.length} canonical skills; ${entries.length} total skill dirs in ${BUNDLE_SKILLS}`,
);
