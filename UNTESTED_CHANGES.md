# Untested Changes

## 2026-04-01 - Task 1: SOPS Secrets Infrastructure

Status: statically validated only. Do not treat this as live-bootstrap verified yet.

Scope:

- Added repo-level `secrets/` scaffolding for SOPS-managed Secret manifests.
- Introduced `secrets/.sops.yaml` with age-based `creation_rules`.
- Added plaintext Secret templates for `openclaw-secrets`, `coder-credentials`, and `nextcloud-config-secrets`.
- Switched the platform values to expect `openclaw-secrets` instead of `openclaw-app-secrets`.
- Switched coder sandbox bootstrap defaults to read `CODER_GITEA_PASSWORD` and `CODER_REGISTRY_PASSWORD` from Kubernetes Secrets instead of literal `change-me` placeholders.
- Deprecated `scripts/bootstrap-secrets.sh` but kept it in place for legacy/not-yet-migrated secrets.

What to verify later during a real bootstrap or GitOps sync:

- `secrets/*.enc.yaml` decrypt successfully in Argo CD repo-server with the operator-provided age private key.
- No plaintext `secrets/*.yaml` files are accidentally staged or committed.
- `openclaw-secrets` exists in the target namespace and contains all keys referenced by `openclaw.secretKeys`, especially:
  `OPENCLAW_GATEWAY_TOKEN`, `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `BRAVE_API_KEY`, `KIMI_API_KEY`, `MOONSHOT_API_KEY`, `TAVILY_API_KEY`, `PERPLEXITY_API_KEY`, `GEMINI_API_KEY`, `XAI_API_KEY`, `GITHUB_TOKEN`, `GOOGLE_API_KEY`, and `BRAVE_SEARCH_API_KEY`.
- Missing optional provider keys behave as intended:
  empty keys should not break pod startup, but keys referenced in values must exist in the Secret if the env var is rendered.
- `coder-credentials` exists before OpenClaw starts and provides both `CODER_GITEA_PASSWORD` and `CODER_REGISTRY_PASSWORD`.
- The coder sandbox `setupCommand` successfully expands `CODER_GITEA_PASSWORD` into `$HOME/.netrc`, authenticates to Gitea, and can create or refresh the Tea token without shell quoting issues.
- Registry login in the coder sandbox still succeeds with the password now sourced from `coder-credentials`.
- `nextcloud-config-secrets` still satisfies both Nextcloud admin bootstrap and the external PostgreSQL/Redis password wiring.
- Any existing environment that still has only `openclaw-app-secrets` will fail until the Secret is renamed or replaced with `openclaw-secrets`; watch for this during migration.
- Any GitOps/bootstrap step that still assumes `scripts/bootstrap-secrets.sh` is the source of truth for OpenClaw provider secrets may now drift from the committed SOPS manifests; confirm the operational runbook uses the new workflow.
- `openclaw-nextcloud-mcp-secrets` is still legacy-managed; verify mixed mode behavior where some secrets are SOPS-managed and some still come from `bootstrap-secrets.sh`.

Suggested later test sequence:

1. Generate a real age keypair and replace the placeholder recipient in `secrets/.sops.yaml`.
2. Fill the plaintext templates locally, produce `*.enc.yaml`, and commit only the encrypted files.
3. Confirm Argo CD repo-server has the matching age private key and SOPS integration enabled.
4. Render/sync into a disposable environment, not the long-running local stack.
5. Check the OpenClaw pod env wiring, coder sandbox bootstrap behavior, and Nextcloud startup before treating the migration as complete.

## 2026-04-01 - Task 2: Sandbox Session Visibility + Writable Coder Workspace

Status: statically validated only. Do not treat this as sandbox-runtime verified yet.

Scope:

- Added `sessionToolsVisibility: "all"` to the shared OpenClaw sandbox defaults in both `charts/platform-stack/values.yaml` and `charts/openclaw/values.yaml`.
- Added `/workspace` to the coder sandbox `docker.tmpfs` list.
- Added explicit `HOME`, `CODEX_HOME`, `XDG_CONFIG_HOME`, `XDG_CACHE_HOME`, and `XDG_STATE_HOME` env vars to the coder sandbox runtime config.

What to verify later during a real runtime test:

- A coder main session running with `sandbox.mode: all` can use `sessions_send` to target existing non-child sessions instead of seeing only its own spawned session tree.
- The rendered `sessionToolsVisibility: "all"` value is actually honored by the OpenClaw runtime, not just present in `openclaw.json`.
- `/workspace` is writable inside the coder sandbox container and behaves as an isolated ephemeral tmpfs mount.
- `HOME=/workspace/.home` and the XDG directories are present in the sandbox process environment before `setupCommand` runs, not only after shell exports.
- The `setupCommand` still successfully creates:
  `"$CODEX_HOME"`, `"$XDG_CONFIG_HOME/tea"`, `"$XDG_CACHE_HOME"`, `"$XDG_STATE_HOME"`, and `"$HOME/.docker"`.
- Codex CLI can write its state under `/workspace/.home/.codex` without permission or read-only filesystem errors.
- Git can write repo metadata and global config without permission issues in the sandboxed coder session.
- Typical stateful tooling such as `pip`, `npm`, and local cache writers work with the new writable workspace contract.
- The writable `/workspace` tmpfs does not unintentionally hide required mounted repo content; confirm the runtime still exposes the expected working tree contents where coder needs them.
- The writable `/workspace` tmpfs size and memory footprint are acceptable for normal coder workflows and do not cause unexpected OOM or disk-full behavior for moderate repo/tool state.
- The explicit runtime env vars do not conflict with any OpenClaw or container entrypoint behavior that also sets `HOME` or XDG paths.

Suggested later test sequence:

1. Start or reuse a disposable environment, not the long-running local stack.
2. Open a coder sandbox session and inspect `pwd`, `env`, `mount`, and write access under `/workspace`.
3. Verify `sessions_send` from the sandbox can see and target the expected session IDs.
4. Run a minimal Codex, `git`, and package-manager workflow that writes state under `/workspace/.home`.
5. Confirm the sandbox still sees the intended repo contents and that no required mounts were shadowed by the `/workspace` tmpfs.

## 2026-04-01 - Task 3: Coder Init Script Extraction + Docker Socket Bind

Status: statically validated only. Do not treat this as coder-image or sandbox-runtime verified yet.

Scope:

- Moved the coder sandbox inline `setupCommand` logic into `images/openclaw-sandbox-coder/coder-init.sh`.
- Updated the coder image Dockerfile to copy that script into `/usr/local/bin/coder-init.sh`.
- Changed the coder sandbox config to call the script via `setupCommand: /usr/local/bin/coder-init.sh`.
- Added a Docker socket bind mount at `/var/run/docker.sock:/var/run/docker.sock`.
- Kept coder Gitea and registry passwords sourced from `${CODER_GITEA_PASSWORD}` and `${CODER_REGISTRY_PASSWORD}`.

What to verify later during a real image build and sandbox runtime test:

- The `openclaw-sandbox-coder` image actually includes `/usr/local/bin/coder-init.sh` with executable permissions.
- The script runs successfully as the sandbox user, not only under shell syntax check.
- The script remains idempotent across repeated sandbox starts and does not accumulate conflicting Tea login state.
- The script correctly derives `CODER_GITEA_BASE_URL` when only `CODER_GITEA_HOST` is set and still behaves correctly when both are set.
- `.netrc` is written with the expected host, username, and password and is readable only by the sandbox user.
- Tea token rotation still works against the live Gitea API and does not leave the coder environment without a usable token if token creation fails midway.
- Docker login still succeeds with credentials sourced from `coder-credentials`.
- The mounted `/var/run/docker.sock` is reachable from inside the coder sandbox and points at the intended Docker daemon in the Incus VM.
- The sandbox user has sufficient permission to use the mounted Docker socket; watch for group/UID mismatches or `permission denied` failures.
- Docker builds and pushes from inside the coder sandbox work end-to-end with the bound socket and registry auth.
- The Docker socket bind does not accidentally point at the wrong daemon in any supported environment.
- The socket bind and writable `/workspace` tmpfs do not conflict with each other or with any existing OpenClaw sandbox mount behavior.
- If the coder image is rebuilt and published to the in-cluster registry, confirm the chart is referencing the updated tag and not an older cached image.

Suggested later test sequence:

1. Build and publish a disposable updated `openclaw-sandbox-coder` image containing `coder-init.sh`.
2. Use a disposable environment, not the long-running local stack.
3. Start a coder sandbox session and verify `/usr/local/bin/coder-init.sh` exists, is executable, and runs cleanly.
4. Confirm `docker version` and a trivial `docker ps` work inside the sandbox through the mounted socket.
5. Perform a small image build and registry push from inside the sandbox.
6. Verify Git, Tea, and Docker auth all still work after rerunning the init script.

## 2026-04-01 - Task 4: Archivist Sandbox Image + Memgraph Connectivity

Status: statically validated only. Do not treat this as sandbox-runtime or live-connectivity verified yet.

Scope:

- Added `images/openclaw-sandbox-archivist/Dockerfile` as a dedicated archivist sandbox image layered on `openclaw-sandbox:bookworm-slim`.
- Installed `nodejs`, `npm`, and global `neo4j-driver` in that archivist image.
- Removed the inherited broken `/usr/local/bin/mgconsole` binary from the archivist image.
- Added archivist image support to `scripts/build-openclaw-sandbox-images.sh`.
- Updated the bootstrap/image-publish flow so archivist image refs are also built, remote-loaded, and tagged alongside the base and coder sandbox images.
- Added an explicit archivist `sandbox` block in platform values and bootstrap-rendered OpenClaw config, pointing at `registry.homebase.local/coder/openclaw-sandbox-archivist:bookworm-slim`.
- Forced the Memgraph Kubernetes Service to `ipFamilies: [IPv4]` with `ipFamilyPolicy: SingleStack`.
- Confirmed the existing Incus hostname-override path already includes Memgraph for both `k3d` and `k3s`, and updated docs/tests around that contract.

What to verify later during a real image build and sandbox runtime test:

- The `openclaw-sandbox-archivist` image builds successfully on the real image-build host and publishes under the intended registry tag.
- `node`, `npm`, and the globally installed `neo4j-driver` are available inside an actual archivist sandbox container.
- Removing `/usr/local/bin/mgconsole` does not break any archivist workflow that still expects that binary path; if `mgconsole` remains needed, it must be replaced with a compatible build rather than silently absent.
- OpenClaw actually launches archivist with the dedicated sandbox image instead of falling back to the shared default image.
- Archivist remains on the intended `sandbox.mode = "non-main"` behavior at runtime.
- The Incus VM and nested Docker containers resolve the active Memgraph hostname to the Incus host listener address, not to public DNS or an unusable local/IPv6 path.
- Archivist can establish a real Bolt TCP connection to `memgraph.homebase.local:7687` from inside the sandbox.
- The IPv4-only Service rendering resolves the prior hostname/address-family issue without breaking in-cluster Memgraph access for other clients.
- Any workflow that still depends on `mgconsole` from inside sandboxes either moves to a supported Bolt client path or receives a compatible replacement binary.
- If a new archivist image is published, the registry tag referenced by OpenClaw matches the image actually present on the remote Docker host and in the in-cluster registry.

Static validation completed:

- `python3 tests/test-bootstrap-config.py`
- `python3 tests/test-render-gitops-repo.py`
- `bash tests/test-bootstrap-stack-remote-docker-autodiscovery.sh`
- `./scripts/lint.sh --values-file charts/platform-stack/values.yaml`
- `./scripts/lint.sh --values-file charts/platform-stack/values.yaml --values-file charts/platform-stack/values-k3d.yaml`
- `./scripts/lint.sh --values-file charts/platform-stack/values.yaml --values-file charts/platform-stack/values-k3s.yaml`
- `./scripts/template.sh --release-name platform-stack --namespace ai-homebase --values-file charts/platform-stack/values.yaml > /tmp/platform-stack.yaml`
- `./scripts/template.sh --release-name platform-stack --namespace ai-homebase --values-file charts/platform-stack/values.yaml --values-file charts/platform-stack/values-k3s.yaml > /tmp/platform-stack-k3s.yaml`

Suggested later test sequence:

1. Build and publish a disposable `openclaw-sandbox-archivist` image to the in-cluster registry.
2. Use a disposable environment, not the long-running local stack.
3. Start an archivist sandbox session and verify `node --version`, `npm --version`, and a minimal `neo4j-driver` import.
4. Confirm the sandbox resolves the active Memgraph hostname to the expected IPv4 address and can TCP-connect to port `7687`.
5. Run a trivial Bolt query from the archivist sandbox to confirm end-to-end Memgraph connectivity.
6. Decide explicitly whether archivist should remain without `mgconsole` or receive a compatible replacement binary.

## 2026-04-01 - Task 5: Model Diversification + API Key Enablement

Status: statically validated only. Do not treat this as live-runtime or provider-failover verified yet.

Scope:

- Changed the shared OpenClaw agent model aliases to the diversified provider mix:
  `openai/gpt-4.1` as Main, `anthropic/claude-sonnet-4-6` as Coder / Archivist, `anthropic/claude-opus-4-6` as Architect, and `openai/gpt-4.1-nano` as Watchdog.
- Updated each explicit agent config to use a structured `model` object with `primary` plus `fallbacks`.
- Extended `bootstrap.local.toml` handling so each agent now supports `model` plus optional `fallback_models`, and updated `bootstrap.example.toml` to the new diversified primary/fallback defaults.
- Kept architect pinned to `anthropic/claude-opus-4-6` as the primary model.
- Aligned the standalone `charts/openclaw/values.yaml` defaults with the umbrella chart so the packaged dependency renders the same diversified model posture.
- Refreshed the vendored umbrella dependency bundle with `helm dependency update charts/platform-stack` so rendered manifests pick up the updated OpenClaw defaults.
- Confirmed the OpenClaw config template still serializes `agents.defaults` and `agents.list` through `toJson`, so structured model objects render through to `openclaw.json`.
- Confirmed the bootstrap config renderer validates provider credentials for both primary and fallback models before generating values.
- Confirmed the deployment template still injects `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, and `GITHUB_TOKEN` from `openclaw-secrets` when the corresponding `secretKeys.*` entries are non-empty.
- Quoted watchdog `sandbox.mode` as `"off"` so the rendered JSON emits the string value instead of YAML boolean `false`.

