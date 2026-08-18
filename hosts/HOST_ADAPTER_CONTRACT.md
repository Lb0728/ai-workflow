# Host Adapter Contract

## Purpose

A Host Adapter connects the Host-neutral Workflow Core to one AI coding host.
It is intentionally thin.

## Required responsibilities

Every Host Adapter declares:

1. how the host discovers persistent repository guidance;
2. how the host discovers reusable Skills;
3. available file, Shell, Git and test capabilities;
4. permission and human-confirmation behavior;
5. how unified `STAY`, `ADVANCE`, `RETURN`, `ESCALATE`, `STOP` and `COMPLETE`
   results are presented;
6. an entry template that points to canonical V2 sources without copying them.
7. assemble only Router-selected `required_context` within `context_budget`;
   Router bootstrap receives the Project Profile and bounded knowledge index.

## Prohibited responsibilities

A Host Adapter must not:

- redefine L1, L2 or L3;
- redefine Skills or Agents;
- redefine STOP or Gate semantics;
- own Company Policy;
- own project facts;
- own Runtime evidence;
- copy Core behavior into host-specific rules.
- infer task relevance by loading every Project Local Knowledge file.

## Manifest requirements

Each `hosts/<host>/host.yaml` declares:

```text
schema_version
host.id
host.display_name
instruction_entry
skill_locations
capabilities
permission_model
state_presentation
semantic_ownership
```

`instruction_entry` additionally declares:

```text
filename
template
instructions_template
install_mode
verification_marker
discovery_scope
```

`install_mode` is a generic installer capability such as `managed_block` or
`managed_file`; it is not selected by checking a concrete Host id.

`skill_locations` declares the repository discovery path, canonical source
owner and optional Host presentation metadata. A Host with no presentation
metadata leaves `metadata_owner` and `metadata_target` empty.

Host manifests and adapters must not declare a model provider, model id or
model-routing rule. Model selection belongs entirely to the Host and is opaque
to Workflow Core.

## Adapter validation

A Host Adapter passes only when:

- removing it requires no Core file change;
- its entry contains references, not copied Core policy;
- its permission mapping cannot bypass immutable constraints;
- its Skill installation uses the canonical Skill source;
- Host-specific Skill presentation metadata stays in the Host Adapter;
- the same Core task produces the same unified state result through the Host.
