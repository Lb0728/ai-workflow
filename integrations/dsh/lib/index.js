/**
 * AI Workflow dsh bundle plugin.
 *
 * A Cordis plugin that registers a packaged skill provider on `ctx.skills`.
 * The provider exposes the skills shipped under ../skills (relative to this
 * module), so a profile gains the AI Workflow skills without touching the
 * filesystem skill roots or the user's own patch layer.
 *
 * Skill format follows the DSH filesystem provider contract: a directory
 * holding SKILL.md whose YAML frontmatter declares `name` and `description`
 * (kebab-case name; model and user invocation are enabled by default).
 *
 * The provider is lazy: nothing is read until the skill service asks for
 * candidates, and skill bodies are read only when a skill is loaded.
 */

import { readFile, readdir } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

export const name = "ai-workflow";

const SKILLS_ROOT = join(dirname(fileURLToPath(import.meta.url)), "..", "skills");
const PROVIDER_NAME = "ai-workflow";
const RANK = 50; // below the user's own local roots, above nothing else

/** Minimal frontmatter reader: `key: value` lines between `---` fences. */
function parseSkillMeta(text) {
	const front = /^---\r?\n([\s\S]*?)\r?\n---/.exec(text);
	if (front === null) return;
	const meta = {};
	for (const line of front[1].split(/\r?\n/)) {
		const match = /^([A-Za-z0-9-]+):[ \t]*(.*)$/.exec(line);
		if (match !== null) {
			meta[match[1]] = match[2].replace(/^['"]|['"]$/g, "");
		}
	}
	return meta;
}

function summary(meta, path, directory) {
	return {
		name: meta.name,
		description: meta.description,
		...(meta.whenToUse !== undefined ? { whenToUse: meta.whenToUse } : {}),
		invocation: {
			modelInvocable: meta["disable-model-invocation"] !== "true",
			userInvocable: meta["user-invocable"] !== "false",
		},
		provider: PROVIDER_NAME,
		source: "bundled",
		rank: RANK,
		locator: { path, directory },
		resourceBase: { kind: "directory", path: directory },
		path,
	};
}

async function loadSkill(path) {
	let text;
	try {
		text = await readFile(path, "utf8");
	} catch {
		return;
	}
	const meta = parseSkillMeta(text);
	if (meta === undefined || meta.name === undefined || meta.description === undefined) {
		return;
	}
	const body = text.replace(/^---\r?\n[\s\S]*?\r?\n---\r?\n?/, "").trim();
	return { meta, body };
}

export function apply(ctx) {
	ctx.skills.registerProvider(() => ({
		name: PROVIDER_NAME,
		async candidates() {
			const candidates = [];
			let entries;
			try {
				entries = await readdir(SKILLS_ROOT, { withFileTypes: true });
			} catch {
				return { candidates, complete: true };
			}
			for (const entry of entries) {
				if (!entry.isDirectory()) continue;
				const directory = join(SKILLS_ROOT, entry.name);
				const path = join(directory, "SKILL.md");
				const loaded = await loadSkill(path);
				if (loaded === undefined) continue;
				candidates.push(summary(loaded.meta, path, directory));
			}
			return { candidates, complete: true };
		},
		async get(candidate) {
			const loaded = await loadSkill(candidate.locator.path);
			if (loaded === undefined) return;
			return {
				...summary(loaded.meta, candidate.locator.path, candidate.locator.directory),
				content: loaded.body,
			};
		},
	}));
}