What to verify later during a real runtime or bootstrap test:

- OpenClaw accepts the structured `model` object shape with `primary` and `fallbacks` exactly as rendered, rather than expecting a plain string at runtime.
- Bootstrap-driven renders and live bootstrap flows pick up `fallback_models` from real `bootstrap.local.toml` files exactly as intended, not just in unit tests.
- Each provider/model identifier is valid for the deployed OpenClaw version and routes to the expected backend without normalization or naming mismatches.
- The primary/fallback behavior actually works across providers:
  `main` should fail over from OpenAI to Anthropic,
  `architect` from Anthropic to OpenAI,
  `coder` and `archivist` from Anthropic to OpenAI,
  and `watchdog` from OpenAI to Anthropic.
- Provider failover preserves the intended agent behavior and does not regress tool access, session handling, or sandbox execution.
- `openclaw-secrets` exists in the target namespace and contains at least:
  `OPENCLAW_GATEWAY_TOKEN`, `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, and `GITHUB_TOKEN`.
- The gateway pod receives `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, and `GITHUB_TOKEN` in its actual process environment, not just in the rendered Deployment manifest.
- The coder sandbox still receives `OPENAI_API_KEY` and `GITHUB_TOKEN` through the rendered sandbox env block and can use them successfully for Codex/GitHub-backed workflows.
- Any environment that previously depended on Anthropic-only agent routing does not hit unexpected provider quota, auth, or rate-limit issues after the split.
- Watchdog remains low-cost and functional on `openai/gpt-4.1-nano` for its scheduled heartbeat and triage workload.
- No bootstrap-generated override values or environment-specific overlays silently revert agents back to the previous single-provider defaults.

