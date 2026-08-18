# Company Security Policy

- Never store or report tokens, passwords, API keys, private keys or account
  credentials.
- Never include production data, complete source, unredacted logs, device
  identifiers or personal absolute paths in Workflow feedback or packages.
- Feedback commands use an allowlist of fields rather than copying arbitrary
  files or logs.
- Existing secrets remain in their normal secret mechanism and are never
  migrated into Project Profile, Runtime or `ai.lock`.
- A sensitive-information ownership conflict returns `STOP`.
