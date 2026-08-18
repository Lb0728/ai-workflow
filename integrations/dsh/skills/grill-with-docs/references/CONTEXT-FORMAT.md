# CONTEXT.md Format

`CONTEXT.md` is the repository shared-language dictionary.

Use it for:

- Durable domain terms.
- Stable definitions that will be reused across tasks.
- Names that prevent repeated explanation or model-based guesswork.

Do not use it for:

- File names, function names, or implementation details.
- A task summary or change log.
- One-off API parameters.
- Unconfirmed proposals.
- Chat transcripts.

Entry format:

```md
**Term**: One stable sentence.
_Avoid_: Names that should not be used as formal terminology.
```

Example:

```md
**Device Capability**: A functional ability a device supports and that determines behavior.
_Avoid_: Generation-Specific Logic, Model-Based Rule
```
