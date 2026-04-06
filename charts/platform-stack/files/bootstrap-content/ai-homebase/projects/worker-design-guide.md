# Worker Agent Design Guide

## What Is a Worker Agent

A worker agent is a bottom-layer execution unit in the layered agent architecture. Workers run cheap models (GPT-5.4 Nano or Mini), follow strict predefined workflows, and escalate when they encounter ambiguity. They are designed to amortize the intelligence of top-layer agents across many cheap, repeated executions.

## Who Designs Workers

The architect is the sole author of worker agent definitions. Main requests a worker design when the user identifies a recurring need. The auditor reviews worker definitions before instantiation when the worker handles sensitive data, financial operations, or external communications.

## Promotion Principle

Repeated LLM work should move down the cost and determinism ladder over time:

- first, a high-judgment agent does the work manually;
- then, if the pattern repeats, architect defines a worker agent;
- later, if the workflow is stable and highly structured, it should be promoted again into deterministic software such as a Kubernetes `CronJob`, service, or controller implemented by `coder`.

Workers are therefore not the end state for mature repetitive workflows. They are often the transition stage between frontier-agent reasoning and ordinary software.

## Worker Definition Package

Every worker must be fully specified before instantiation. The architect produces a definition package containing:

### 1. Execution Plan
- Step-by-step workflow with explicit inputs, outputs, and tool calls
- Decision rules with no ambiguous branches
- Error conditions and escalation triggers
- What to do when input is missing or malformed

### 2. Reference Documentation
- Templates, schemas, formatting rules
- Domain-specific constraints and examples
- Validation criteria

### 3. Schedule
- Cron expression for recurring tasks, or heartbeat interval
- Whether the worker responds to user triggers or runs autonomously

### 4. Model Selection
- Nano: purely procedural tasks with no variance
- Mini: light conditional logic or tool chaining

### 5. Escalation Rules
- Workers always escalate to main
- Standard triggers: rule gaps, unexpected input, tool failures
- Domain-specific triggers defined per worker

## How Workers Are Instantiated

1. Architect produces the definition package and writes it to `/Projects/<project-slug>/workers/<worker-id>/` in Nextcloud.
2. If risk-triggered review is warranted, main routes the definition to auditor.
3. Main instantiates the worker at runtime:
   a. Create the workspace directory (e.g., `~/.openclaw/workspace-<worker-id>`).
   b. Write the workspace files (AGENTS.md, SOUL.md, IDENTITY.md, MEMORY.md, TOOLS.md, HEARTBEAT.md, USER.md) by filling in the worker template placeholders with values from the architect's definition package.
   c. Run `openclaw agents add <worker-id> --workspace ~/.openclaw/workspace-<worker-id> --model <model-id>` to register the agent.
   d. Update `/Projects/ai-homebase/budget-policy.md` if the new worker changes the expected ongoing LLM spend posture.
   e. If the worker needs a cron schedule, configure it with `openclaw cron add`.
4. Main confirms to the user that the worker is active.

To decommission a worker:
1. Remove its cron schedule with `openclaw cron remove` (if any).
2. Run `openclaw agents delete <worker-id>`.
3. Update `/Projects/ai-homebase/budget-policy.md` if the removal changes expected ongoing spend.
4. Announce to the user.

## Worker Behavior Invariants

Workers must:
- Follow instructions deterministically
- Avoid interpretation or creativity
- Request missing inputs via escalation to main
- Escalate to main for complex decisions, design changes, and ambiguity

Workers must NOT:
- Redesign their own workflows
- Generate strategy or make creative decisions
- Improvise structure or output formats
- Store memories unless their execution plan explicitly requires it
- Contact agents other than main

## Template Location

The worker workspace template is at `charts/openclaw/files/workspaces/worker-template/` in the ai-homebase repo. Main uses this as a reference when creating workspace files for new workers — it is not deployed as a live agent workspace.
