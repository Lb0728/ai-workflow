# Distribution Boundary

A distribution manifest declares exactly what an installable Workflow package
contains. The canonical generic example is `distribution/example.yaml`.

## How to customize

1. Copy `example.yaml` to `distribution/<your-id>.yaml`.
2. Adjust `supported.project_adapters` and `include.project_adapters` to your
   own Project Adapter(s). Adapters live under `adapters/<id>/` and are
   auto-detected from each consumer project via `project-profile.yaml`.
3. Validate before packaging:

```bash
LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
  ./tool/ai_distribution_check.sh \
    --manifest <your-id> \
    --role developer
```

4. Build the archive from a committed and clean source:

```bash
LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
  ./tool/ai_distribution_package.sh \
    --project-root /path/to/validation-project \
    --distribution <your-id> \
    --role developer \
    --output-dir /path/to/output
```

## What a package never contains

- `.git` history;
- Runtime task instances, states, handoffs, closeouts or defects (the archive
  ships an empty Runtime seed; each consumer project gets its own
  `.ai-runtime/`);
- personal absolute paths, local logs, generated prompts, account identifiers,
  tokens, API keys or secrets.

Two projects using the same extracted package therefore never share task
cards, evidence, handoffs or defect instances.