Static validation completed:

- `nix-shell --run './scripts/lint.sh --values-file charts/platform-stack/values.yaml'`
- `nix-shell --run './scripts/lint.sh --values-file charts/platform-stack/values.yaml --values-file charts/platform-stack/values-k3d.yaml'`
- `nix-shell --run './scripts/template.sh --release-name platform-stack --namespace ai-homebase --values-file charts/platform-stack/values.yaml > /tmp/platform-stack.yaml'`
- `nix-shell --run './scripts/template.sh --release-name platform-stack --namespace ai-homebase --values-file charts/platform-stack/values.yaml --values-file charts/platform-stack/values-k3d.yaml > /tmp/platform-stack-k3d.yaml'`
- `nix-shell --run 'helm dependency update charts/platform-stack'`

Suggested later test sequence:

1. Use a disposable environment, not the long-running local stack.
2. Confirm the live OpenClaw pod environment contains `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, and `GITHUB_TOKEN`.
3. Inspect the active `openclaw.json` inside the pod and verify the rendered agent `model` objects match the intended primary/fallback assignments.
4. Exercise one request per agent with both providers healthy to confirm the primaries are selected as intended.
5. Simulate or induce provider unavailability one provider at a time and confirm cross-provider fallback works for each affected agent.
6. Verify watchdog cron/heartbeat behavior remains acceptable on the new low-cost OpenAI primary.

## 2026-04-01 - Task 6: Main + Architect Workspace Bootstrap Revisions

Status: statically validated only. Do not treat this as first-deploy or live-agent-runtime verified yet.

Scope:

- Updated the seeded `main` workspace `AGENTS.md` in `charts/platform-stack/values.yaml` to describe main as the user-facing coordinator and project manager.
- Added explicit main-agent routing exclusions for graph work to archivist and expanded the existing routing boundaries for architect, coder, and watchdog.
- Added a routing heuristics table to main's seeded `AGENTS.md` covering graph, coding/deployment, design/planning, and monitoring/health prompts.

## 2026-04-02 - Task 13: Workspace Files Extracted Out of values.yaml

Status: statically validated only. Do not treat this as live first-boot verified yet.

Scope:

- Moved the seeded agent workspace markdown out of inline YAML block scalars and into plain files under `charts/openclaw/files/workspaces/`.
- Replaced the inline `workspaceBootstrap.agents.<id>.files` maps in `charts/platform-stack/values.yaml` and `charts/openclaw/values.yaml` with `filesDir` pointers.
- Updated `charts/openclaw/templates/configmap.yaml` to render workspace files either from chart-owned files via `.Files.Get` or from legacy inline `files` values.
- Updated `charts/openclaw/templates/deployment.yaml` so the workspace bootstrap init-container seeds files from either `filesDir` or legacy inline `files`.
- Documented the new chart-owned workspace file location and legacy compatibility behavior in `docs/configuration.md`.

What to verify later during a real deploy or first-start test:

- A fresh OpenClaw install still seeds every expected workspace file into the durable state tree for `main`, `coder`, `architect`, `archivist`, and `watchdog`.
- The seeded files in the live pod match the intended on-disk chart assets exactly, including trailing newlines and markdown formatting.
- Existing persistent workspaces are still preserved correctly on upgrade and are not overwritten by the init-container when files already exist.
- The chart-owned `filesDir` path works correctly for both umbrella-driven installs and direct `charts/openclaw` chart usage.
- A values override that still uses legacy inline `workspaceBootstrap.agents.<id>.files` continues to render and seed correctly without `filesDir`.
- The ConfigMap size remains acceptable when the workspace payload is loaded from files rather than inline values.

Static validation completed:

- `nix-shell --run './scripts/lint.sh --values-file charts/platform-stack/values.yaml'`
- `nix-shell --run './scripts/template.sh --release-name platform-stack --namespace ai-homebase --values-file charts/platform-stack/values.yaml > /tmp/after-refactor.yaml'`
- Rendered a clean pre-change snapshot to `/tmp/before-refactor.yaml` and confirmed `diff -u /tmp/before-refactor.yaml /tmp/after-refactor.yaml` was empty.

Suggested later test sequence:

1. Use a disposable environment, not the long-running local stack.
2. Deploy or upgrade the umbrella chart with the refactored values.
3. Inspect the rendered OpenClaw ConfigMap and confirm the expected `workspace-<agent>-<file>` keys exist.
4. Start from an empty OpenClaw state directory and verify the init-container seeds every expected workspace file.
5. Re-run with an existing populated state directory and confirm existing workspace files are preserved.
6. Run one targeted override test using legacy inline `workspaceBootstrap.agents.<id>.files` to confirm backward compatibility.

## 2026-04-01 - Task 7: Coder + Archivist Workspace Bootstrap Revisions

Status: statically validated only. Do not treat this as first-deploy or live-agent-runtime verified yet.

Scope:

- Updated the seeded `coder` workspace files in `charts/platform-stack/values.yaml` to make the coder and archivist boundary explicit.
- Added coder exclusions for graph data operations, graph schema work, Cypher, graph migration scripts, knowledge-import pipelines, and Qdrant memory grooming.
- Added coder grey-zone guidance clarifying that infrastructure automation belongs to coder while graph data work belongs to archivist.
- Added the coder communication-budget guidance to be conservative with inter-agent messages and prefer durable Nextcloud context.
- Added the coder Layer 2 cost-awareness check referencing `session_status` and `/Projects/ai-homebase/budget-ledger.json`, with a `$3` daily soft budget and the monthly `$100` hard ceiling.
- Applied minor supporting updates to the seeded coder `SOUL.md`, `USER.md`, `IDENTITY.md`, `HEARTBEAT.md`, and `MEMORY.md`.
- Updated the seeded `archivist` workspace files in `charts/platform-stack/values.yaml` to make archivist the explicit owner of all graph data operations.
- Expanded archivist domain ownership to include knowledge-graph schema evolution, all Cypher/query/mutation work, graph migration scripts, data-import pipelines, Qdrant grooming/linking/deduplication, and cross-project context synthesis.
- Added archivist grey-zone guidance clarifying that infrastructure and installation work belong to coder while graph data work belongs to archivist.
- Added the archivist communication-budget guidance to be conservative with inter-agent messages and prefer durable Nextcloud context.
- Added the archivist Layer 2 cost-awareness check referencing `session_status` and `/Projects/ai-homebase/budget-ledger.json`, with a `$1` daily soft budget and the monthly `$100` hard ceiling.
- Rewrote the seeded archivist `TOOLS.md` to use `neo4j-driver` for Bolt connections instead of `mgconsole`.
- Updated archivist tool guidance to target the Memgraph ingress hostname from `global.hosts.memgraph` on port `7687`.
- Strengthened archivist Cypher/schema guidance so labels and relationship types stay few, general-purpose, and reusable across many domains rather than proliferating domain-specific relationships.
- Applied minor supporting updates to the seeded archivist `SOUL.md`, `MEMORY.md`, `USER.md`, `IDENTITY.md`, and `HEARTBEAT.md`.

What to verify later during a real first deploy or live-agent sandbox/runtime test:

- Freshly bootstrapped coder and archivist workspaces receive the revised seeded files exactly as rendered from `charts/platform-stack/values.yaml`.
- Existing long-lived agent workspaces are handled intentionally; confirm whether they should remain unchanged, be manually migrated, or receive an automated reseed path.
- The seeded markdown renders cleanly inside the agent workspaces with the intended YAML multiline-string formatting preserved.
- Coder behavior now consistently routes graph data tasks to archivist while still handling graph-tooling installation and infrastructure automation itself.
- Archivist behavior now consistently accepts graph queries, mutations, imports, migrations, and Qdrant grooming while routing infrastructure changes back to coder.
- Archivist sandbox runtime actually has globally installed `neo4j-driver` available to Node without extra installation.
- Archivist can connect successfully to Memgraph over Bolt using the ingress hostname from `global.hosts.memgraph` on port `7687`.
- No seeded archivist instructions, helper scripts, or runtime assumptions elsewhere still depend on `mgconsole`.
- The broad-schema guidance is sufficient in practice to prevent domain-specific relationship sprawl while still allowing necessary modeling across very different domains.
- The budget-ledger path `/Projects/ai-homebase/budget-ledger.json` is reachable from the relevant agent runtime and the agents can append usage in the expected format.
- The new communication-budget guidance does not conflict with any automation or agent-to-agent workflows that currently assume verbose direct messaging.

Validation completed:

- `nix-shell --run './scripts/lint.sh --values-file charts/platform-stack/values.yaml'`

Known validation gap:

- The reference note `/Projects/ai-homebase/agent-role-revisions-2026-04-01.md` was not available in this local workspace, so the seeded text was updated from the task specification rather than verified against that Nextcloud file.

Suggested later test sequence:

1. Use a disposable environment, not the long-running local stack.
2. Bootstrap fresh agent workspaces and inspect the seeded coder and archivist files for exact content and formatting.
3. Exercise one coder task that installs or configures graph infrastructure and confirm it stays within coder's domain.
4. Exercise one archivist task that performs a real Bolt query or mutation with `neo4j-driver` and confirm it stays within archivist's domain.
5. Confirm archivist can resolve the Memgraph ingress hostname and connect on `7687`.
6. Check that the agents can read and append `/Projects/ai-homebase/budget-ledger.json` as described.
- Expanded main's boundary rule so graph queries/graph-linking work and sustained monitoring or health investigation are stop-and-route cases.
- Added a communication-budget section to main instructing conservative inter-agent messaging and a preference for durable Nextcloud artifacts over long handoff threads.
- Added a budget-management section to main making it the budget manager, defining daily/weekly/monthly thresholds, per-agent soft allocations, delegation rules by priority class, and the `/Projects/ai-homebase/budget-ledger.json` ledger contract.
- Explicitly instructed main to create `/Projects/ai-homebase/budget-ledger.json` on first use with `{"entries": []}` if it does not yet exist.
- Added heartbeat-maintenance instructions to main's seeded `AGENTS.md` and `HEARTBEAT.md`, pointing at `/Projects/ai-homebase/heartbeat.json` with the required JSON shape.
- Added corresponding `TOOLS.md` guidance for main so the seeded Nextcloud file-placement instructions mention both the budget ledger and heartbeat files.
- Updated the seeded `architect` workspace `AGENTS.md` to explicitly exclude graph queries, graph schema work, Cypher, memory linking, and durable graph curation to archivist.
- Added a communication-budget section to architect instructing conservative inter-agent messaging and a preference for durable Nextcloud artifacts.
- Added architect cost-awareness instructions to check `session_status` and or `/Projects/ai-homebase/budget-ledger.json`, to surface over-budget posture to main when near or over the daily soft budget, and to append usage to the ledger at session end.
- Added a small supporting note to architect's `HEARTBEAT.md` so non-trivial tasks also require checking and surfacing budget posture.
- Left the other seeded `main` and `architect` workspace files largely intact, only making the minor updates needed to support the new budget and heartbeat behavior.

What to verify later during a real first deploy or live agent-runtime test:

- On a fresh bootstrap, the seeded `main` and `architect` workspaces are created exactly once with the revised `AGENTS.md`, `TOOLS.md`, and `HEARTBEAT.md` contents.
- The multiline Markdown in `charts/platform-stack/values.yaml` survives OpenClaw bootstrap file seeding without YAML indentation damage, truncation, or formatting corruption.
- Main can create `/Projects/ai-homebase/budget-ledger.json` on first use when it is absent, and the resulting file contents match the documented JSON contract.
- Main can append ledger entries in the documented format without breaking later reads or causing malformed JSON.
- Main can create or update `/Projects/ai-homebase/heartbeat.json` in the documented format after user-facing work or meaningful coordination cycles.
- Architect can read the shared budget ledger and surface an over-budget status to main in a usable way before continuing non-trivial work.
- The seeded role boundaries actually improve routing behavior in practice:
  graph work routes to archivist,
  implementation and deployment work routes to coder,
  design/specification work routes to architect,
  and health/monitoring work routes to watchdog.
- Main follows the new communication-budget rule by preferring concise handoffs plus durable Nextcloud artifacts instead of verbose inter-agent message threads.
- The references to `session_status` and Nextcloud ledger files align with the real OpenClaw tool/runtime surface available to the seeded agents.
- Existing bootstrap behavior that shares `/Projects/` and `/Notes/` with the user still works when the new `budget-ledger.json` and `heartbeat.json` files appear under `/Projects/ai-homebase/`.

Static validation completed:

- `nix-shell --run './scripts/lint.sh --values-file charts/platform-stack/values.yaml'`
- `nix-shell --run './scripts/lint.sh --values-file charts/platform-stack/values.yaml --values-file charts/platform-stack/values-k3d.yaml'`
- `nix-shell --run './scripts/lint.sh --values-file charts/platform-stack/values.yaml --values-file charts/platform-stack/values-k3s.yaml'`
- `nix-shell --run './scripts/template.sh --release-name platform-stack --namespace ai-homebase --values-file charts/platform-stack/values.yaml > /tmp/platform-stack.yaml'`

Suggested later test sequence:

1. Use a disposable environment, not the long-running local stack.
2. Bootstrap a fresh OpenClaw install and inspect the seeded `main` and `architect` workspace files on disk.
3. Confirm the seeded `main` files contain the routing table, budget-management section, and heartbeat instructions exactly as intended.
4. Confirm the seeded `architect` files contain the graph exclusion, communication-budget guidance, and cost-awareness section.
5. Exercise one routed request in each category to verify main hands graph, coding, planning, and monitoring work to the intended specialist.
6. Confirm main can create and later append `/Projects/ai-homebase/budget-ledger.json` and can update `/Projects/ai-homebase/heartbeat.json` without runtime errors.

## 2026-04-01 - Task 8: Watchdog Workspace Files Severity Gates + Anti-False-Positive Rules

Status: statically updated only. Do not treat this as cron-runtime or live-agent behavior verified yet.

Scope:

- Updated the seeded watchdog `AGENTS.md` in `charts/platform-stack/values.yaml`.
- Added explicit severity gates for `info`, `warning`, and `critical`, including persistence and independent-signal requirements before escalation.
- Added anti-false-positive rules for cold-start latency, cron-context `sessions_list` isolation, a 30-minute critical re-escalation cooldown, and a baseline-first requirement using `/Projects/ai-homebase/baselines.md`.
- Added conservative communication-budget guidance telling watchdog to prefer durable Nextcloud notes and minimize inter-agent messaging.
- Added the watchdog Layer 2 cost-awareness check referencing `session_status` and `/Projects/ai-homebase/budget-ledger.json`, with a `$0.50` daily soft budget and the shared `$100` monthly hard ceiling.
- Added an explicit cron-behavior note forbidding `sessions_send` and `sessions_list` from cron context and directing cron checks toward the Nextcloud heartbeat file and the local gateway readiness endpoint.
- Updated the seeded watchdog `TOOLS.md` to document the heartbeat-based monitoring approach via `http://127.0.0.1:18789/readyz` and `/Projects/ai-homebase/heartbeat.json`.
- Added a `status-log.md` convention at `/Projects/ai-homebase/status-log.md` for severity-gated routine observations and cooldown context.

