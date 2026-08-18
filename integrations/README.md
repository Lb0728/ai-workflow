# Client Integrations

Client Integrations are thin installation and persistent-rule entries for supported AI coding clients. They do not own Router rules, Agent logic, Project facts, Role behavior or Runtime history.

The reusable Skill source remains `skills/`. The installer links that same source into the client-specific Skill directory and installs only the minimal persistent rule required by that client.

Supported clients:

- `codex`
- `cursor`
- `claude-code`
