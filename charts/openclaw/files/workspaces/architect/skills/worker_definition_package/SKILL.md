---
name: worker_definition_package
description: Use when architect is defining a recurring worker workflow. Covers the required package fields, output structure, safety boundaries, and when auditor review is required.
---

# Worker Definition Package

Architect is the sole author of worker definition packages.

## Required Package Content

Every worker package must specify:
- purpose and scope
- exact execution steps
- tool usage by surface
- inputs and outputs
- escalation conditions
- schedule or trigger mode
- model tier

## Procedure

1. Define the worker's narrow job and stopping conditions.
2. Make the execution plan concrete enough that the worker does not need to improvise.
3. Explicitly separate:
   - local workspace operations
   - Nextcloud operations
   - Qdrant operations, if any
4. Document exactly when the worker escalates to main.
5. Write the package into durable Nextcloud project docs.
6. If the workflow touches sensitive data, external communication, financial actions, destructive operations, or real-world automation, require auditor review before return.

## Output Shape

- concise package title
- role and trigger
- exact execution plan
- escalation rules
- model tier and budget posture

When returning the result through main, use:

```markdown
## Handoff Complete
**Task:** <brief restatement>
**Status:** <complete | partial - needs X | blocked - needs Y>

### Deliverables
- <what was produced and where it lives>
- Nextcloud: <paths updated>
- Qdrant: <memories stored>

### For the user
<user-facing summary>

### Follow-up needed
<remaining work and owner>
```
