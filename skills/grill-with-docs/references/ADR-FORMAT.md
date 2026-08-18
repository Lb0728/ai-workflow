# ADR Format

Create an ADR only when all are true:

1. The decision is hard to reverse.
2. Future readers would not understand the reason from code alone.
3. There were real alternatives or tradeoffs.

Path:

```text
docs/adr/NNNN-kebab-case-title.md
```

Template:

```md
# Decision title

## Context
- Current problem and real constraints.

## Decision
- Confirmed decision.

## Consequences
- Benefits.
- Boundaries or future constraints.

## Alternatives considered
- 1-3 real alternatives that were considered.
```

Keep ADRs short. Do not use ADRs as task logs, PRDs, or implementation notes.