What to verify later during a real first deploy or live watchdog runtime test:

- A freshly seeded watchdog workspace receives the revised `AGENTS.md` and `TOOLS.md` exactly as rendered from `charts/platform-stack/values.yaml`.
- Existing watchdog workspaces are handled intentionally; confirm whether they remain unchanged, need manual migration, or require a reseed path.
- Cron-triggered watchdog sessions actually avoid `sessions_send` and `sessions_list` and instead use the heartbeat file plus `http://127.0.0.1:18789/readyz`.
- The watchdog agent treats initial session cold-start latency as non-actionable and no longer emits false `critical` alerts for expected first-use startup delay.
- `sessions_list` returning `0` from cron context is ignored as expected and does not trigger incident escalation.
- Warning-level conditions only notify main after at least two consecutive checks with a minimum 10-minute separation.
- Critical-level incidents require at least one independent confirming signal before watchdog escalates to main.
- The 30-minute cooldown on repeated escalation of the same issue behaves as intended unless new evidence appears.
- `/Projects/ai-homebase/baselines.md` is readable from the watchdog runtime, and missing baselines cause `info` logging plus baseline proposal behavior rather than escalation.
- `/Projects/ai-homebase/status-log.md` is writable and useful for observation logging and cooldown context without creating noisy durable artifacts.
- The heartbeat readiness pair remains reliable in the real runtime:
  `http://127.0.0.1:18789/readyz` from the gateway,
  and `/Projects/ai-homebase/heartbeat.json` from Nextcloud.
