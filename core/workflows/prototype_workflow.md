# Prototype Workflow

## Purpose

Use this workflow when a small throwaway prototype can answer a design, state-machine, UI interaction, or capability-composition question before production implementation.

Prototype output is evidence for decisions, not production code.

## Suitable Cases

- Device capability combinations are unclear.
- A state machine has multiple branches and needs simulation.
- A UI interaction direction needs comparison before implementation.
- A data transformation rule needs fast validation.

## Process

```text
QUESTION
-> PROTOTYPE SCOPE
-> THROWAWAY IMPLEMENTATION
-> OBSERVE RESULT
-> DECISION / OPEN QUESTIONS
-> DISCARD OR ARCHIVE AS EVIDENCE
```

## Rules

- Keep the prototype outside production code paths unless the user explicitly asks otherwise.
- Do not wire prototype code into production business logic.
- Do not use prototype assumptions as confirmed facts.
- If a prototype answers a high-risk device or protocol question, still enter `ALIGNMENT_PENDING` before implementation.

## Output

```text
Question answered
Prototype location
Observed result
Decision supported
Remaining uncertainty
Recommended next step
```
