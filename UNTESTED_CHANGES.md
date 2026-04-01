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