- The watchdog agent can read and append `/Projects/ai-homebase/budget-ledger.json` and can surface over-budget posture to main before non-trivial work.

Validation attempted:

- `./scripts/lint.sh --values-file charts/platform-stack/values.yaml`
- `./scripts/template.sh --release-name platform-stack --namespace ai-homebase --values-file charts/platform-stack/values.yaml > /tmp/platform-stack.yaml`

Known validation gap:

- Both canonical validation commands failed immediately in this local environment because `helm` is not installed, so no Helm-based lint or render completed for this change.

Suggested later test sequence:

1. Use a disposable environment, not the long-running local stack.
2. Bootstrap or reseed a fresh watchdog workspace and inspect the seeded `AGENTS.md` and `TOOLS.md` content on disk.
3. Exercise a cron-style watchdog check and confirm it uses the heartbeat file and `readyz` endpoint instead of inter-session messaging.
4. Simulate cold-start latency and cron-context `sessions_list = 0` and verify both are treated as exempt, non-critical conditions.
5. Simulate a warning condition across multiple checks to confirm main is only notified after the persistence gate is met.
6. Simulate a critical outage with two independent signals and confirm watchdog escalates once, then respects the 30-minute cooldown for repeated alerts.

## 2026-04-01 - Task 9: Cron Job Updates

