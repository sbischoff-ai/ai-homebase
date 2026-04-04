# Worker Agent Design Guide

## What Is a Worker Agent

A worker agent is a bottom-layer execution unit in the layered agent architecture. Workers run cheap models (GPT-5.4 Nano or Mini), follow strict predefined workflows, and escalate when they encounter ambiguity. They are designed to amortize the intelligence of top-layer agents across many cheap, repeated executions.

## Who Designs Workers

The architect is the sole author of worker agent definitions. Main requests a worker design when the user identifies a recurring need. The auditor reviews worker definitions before instantiation when the worker handles sensitive data, financial operations, or external communications.

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

1. Architect produces the definition package and writes it to `/Projects/<project-slug>/workers/<worker-id>/`.
2. If risk-triggered review is warranted, main routes the definition to auditor.
3. Main (or coder, on main's behalf) adds the worker to the platform config:
   - New entry in the agent list in `charts/platform-stack/values.yaml`
   - New workspace directory under `charts/openclaw/files/workspaces/<worker-id>/` created from the worker template
   - Placeholder values in the template filled in from the definition package
   - New entry in the `workspaceBootstrap.agents` section of `charts/platform-stack/values.yaml`
4. Cron schedule (if any) is configured via `openclaw cron add`.

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

The worker workspace template is at `charts/openclaw/files/workspaces/worker-template/`. Copy it to a new directory named after the worker ID and fill in the `{{PLACEHOLDER}}` values from the definition package.
