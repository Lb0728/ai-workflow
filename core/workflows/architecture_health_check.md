# Architecture Drift Check

## Purpose

Use this read-only workflow to periodically scan the codebase for architecture drift and identify candidate technical-debt task cards.

This workflow does not modify business code and does not create implementation diffs.

## Inputs

- 当前 Host 暴露的仓库规则与 Company Policy
- Project Local Knowledge 解析出的目标架构、当前状态和进度资料
- Current source tree and recent diffs, if provided by the user

## Scope

Check for:

- Old manager responsibility expansion.
- Controller business orchestration growth.
- Profile / runtime source-of-truth mixing.
- Direct platform or transport access from feature or page layers.
- New parallel state, theme, command, or navigation systems.
- Missing Task Card candidates for recurring high-risk patterns.

## Process

```text
READ RULES
-> SCAN TARGET AREAS
-> MAP DRIFT TO REAL RUNNING CHAINS
-> CLASSIFY RISK
-> PROPOSE TASK CARD CANDIDATES
-> STOP
```

## Output

```text
Owner 摘要
Architecture Drift Findings
Candidate Task Cards
Suggested delivery_level
High-risk alignment needs
Recommended next action
```

## Boundaries

- Do not modify files.
- Do not create task cards unless explicitly requested.
- Do not treat blueprint goals as completed reality.
- Do not recommend large refactors without a verifiable slice.