Status: statically updated only. Do not treat this as live cron-runtime or gateway-job verified yet.

Scope:

- Updated the four `ensure_job` definitions in `scripts/bootstrap-openclaw-cron.sh` without changing the script structure, session mode, or agent assignments.
- Changed the watchdog heartbeat cron frequency from `5m` to `15m`.
- Rewrote the heartbeat job instructions to use `http://127.0.0.1:18789/readyz` plus `/Projects/ai-homebase/heartbeat.json` instead of `sessions_send` or `sessions_list` from cron context.
- Updated the heartbeat job to require two consecutive failures before escalating beyond the status log and to apply the watchdog severity gates from `AGENTS.md`.
- Changed the platform sweep schedule from `15 */6 * * *` to `15 */12 * * *`.
- Removed `sessions_send` / `sessions_list` references from the platform sweep job and redirected cron-context issue reporting to `/Projects/ai-homebase/watchdog-status-log.md` for main to pick up later.
- Updated the archivist nightly grooming job to use a Node.js Bolt path via `require('neo4j-driver')` instead of `mgconsole`.
- Tightened the archivist grooming instructions to prefer a small set of general-purpose labels and relationships instead of adding domain-specific graph types unnecessarily.
- Extended the daily digest job to read `/Projects/ai-homebase/budget-ledger.json` and include daily, weekly, and monthly per-agent spend summaries with threshold warnings.

