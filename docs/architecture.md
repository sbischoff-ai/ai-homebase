# Architecture boundaries: control-plane vs execution-plane

`ai-homebase` models the platform as two cooperating planes with distinct responsibilities:

- **Control-plane (`openclaw`)**: API-first entrypoint, user-facing orchestration surface, and policy/configuration owner.
- **Execution-plane (`openhands`)**: internal job runner responsible for workspace lifecycle, queue-backed execution, and worker-level runtime concerns.

## Boundary definition

### `openclaw` (control-plane)

Primary responsibilities:

- Expose the external ingress/API endpoint.
- Accept requests, validate/authorize, and normalize job intents.
- Persist and publish execution requests to the selected queue/event mechanism.
- Aggregate execution status and present a stable contract back to clients.

Operational expectations:

- Prioritize API availability and predictability.
- Keep request-path state minimal and explicit.
- Remain externally reachable while execution stays private by default.

### `openhands` (execution-plane)

Primary responsibilities:

- Consume queued work and execute isolated job workloads.
- Handle workspace storage and runtime dependencies for jobs.
- Report status, artifacts, and terminal outcomes back to control-plane integration points.
- Scale workers based on queue pressure and resource targets.

Operational expectations:

- Default to internal-only service exposure (`ClusterIP`).
- Emphasize safe execution, workload isolation, and bounded concurrency.
- Support horizontal scale independently of control-plane API scaling.

## Data and trust flow

1. Client traffic enters through `openclaw` ingress.
2. `openclaw` validates and translates requests into execution units.
3. `openhands` workers consume those units and perform execution.
4. Results/status propagate back to control-plane-visible stores or APIs.

This keeps ingress, API contracts, and policy in one plane while runtime risk and high-variance workloads remain in another.

## Future scaling and isolation intent

The chart structure intentionally leaves room for stronger execution isolation and independent scaling:

- **Independent scaling knobs** for each plane (replicas + HPA targets).
- **Worker isolation controls** (runtime class, node selectors, tolerations, affinity) for execution-plane hardening.
- **Queue abstraction placeholders** so execution can migrate between providers without changing the control-plane contract.
- **Persistence separation** so API data and execution workspaces evolve with different storage classes and backup policies.

Longer-term direction:

- Per-tenant/per-workload job pools.
- Dedicated node pools for untrusted or high-cost jobs.
- Stronger runtime isolation (e.g., gVisor/Kata or equivalent) where required.
- Clear SLO split: API latency/availability (`openclaw`) vs throughput/completion (`openhands`).