What to verify later during a real runtime test:

- `openclaw cron add` accepts the revised long-form message strings without truncation, escaping issues, or cron-parser problems.
- The heartbeat cron job can read `/Projects/ai-homebase/heartbeat.json` successfully from its isolated cron session and parse main's last-activity timestamp reliably.
- The heartbeat job correctly treats `sessions_send` and `sessions_list` as non-authoritative in cron context and no longer produces false alarms from sandbox isolation.
- A healthy gateway plus a fresh heartbeat produces only a short OK append to `/Projects/ai-homebase/watchdog-status-log.md`.
- A stale heartbeat or failing `readyz` check produces a failure note in the same log and does not escalate until the second consecutive failure path is observed.
- The resulting watchdog behavior in cron aligns with the severity gates already seeded into the watchdog workspace `AGENTS.md`.
- The platform sweep still performs gateway readiness checks, TLS expiry inspection, and `session-logs` skill usage as intended, despite removing cron-context session messaging.
- Main or the standing watchdog session can reliably detect and act on flagged issues written to `/Projects/ai-homebase/watchdog-status-log.md`.
- The archivist runtime actually has `neo4j-driver` available and can establish the intended Bolt connection path from its execution environment.
- The archivist grooming workflow still reaches the graph successfully without any hidden `mgconsole` dependency.
- The daily digest can read `/Projects/ai-homebase/budget-ledger.json`, compute daily/weekly/monthly spend per agent, and flag threshold-adjacent agents without malformed output.
- The daily digest still trims older status-log content as intended after adding the new budget-summary section.

Static validation completed:

- `bash -n scripts/bootstrap-openclaw-cron.sh`

Known validation gap:

- No live OpenClaw cron jobs were created or exercised in this session, and the running cluster was intentionally left untouched.

Suggested later test sequence:

1. Use a disposable environment, not the long-running local stack.
2. Seed the revised cron jobs and list them back from the gateway to confirm the schedules and full messages were stored correctly.
3. Trigger or wait for one heartbeat run with a healthy gateway and fresh heartbeat file, then confirm the expected one-line OK append in `/Projects/ai-homebase/watchdog-status-log.md`.
4. Simulate a stale heartbeat and then a repeated stale heartbeat to confirm the two-consecutive-failure rule before escalation behavior.
5. Run a platform sweep and confirm findings are written to the Nextcloud status log rather than sent directly from cron via `sessions_send`.
6. Run archivist grooming and the daily digest once to confirm the `neo4j-driver` path and budget-ledger summary both work end to end.

## 2026-04-01 - Task 10: Nextcloud Bootstrap Content + Escalation Rules + Baselines

Status: statically validated only. Do not treat this as live Nextcloud-bootstrap or reseed verified yet.

Scope:

- Added `heartbeat.json` to the seeded `bootstrapProjectContent` for the `ai-homebase` Nextcloud project with the initial bootstrap heartbeat payload.
- Added `budget-ledger.json` to the same seeded project content with the initial soft-budget and hard-ceiling structure plus an empty `entries` array.
- Replaced the placeholder `baselines.md` content with initial gateway, session, service, and known-pattern baselines for watchdog follow-up.
- Replaced the placeholder `escalation-rules.md` content with explicit `info` / `warning` / `critical` gates, anti-false-positive rules, and follow-up ownership guidance.

What to verify later during a real bootstrap, reseed, or disposable-environment test:

- A fresh Nextcloud bootstrap actually creates `/Projects/ai-homebase/heartbeat.json` with the exact initial JSON payload from `charts/platform-stack/values.yaml`.
- A fresh Nextcloud bootstrap actually creates `/Projects/ai-homebase/budget-ledger.json` with the exact seeded budget structure and an empty `entries` array.
- The Nextcloud bootstrap job writes the Markdown files with the intended formatting and does not mangle the table in `escalation-rules.md`.
- Existing environments are handled intentionally:
  confirm whether already-seeded project files remain unchanged, are overwritten, or require an explicit reseed path.
- The standing agents can read the newly seeded `heartbeat.json` and `budget-ledger.json` paths through the Nextcloud MCP pathing conventions already referenced in their workspace instructions.
- `watchdog` can append or update the seeded `baselines.md` and incident-related files without conflicting with the new initial content.
- `main` can read the seeded `budget-ledger.json` before delegation and append later usage records in the expected JSON shape.
- The initial baselines are accurate enough for a real environment and do not create false positives once the platform is running normally.
- The severity ownership guidance in `escalation-rules.md` matches actual operator expectations for watchdog-to-main escalation flow.

Static validation completed:

- `yq '.' charts/platform-stack/values.yaml >/tmp/platform-stack-values-validated.yaml`
- Extracted `heartbeat.json` payload from `charts/platform-stack/values.yaml` and validated it with `jq`.
- Extracted `budget-ledger.json` payload from `charts/platform-stack/values.yaml` and validated it with `jq`.

Known validation gap:

- The repo's canonical Helm-based validation commands could not run in this workspace because `helm` is not installed locally, so no Helm render or lint verified the seeded Nextcloud content in this session.

Suggested later test sequence:

1. Use a disposable environment, not the long-running local stack.
2. Run a fresh bootstrap or an explicit Nextcloud project-content reseed path and inspect the resulting `/Projects/ai-homebase/` files.
3. Open `heartbeat.json`, `budget-ledger.json`, `baselines.md`, and `escalation-rules.md` through Nextcloud or the MCP bridge and confirm the exact seeded content and formatting.
4. Exercise one `main` budget-check flow and one `watchdog` baseline/escalation-reference flow to confirm the seeded files are readable and operationally useful.
5. Decide and document the intended behavior for already-existing bootstrap project files during upgrades or reruns.

## 2026-04-01 - Task 11: Generalized Memgraph Seed Schema

Status: statically validated only. Do not treat this as live Memgraph-bootstrap or Helm-render verified yet.

Scope:

- Rewrote `memgraphBootstrap.seedCypher` in `charts/platform-stack/values.yaml` to replace domain-specific relationship types with the smaller general-purpose set `HAS_MEMBER`, `USES`, `PART_OF`, and `MANAGES`.
- Kept the seeded bootstrap entities limited to bootstrap-time state only:
  `ai-homebase`, the user, OpenClaw, Nextcloud, Qdrant, Memgraph, Memgraph Lab, Gitea, Argo CD, the registry, the core agents, and the two seeded repositories.
- Added `Entity` as a common label on the seeded durable nodes to support a more uniform baseline query shape.
- Moved specialized semantics from relationship types onto relationship properties, for example:
  `MANAGES {role: 'graph-curation'}` and `USES {role: 'graph-visualization'}`.
- Updated the seeded Nextcloud copy of `knowledge-graph-schema.md` inside `bootstrapProjectContent`.
- Updated the repo copy at `docs/knowledge-graph-schema.md`.
- Updated the seeded archivist `TOOLS.md` Cypher guidance so runtime instructions match the new canonical relationship vocabulary.

What to verify later during a real bootstrap, reseed, or disposable-environment test:

- The Memgraph bootstrap Job accepts the revised multi-statement Cypher exactly as rendered from `charts/platform-stack/values.yaml`.
- Memgraph 3.8.x accepts the relationship-property `MERGE` statements exactly as written, especially the `MANAGES {role: ...}` and `USES {role: 'graph-visualization'}` edges.
- A fresh bootstrap creates only one copy of each seeded node and edge after repeated hook runs, preserving idempotency.
- The `Entity` label addition does not conflict with any existing archivist queries, graph notes, or later graph-curation workflows.
- The reduced relationship vocabulary is sufficient for the existing cluster-domain queries without forcing immediate ad hoc relationship-type growth.
- The seeded Nextcloud `/Projects/ai-homebase/knowledge-graph-schema.md` file matches the updated repo-managed schema guidance after a fresh bootstrap or explicit reseed path.
- Existing environments are handled intentionally:
  confirm whether a rerun updates only Memgraph state, only Nextcloud-seeded docs, both, or neither when bootstrap content already exists.
- Archivist guidance in the seeded workspace remains aligned with the actually bootstrapped schema and does not drift from `docs/knowledge-graph-schema.md`.

Static validation completed:

- Searched the updated schema paths to confirm the old domain-specific relationship names are no longer referenced in the canonical schema doc, seeded schema doc, or seeded Cypher block.
- Reviewed the resulting diff to confirm the seeded entities stayed restricted to bootstrap-time state and that the relationship vocabulary was consistently reduced across docs and instructions.

Known validation gap:

- The repo's canonical Helm render path could not run in this workspace because `helm` is not installed locally, so `./scripts/template.sh --release-name platform-stack --namespace ai-homebase --values-file charts/platform-stack/values.yaml` was not executable here.

Suggested later test sequence:

1. Use a disposable environment, not the long-running local stack.
2. Run the shared render path with Helm available and inspect the rendered Memgraph bootstrap Job payload.
3. Bootstrap or rerun the Memgraph seed hook once, then query the graph to confirm the expected labels, edges, and relationship properties were created.
4. Rerun the same bootstrap hook and confirm node and edge counts remain stable.
5. Inspect the seeded `/Projects/ai-homebase/knowledge-graph-schema.md` file in Nextcloud and confirm it matches the updated canonical vocabulary.
