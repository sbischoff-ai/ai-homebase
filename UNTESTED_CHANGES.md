# Untested Changes

## 2026-04-03 - Task 9: Strengthen Graph Population and Archivist Coordination

Status: statically validated only. Do not treat this as live runtime/bootstrap verified yet.

Scope:

- Added `## Graph-Worthy Events` guidance to `charts/openclaw/files/workspaces/{main,coder,architect,watchdog}/AGENTS.md` so non-archivist agents explicitly record graph-worthy events in Qdrant using canonical slugs.
- Added `## Entity references` guidance to `charts/openclaw/files/workspaces/{main,coder,architect,watchdog}/MEMORY.md` so stored memories mention canonical graph slugs for projects, services, agents, repos, and people.
- Replaced `scripts/cron-messages/archivist-nightly-grooming.md` with a concrete 5-step nightly grooming procedure covering memory discovery, `MemoryEntry` linking, stale/orphan review, schema-doc updates, and grooming-log updates.
- Added bootstrap project content file `charts/platform-stack/files/bootstrap-content/ai-homebase/projects/archivist-grooming-log.md`.
- Updated `charts/platform-stack/values.yaml` so Nextcloud bootstrap project content includes `archivist-grooming-log.md`.
- Updated `scripts/bootstrap-config.py` embedded workspace markdown and seeded project-content definitions so bootstrap-generated files match the checked-in workspace docs and include the new grooming log file.

What to verify later during a real bootstrap/render/runtime check:

- A real OpenClaw bootstrap emits the updated `AGENTS.md` and `MEMORY.md` files for `main`, `coder`, `architect`, and `watchdog` with the new graph-related sections present and matching the checked-in files.
- The bootstrapped Nextcloud project content includes `/Projects/ai-homebase/archivist-grooming-log.md` with the expected starter table.
- The running archivist cron job receives the new nightly grooming prompt and follows the intended 5-step procedure without regressions in its existing runtime flow.
- The generated bootstrap content from `scripts/bootstrap-config.py` stays aligned with the checked-in workspace files and project bootstrap markdown after a real bootstrap or render path is exercised.
- Agents actually begin producing Qdrant memories with canonical slugs often enough for archivist graph-linking to become easier in practice.

Static validation completed:

- `rg -n "## Graph-Worthy Events" charts/openclaw/files/workspaces/{main,coder,architect,watchdog}/AGENTS.md scripts/bootstrap-config.py`
- `rg -n "## Entity references|canonical graph slug" charts/openclaw/files/workspaces/{main,coder,architect,watchdog}/MEMORY.md scripts/bootstrap-config.py`
- `sed -n '1,220p' scripts/cron-messages/archivist-nightly-grooming.md`
- `rg -n "archivist-grooming-log\\.md" charts/platform-stack/values.yaml scripts/bootstrap-config.py charts/platform-stack/files/bootstrap-content/ai-homebase/projects/archivist-grooming-log.md`
- `git diff -- charts/openclaw/files/workspaces/main/AGENTS.md charts/openclaw/files/workspaces/coder/AGENTS.md charts/openclaw/files/workspaces/architect/AGENTS.md charts/openclaw/files/workspaces/watchdog/AGENTS.md charts/openclaw/files/workspaces/main/MEMORY.md charts/openclaw/files/workspaces/coder/MEMORY.md charts/openclaw/files/workspaces/architect/MEMORY.md charts/openclaw/files/workspaces/watchdog/MEMORY.md scripts/cron-messages/archivist-nightly-grooming.md charts/platform-stack/values.yaml charts/platform-stack/files/bootstrap-content/ai-homebase/projects/archivist-grooming-log.md scripts/bootstrap-config.py`

## 2026-04-03 - Task 8: Strengthen Memory Discipline Across All Agent Workspace Files

Status: statically validated only. Do not treat this as live runtime/bootstrap verified yet.

Scope:

- Updated `charts/openclaw/files/workspaces/{main,architect,coder,archivist,watchdog}/MEMORY.md` to add explicit `When to search`, `When to store`, and `Search tips` sections tailored to each agent.
- Added `charts/openclaw/files/workspaces/auditor/MEMORY.md` with the same overall structure, tailored to audit findings, recurring patterns, anti-patterns, systemic observations, and review artifacts.
- Updated `scripts/bootstrap-config.py` embedded workspace markdown so all six generated `MEMORY.md` files match the checked-in workspace files, including the new auditor memory guide.
- Kept the shared collection wording aligned as `All six agents share one Qdrant collection for durable semantic memory.` across workspace files and bootstrap output.
- Preserved and aligned pre-existing architect-specific memory guidance so the checked-in architect file and bootstrap template no longer drift.

What to verify later during a real bootstrap/render/runtime check:

- A real OpenClaw bootstrap emits all six `MEMORY.md` workspace files with the new sections present and with content matching the checked-in files.
- The bootstrapped auditor workspace now includes `MEMORY.md` and any runtime code that consumes workspace files remains compatible with that added file.
- The generated workspace markdown renders cleanly in the running OpenClaw environment and the added headings/lists are displayed as intended.
- Any agent flows that rely on these instructions actually preserve the stronger search/store behavior once exercised in real sessions.

Static validation completed:

- `rg -n "All five agents share|Search Qdrant before|## " charts/openclaw/files/workspaces/*/MEMORY.md scripts/bootstrap-config.py`
- `rg --files charts/openclaw/files/workspaces`
- `sed -n '1,220p' charts/openclaw/files/workspaces/{main,coder,architect,archivist,watchdog}/MEMORY.md`
- `sed -n '660,740p' scripts/bootstrap-config.py`
- `sed -n '900,980p' scripts/bootstrap-config.py`
- `sed -n '1055,1105p' scripts/bootstrap-config.py`
- `sed -n '1200,1245p' scripts/bootstrap-config.py`
- `sed -n '1390,1435p' scripts/bootstrap-config.py`
- `sed -n '1535,1585p' scripts/bootstrap-config.py`
- `test -f charts/openclaw/files/workspaces/auditor/MEMORY.md && echo auditor-memory-exists`
- `sed -n '1,220p' charts/openclaw/files/workspaces/auditor/MEMORY.md`
- `rg -n "## When to search|## When to store|## Search tips|All five agents share|All six agents share" charts/openclaw/files/workspaces/*/MEMORY.md scripts/bootstrap-config.py`
- `git diff -- charts/openclaw/files/workspaces/main/MEMORY.md charts/openclaw/files/workspaces/coder/MEMORY.md charts/openclaw/files/workspaces/architect/MEMORY.md charts/openclaw/files/workspaces/archivist/MEMORY.md charts/openclaw/files/workspaces/watchdog/MEMORY.md charts/openclaw/files/workspaces/auditor/MEMORY.md scripts/bootstrap-config.py`

## 2026-04-03 - Task 7: Add Auditor to Graph Bootstrap Seed

Status: statically validated only. Do not treat this as live Memgraph-bootstrap, fresh-deploy seed, or Helm-render verified yet.

Scope:

- Added `auditor` to the repo-managed Memgraph bootstrap seed at `charts/platform-stack/files/memgraph-seed.cypher` as `:Entity:Agent:Person` with `name = 'auditor'` and `role = 'reviewer'`.
- Added the corresponding `MATCH (auditor:...)` line in the same seed file so the later relationship block can connect the seeded node idempotently.
- Added auditor graph relationships in the file-backed seed using the conventions already present there:
  `MERGE (auditor)-[:PART_OF]->(openclaw)`,
  `MERGE (auditor)-[:USES_SERVICE]->(nextcloud)`,
  and `MERGE (auditor)-[:USES_SERVICE]->(qdrant)`.
- Updated the embedded bootstrap Cypher in `scripts/bootstrap-config.py` to include the same `auditor` node and service edges, plus `MERGE (openclaw)-[:COORDINATES]->(auditor)` to match that block's existing coordination convention.

What to verify later during a real bootstrap, reseed, or disposable-environment test:

- A fresh deploy or explicit Memgraph bootstrap run creates exactly one `auditor` node in the initial graph.
- The seeded `auditor` node has the expected labels and properties, especially `:Entity:Agent:Person` in the file-backed seed path and `role = 'reviewer'`.
- The expected auditor relationships appear after bootstrap:
  OpenClaw membership/coordination in the relevant seed path and `USES_SERVICE` edges to Nextcloud and Qdrant only.
- The generated bootstrap values path still emits the intended embedded Cypher from `scripts/bootstrap-config.py` without drift from the checked-in seed file.
- No duplicate auditor edges are created when the bootstrap hook is rerun.

Static validation completed:

- Reviewed both graph-seed definitions and added the auditor node and relationships in the local conventions each block already uses.
- Searched the updated files to confirm the new `auditor` `MERGE` / `MATCH` statements appear once per file and that the intended service relationships are present.

Known validation gap:

- No Helm lint/render, bootstrap execution, or live Memgraph query was run in this session for Task 7.

## 2026-04-03 - Task 5: Codex Model Configuration via bootstrap.local.toml

Status: partially validated. Bootstrap validation, chart render checks, and `coder-init.sh` config writing were verified locally; the full `render-values` path remains blocked by a pre-existing unrelated bug.

Scope:

- Added `DEFAULT_CODEX_MODEL = "openai/gpt-5.3-codex"` to `scripts/bootstrap-config.py`.
- Added bootstrap support for `openclaw.agents.coder.codex_model`, including basic `provider/model` validation and propagation into the coder sandbox env as `CODEX_MODEL`.
- Added `codex_model = "openai/gpt-5.3-codex"` to `[openclaw.agents.coder]` in `bootstrap.example.toml`.
- Updated both `charts/platform-stack/values.yaml` and `charts/openclaw/values.yaml` so the default coder sandbox env includes `CODEX_MODEL: openai/gpt-5.3-codex`.
- Updated `images/openclaw-sandbox-coder/coder-init.sh` so sandbox startup writes `${CODEX_HOME}/config.toml` with the bare Codex CLI model name, for example `model = "gpt-5.3-codex"`.
- Updated repo docs to describe the new bootstrap key and coder sandbox Codex model behavior.

What to verify later during a real bootstrap/render/runtime check:

- `python3 scripts/bootstrap-config.py render-values --config bootstrap.local.toml` succeeds once the existing unrelated `workspace_bootstrap_values()` format-string bug is fixed.
- A real bootstrap using `bootstrap.local.toml` passes a non-default `openclaw.agents.coder.codex_model` through to the running coder sandbox env.
- The live coder sandbox writes `${CODEX_HOME}/config.toml` on startup with the expected bare model name for both the default and a non-default configured `codex_model`.
- Codex CLI inside the running sandbox actually honors the rendered config file and uses the configured model.

Validation completed:

- `nix-shell -p python3 --run 'python3 scripts/bootstrap-config.py validate --config bootstrap.example.toml'`
- `nix-shell -p python3 --run 'python3 scripts/bootstrap-config.py shell-vars --config bootstrap.example.toml | rg -n "^CODEX_MODEL=|openai/gpt-5.3-codex"'`
- `nix-shell -p kubernetes-helm --run './scripts/template.sh --release-name platform-stack --namespace ai-homebase --values-file charts/platform-stack/values.yaml | rg -n "CODEX_MODEL|openai/gpt-5.3-codex"'`
- `HOME="$(mktemp -d)/home" CODEX_HOME="$HOME/.codex" XDG_CONFIG_HOME="$HOME/.config" XDG_CACHE_HOME="$HOME/.cache" XDG_STATE_HOME="$HOME/.local/state" DOCKER_CONFIG="$HOME/.docker" CODEX_MODEL="openai/gpt-5.3-codex" CODER_GITEA_USERNAME="coder" CODER_GITEA_EMAIL="coder@example.invalid" bash images/openclaw-sandbox-coder/coder-init.sh`
- `cat "$CODEX_HOME/config.toml"` produced `model = "gpt-5.3-codex"`

## 2026-04-03 - Task 4: Update Existing Agent Workspace Files for Auditor

Status: statically validated only. Do not treat this as live runtime/bootstrap verified yet.

Scope:

- Updated existing workspace files under `charts/openclaw/files/workspaces/{main,architect,coder,archivist,watchdog}/` so `auditor` is referenced in routing heuristics, agent domain boundaries, and session-target examples where applicable.
- Updated main agent budget guidance in `charts/openclaw/files/workspaces/main/AGENTS.md` to include the auditor daily soft budget and revised per-agent allocations that still sum to the unchanged `$12.50` daily total.
- Updated related checked-in workspace support files that still assumed five agents, including `charts/openclaw/files/workspaces/main/BOOTSTRAP.md`, `charts/openclaw/files/workspaces/coder/TOOLS.md`, and the affected workspace `MEMORY.md` files.
- Updated the embedded workspace markdown in `scripts/bootstrap-config.py` to match the checked-in workspace content, including the new auditor routing/domain references and the main budget section.

What to verify later during a real bootstrap/render/runtime check:

- A real OpenClaw bootstrap emits workspace files for `main`, `architect`, `coder`, `archivist`, and `watchdog` that match the updated checked-in markdown and include the auditor references in the intended sections.
- The bootstrapped main workspace content still renders cleanly and the added routing/budget markdown is displayed correctly by the running OpenClaw version.
- Any runtime flows that rely on these textual routing heuristics or session-target examples remain aligned with the actual six-agent topology after bootstrap.

Static validation completed:

- `rg -n "five agents|five standing" charts/openclaw/files/workspaces scripts/bootstrap-config.py`
- `rg -n "Quality review, design review, implementation audit, systemic oversight -> auditor|quality review,|implementation audit|systemic oversight" charts/openclaw/files/workspaces/main/AGENTS.md scripts/bootstrap-config.py`
- `rg -n "Per-agent daily soft allocations|Daily soft budget|Weekly soft budget|Monthly hard ceiling" charts/openclaw/files/workspaces/main/AGENTS.md scripts/bootstrap-config.py`

## 2026-04-03 - Task 3: Auditor Workspace Files

Status: statically validated only. Do not treat this as live runtime/bootstrap verified yet.

Scope:

- Added the full six-file auditor workspace under `charts/openclaw/files/workspaces/auditor/`: `AGENTS.md`, `IDENTITY.md`, `SOUL.md`, `USER.md`, `TOOLS.md`, and `HEARTBEAT.md`.
- Replaced the auditor placeholder workspace content in `scripts/bootstrap-config.py` with the same real markdown content wrapped in `normalize_markdown("""...""")`.
- Removed the auditor `MEMORY.md` placeholder entry from the bootstrap workspace file map so the generated workspace matches the requested six-file layout.

What to verify later during a real bootstrap/render/runtime check:

- A real OpenClaw bootstrap seeds `/home/node/.openclaw/workspace-auditor` with exactly these six files and the expected file contents.
- Any runtime code that reads agent workspace files does not assume every agent has a `MEMORY.md` file and remains compatible with the auditor's six-file workspace.
- The bootstrapped auditor workspace content is exposed through the rendered ConfigMap as intended and consumed correctly by the running OpenClaw version.

Static validation completed:

- `find charts/openclaw/files/workspaces/auditor -maxdepth 1 -type f | sort`
- `sed -n '1,260p' charts/openclaw/files/workspaces/auditor/AGENTS.md`
- `sed -n '1384,1498p' scripts/bootstrap-config.py`
- `rg -n '"MEMORY.md"|Placeholder\.' scripts/bootstrap-config.py charts/openclaw/files/workspaces/auditor -S`

## 2026-04-03 - Task 2: Add Auditor Agent

Status: statically validated only. Do not treat this as live runtime/bootstrap verified yet.

Scope:

- Added a sixth OpenClaw agent, `auditor`, to `scripts/bootstrap-config.py` with default model/fallback constants, rendered `openclaw.json` agent config, `main` subagent allowlist wiring, and placeholder workspace bootstrap files.
- Added `[openclaw.agents.auditor]` defaults to `bootstrap.example.toml`.
- Updated both `charts/platform-stack/values.yaml` and `charts/openclaw/values.yaml` so the chart-owned OpenClaw defaults include the new auditor workspace, model aliases, agent list entry, and `allowAgents` wiring.
- Added the placeholder workspace file at `charts/openclaw/files/workspaces/auditor/AGENTS.md`.
- Updated repo docs and embedded bootstrap markdown to describe a six-agent topology instead of five agents where relevant.

What to verify later during a real bootstrap/render/runtime check:

- A real OpenClaw bootstrap still seeds all six agent workspaces correctly, including the new `/home/node/.openclaw/workspace-auditor` path and placeholder files.
- The rendered `openclaw.json` is accepted by the running OpenClaw version with `sandbox.mode = "off"` on `auditor` and the configured Opus primary plus GPT-5.4 fallback.
- `main` can delegate to `auditor` successfully through the bootstrapped agent-to-agent session flow.
- Any runtime assumptions, cron wiring, or UI surfaces that previously assumed exactly five standing agents are updated or remain compatible.

Static validation completed:

- `nix-shell -p python3 --run "python3 scripts/bootstrap-config.py validate --config bootstrap.example.toml"`
- `rg -n 'five agents|five standing' scripts/bootstrap-config.py`
- `rg -n 'allowAgents:|"allowAgents": \\[|auditor' scripts/bootstrap-config.py charts/platform-stack/values.yaml charts/openclaw/values.yaml bootstrap.example.toml charts/openclaw/files/workspaces/auditor/AGENTS.md`

## 2026-04-03 - Task 21: Generalize AGENTS Guardrail for Render-Impacting Changes

Status: documentation-only update.

Scope:

- Replaced the OpenClaw-model-specific checklist in `AGENTS.md` with a broader render-impacting change checklist that applies to any overlapping base/umbrella values and golden fixtures.
- Kept explicit commands for `scripts/ci/update_golden.sh` and `scripts/ci/check_golden.sh` in the generalized guidance.

Static validation completed:

- `python3 scripts/bootstrap-config.py validate --config bootstrap.example.toml`

## 2026-04-03 - Task 20: Align OpenClaw Base Chart Model Defaults with Umbrella

Status: statically validated only. Do not treat this as live CI/network-verified yet.

Scope:

- Updated `charts/openclaw/values.yaml` default model aliases and `agents.list` primary/fallback entries to the same lineup already set in umbrella values/bootstrap defaults.
- Documented a mandatory model-default update checklist in `AGENTS.md` so future changes also touch base chart defaults and regenerate golden fixtures in one commit.

Root cause addressed:

- Helm values merge retained legacy model alias keys from `charts/openclaw/values.yaml` (`openai/gpt-4.1` and `anthropic/claude-opus-4-6`) even after umbrella overrides changed, causing golden snapshots generated in CI to include unexpected extra model alias entries.

What to verify later during a real CI run:

- `scripts/ci/check_golden.sh` passes on GitHub Actions with network access to configured Helm chart repositories.

Static validation completed:

- `rg -n 'claude-opus-4-6|openai/gpt-4\.1(?!-nano)|gpt-4\.1-mini' charts/openclaw/values.yaml tests/golden --pcre2`

## 2026-04-03 - Task 19: Refresh Golden Snapshots for Agent Model Lineup

Status: statically validated only. Do not treat this as live CI/network-verified yet.

Scope:

- Updated all `tests/golden/*.yaml` fixtures to match the new OpenClaw agent model defaults and fallbacks introduced in Task 18.
- Added explicit golden snapshot maintenance commands to `AGENTS.md` so future render-impacting changes call out updating/checking golden fixtures.

What to verify later during a real CI run:

- `scripts/ci/check_golden.sh` succeeds on a runner with network access to the configured Helm chart repositories.
- Golden snapshot diffs remain focused to intentional render changes when model defaults or agent config change.

Static validation completed:

- `rg -n 'gpt-4\.1(?!-nano)|gpt-4\.1-mini|claude-opus-4-6' tests/golden --pcre2`

## 2026-04-02 - Task 18: Update Default Agent Model Assignments

Status: statically validated only. Do not treat this as live-runtime verified yet.

Scope:

- Updated bootstrap default constants in `scripts/bootstrap-config.py` for `main`, `architect`, `coder`, `archivist`, and `watchdog` model assignments to the new lineup.
- Updated `bootstrap.example.toml` per-agent model and fallback selections to match the new defaults.
- Updated `charts/platform-stack/values.yaml` OpenClaw agent defaults model aliases plus all five `openclaw.agents.list` model primary/fallback entries to match the new lineup.
- Removed old primary-model alias entries no longer used by any agent primary and added aliases for the new OpenAI model IDs.

What to verify later during a real runtime/bootstrap check:

- Bootstrapping with `bootstrap.local.toml` defaults still renders and applies valid OpenClaw model objects in `openclaw.json` for all five agents.
- Agent runtime behavior still honors the configured fallback model order when primary providers are unavailable.
- Any downstream automation or operator docs expecting old model IDs (for example `openai/gpt-4.1` or `anthropic/claude-opus-4-6`) is updated where needed outside this change.

Static validation completed:

- `python3 scripts/bootstrap-config.py validate --config bootstrap.example.toml`
- `rg -n 'gpt-4\.1(?!-nano)' scripts/bootstrap-config.py bootstrap.example.toml charts/platform-stack/values.yaml`
- `rg -n 'opus-4-6' scripts/bootstrap-config.py bootstrap.example.toml charts/platform-stack/values.yaml`


## 2026-04-02 - Task 17: Golden Snapshot Coverage for Rendered OpenClaw ConfigMap

Status: CI-level render validation completed. Do not treat this as live install or runtime verified yet.

Scope:

- Extended `scripts/ci/update_golden.sh` to generate dedicated per-profile OpenClaw ConfigMap snapshots alongside the existing full-manifest snapshots.
- Added committed fixtures at `tests/golden/values-openclaw-configmap.yaml`, `tests/golden/values-k3d-openclaw-configmap.yaml`, and `tests/golden/values-k3s-openclaw-configmap.yaml`.
- Made the OpenClaw snapshot generation fail fast if the rendered `platform-stack-openclaw` ConfigMap is missing, if `data["openclaw.json"]` is missing or invalid JSON, if any rendered agent is missing `model.primary`, or if any rendered agent lacks workspace bootstrap files in the ConfigMap.
- Wired `scripts/ci/check_golden.sh` into `.github/workflows/helm-ci.yml` so CI now enforces the committed golden snapshots instead of only providing update/check scripts without a workflow step.
- Refreshed the existing `tests/golden/values.yaml`, `tests/golden/values-k3d.yaml`, and `tests/golden/values-k3s.yaml` fixtures so they match the current render output.

What to verify later during a real CI run or chart change:

- GitHub Actions runs the new golden snapshot step successfully on a clean runner with the same tool versions used by the repo workflow.
- Future OpenClaw config regressions produce a focused diff in the dedicated `*-openclaw-configmap.yaml` fixtures that is readable enough for review.
- The snapshot extractor continues to find exactly one `platform-stack-openclaw` ConfigMap if chart naming or release naming conventions change.
- The workspace-file presence check remains aligned with the intended bootstrap contract if agent IDs or workspace key naming conventions change.
- A real chart change that intentionally modifies `openclaw.json`, the MCP bridge, or seeded workspace content is caught by CI until `scripts/ci/update_golden.sh` is rerun and the updated fixtures are committed.

Static/CI-style validation completed:

- `nix-shell -p kubernetes-helm python3Packages.pyyaml --run './scripts/ci/update_golden.sh'`
- `nix-shell -p kubernetes-helm python3Packages.pyyaml --run './scripts/ci/check_golden.sh'`

## 2026-04-03 - Task 6: Auditor Weekly Cron Job and Bootstrap Content

Status: statically updated and base-render validated only. Do not treat this as live cron-runtime, live Nextcloud-bootstrap, or gateway-job verified yet.

Scope:

- Added `scripts/cron-messages/auditor-weekly-review.md` with the weekly scheduled audit prompt for the `auditor` agent.
- Added a fifth `ensure_job` entry to `scripts/bootstrap-openclaw-cron.sh` for `Auditor weekly review`.
- Scheduled the new job at `0 3 * * 0` so it runs Sunday at 03:00 UTC, after the existing archivist nightly grooming job at `30 2 * * *`.
- Added seeded Nextcloud project content at `charts/platform-stack/files/bootstrap-content/ai-homebase/projects/audit-log.md`.
- Updated `charts/platform-stack/values.yaml` to include `audit-log.md` in the explicit `nextcloud.bootstrapProjectContent[0].projectsFiles` allowlist.
- Kept `charts/platform-stack/templates/nextcloud-bootstrap-project-content.yaml` unchanged because it already renders the file-backed project-content allowlist generically.

What to verify later during a real runtime, bootstrap, or reseed test:

- Running `scripts/bootstrap-openclaw-cron.sh` against a live OpenClaw deployment creates the `Auditor weekly review` job exactly once and leaves the existing four jobs intact.
- Listing cron jobs back from the gateway shows the new schedule as `0 3 * * 0`, the agent as `auditor`, and the stored message content matching `scripts/cron-messages/auditor-weekly-review.md`.
- The Sunday 03:00 UTC schedule does not create an operational conflict with the existing `Archivist nightly grooming` job at 02:30 UTC when both run in the same environment.
- A fresh Nextcloud bootstrap or explicit reseed creates `/Projects/ai-homebase/audit-log.md` with the expected table formatting.
- The auditor agent can append one-line summaries to `/Projects/ai-homebase/audit-log.md` and create `/Projects/ai-homebase/audit-reports/weekly-YYYY-MM-DD.md` without path or permission issues.
- Existing environments are handled intentionally:
  confirm whether already-seeded project files remain unchanged, are overwritten, or require an explicit reseed path before `audit-log.md` appears.

Static/render validation completed:

- `sed -n '1,120p' scripts/cron-messages/auditor-weekly-review.md`
- `sed -n '100,180p' scripts/bootstrap-openclaw-cron.sh`
- `sed -n '466,486p' charts/platform-stack/values.yaml`
- `nix-shell -p kubernetes-helm --run './scripts/template.sh --release-name platform-stack --namespace ai-homebase --values-file charts/platform-stack/values.yaml > /tmp/platform-stack.yaml && rg -n "write_managed_file .*audit-log|project-0-file" /tmp/platform-stack.yaml'`

Known validation gap:

- No live OpenClaw cron jobs were created or exercised in this session, and no real Nextcloud bootstrap or reseed was run against a cluster.

Suggested later test sequence:

1. Use a disposable environment, not the long-running local stack.
2. Run `scripts/bootstrap-openclaw-cron.sh` against a live OpenClaw deployment, then list jobs back from the gateway and confirm the fifth `Auditor weekly review` entry is present with the intended schedule and full message.
3. Trigger or wait for one weekly auditor run and confirm it stores `/Projects/ai-homebase/audit-reports/weekly-YYYY-MM-DD.md`, appends a one-line entry to `/Projects/ai-homebase/audit-log.md`, and only sends to `main` when it finds critical issues.
4. Bootstrap or reseed the `ai-homebase` Nextcloud project content and confirm `/Projects/ai-homebase/audit-log.md` appears with the expected header and Markdown table intact.

## 2026-04-02 - Task 16: Extract Cron Job Messages into Standalone Files

Status: statically validated only. Do not treat this as live-runtime verified yet.

Scope:

- Added `scripts/cron-messages/` with four standalone markdown prompt files for the documented default OpenClaw cron jobs:
  `watchdog-heartbeat.md`, `watchdog-platform-sweep.md`, `watchdog-daily-digest.md`, and `archivist-nightly-grooming.md`.
- Removed the large inline `--message` bash string literals from `scripts/bootstrap-openclaw-cron.sh`.
- Added a `read_message()` helper to `scripts/bootstrap-openclaw-cron.sh` that resolves prompt file paths relative to `$(dirname "$0")/cron-messages/`.
- Made the script fail fast with a clear `Missing cron message file: ...` error if any expected prompt file is absent.
- Kept the existing cron job names, schedules, agents, sessions, and message text unchanged apart from sourcing the messages from files at runtime.

What to verify later during a real runtime check:

- Running `scripts/bootstrap-openclaw-cron.sh` against a live OpenClaw deployment still results in the same `openclaw cron add` payloads as before for all four jobs.
- The message content reaches OpenClaw byte-for-byte as intended, including any trailing newline behavior from the markdown files.
- The relative-path lookup works correctly when the script is invoked from working directories other than the repo root.
- The missing-file failure path is clear in practice and stops the script before any partial cron seeding occurs.

Static validation completed:

- `bash -n scripts/bootstrap-openclaw-cron.sh`

## 2026-04-02 - Task 15: Extract `mcp-http-bridge.mjs` from ConfigMap Template

Status: statically validated only. Do not treat this as live-runtime verified yet.

Scope:

- Moved the embedded `mcp-http-bridge.mjs` module out of `charts/openclaw/templates/configmap.yaml` into `charts/openclaw/files/mcp-http-bridge.mjs`.
- Updated the OpenClaw ConfigMap template to render `mcp-http-bridge.mjs` via `.Files.Get` instead of embedding the JavaScript inline.
- Kept the ConfigMap key name as `mcp-http-bridge.mjs`.
- Kept the JavaScript module content byte-for-byte identical to the prior inline version.

What to verify later during a real install, upgrade, or runtime check:

- The live OpenClaw ConfigMap still mounts `mcp-http-bridge.mjs` at the expected path with the expected file contents.
- The OpenClaw runtime can still execute the extracted file as a Node.js ES module with no path, permission, or newline regressions.
- Any workflow that invokes the stdio-to-HTTP MCP bridge still behaves identically against the configured MCP HTTP endpoints.

Static validation completed:

- `cmp -s charts/openclaw/files/mcp-http-bridge.mjs <(git show HEAD:charts/openclaw/templates/configmap.yaml | sed -n '/^  mcp-http-bridge.mjs: |$/,/^  {{- if \\.Values\\.workspaceBootstrap\\.enabled }}/p' | sed '1d;$d;s/^    //')`
- `nix-shell --run './scripts/template.sh --release-name platform-stack --namespace ai-homebase --values-file charts/platform-stack/values.yaml > /tmp/rendered-prechange.yaml'` from a dependency-preserving temp workspace with the pre-change `charts/openclaw/templates/configmap.yaml` restored from `HEAD`
- `nix-shell --run './scripts/template.sh --release-name platform-stack --namespace ai-homebase --values-file charts/platform-stack/values.yaml > /tmp/rendered-current.yaml'`
- `diff -u /tmp/rendered-prechange.yaml /tmp/rendered-current.yaml`

## 2026-04-02 - Task 14: File-Backed Nextcloud Bootstrap Content + Memgraph Seed Cypher

Status: statically validated only. Do not treat this as live-bootstrap verified yet.

Scope:

- Moved the inline Nextcloud bootstrap markdown, JSON, and notes content out of `charts/platform-stack/values.yaml` into plain repo files under `charts/platform-stack/files/bootstrap-content/ai-homebase/`.
- Changed the standard `nextcloud.bootstrapProjectContent[]` entry in `charts/platform-stack/values.yaml` to point at `projectsFilesDir` and `notesFilesDir`, while keeping explicit ordered `projectsFiles[].path` and `notes[].path` lists so rendered key ordering stays stable.
- Added `charts/platform-stack/templates/nextcloud-bootstrap-project-content.yaml` so the umbrella chart renders the bootstrap-content ConfigMap from chart-owned files via `.Files.Get`.
- Kept the Nextcloud bootstrap Job in `charts/nextcloud/templates/bootstrap-project-content-job.yaml` and preserved the legacy inline-content path for backward compatibility.
- Moved the inline Memgraph seed Cypher out of `charts/platform-stack/values.yaml` into `charts/platform-stack/files/memgraph-seed.cypher`.
- Updated `charts/platform-stack/templates/memgraph-bootstrap-job.yaml` to load `memgraphBootstrap.seedCypherFile` via `.Files.Get`, with inline `seedCypher` retained as a fallback for backward compatibility.
- Updated chart/docs schema references so the file-backed shape is documented and accepted.

What to verify later during a real bootstrap or upgrade test:

- The Nextcloud bootstrap Job still mounts and reads the umbrella-rendered ConfigMap correctly in a live install or upgrade, not just in `helm template` output.
- The file-backed Nextcloud content preserves exact on-disk file bytes as intended, including trailing newline behavior for markdown, JSON, and nested paths such as `incidents/README.md`.
- A real post-install or post-upgrade hook run still writes the expected files into `/Projects/ai-homebase/` and `/Notes/ai-homebase/` for the `openclaw` user, with no path, permission, or ownership regressions.
- The file-backed ConfigMap move from the `nextcloud` subchart to the umbrella chart does not affect hook behavior, object lifecycle, or any operator tooling that inspects resource provenance.
- The Memgraph bootstrap hook still writes the same Cypher to `/tmp/memgraph-seed.cypher` in the hook pod and executes successfully against a live Memgraph instance.
- Any environment still relying on inline `bootstrapProjectContent[].projectsFiles[].content`, `bootstrapProjectContent[].notes[].content`, or `memgraphBootstrap.seedCypher` continues to render and behave correctly through the fallback paths.

Static validation completed:

- `nix-shell --run 'helm dependency update charts/platform-stack'`
- `nix-shell --run './scripts/template.sh --release-name platform-stack --namespace ai-homebase --values-file charts/platform-stack/values.yaml > /tmp/platform-stack-task14-after.yaml'`
- Rendered archived `HEAD` into `/tmp/platform-stack-task14-before.yaml` and diffed against the updated render.
- Confirmed the Memgraph bootstrap render is unchanged.
- Confirmed the Nextcloud bootstrap Job render is unchanged.
- Confirmed the full-render diff is limited to the bootstrap-content ConfigMap moving from the `nextcloud` subchart to the umbrella chart, which changes Helm `# Source:` provenance and document position but not the rendered ConfigMap payload.

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

## 2026-04-03 - Task 10: Cost Optimization Pass

Status: partially statically validated only. Do not treat this as Helm-render or golden-snapshot verified yet.

Scope:

- Changed the default Codex model from `openai/gpt-5.3-codex` to `openai/gpt-5.4-mini` in `scripts/bootstrap-config.py` and `bootstrap.example.toml`, while leaving `openai/gpt-5.3-codex` documented as a higher-cost override.
- Aligned the archivist default model to `openai/gpt-5.4-mini` in bootstrap defaults and chart values so the documented model lineup matches the intended final lineup.
- Reduced the watchdog heartbeat cron from every 15 minutes to every 30 minutes and expanded the watchdog heartbeat staleness grace from 30 minutes to 60 minutes.
- Replaced the direct `Archivist nightly grooming` cron seed with a new `Watchdog nightly activity check` cron seed and added `scripts/cron-messages/watchdog-nightly-activity-check.md`.
- Removed the old `scripts/cron-messages/archivist-nightly-grooming.md` direct-cron message file.
- Rewrote the main-agent budget system around `tokscale`, Codex usage logs, hard ceilings, off-budget sessions, and model-based spend inference in both the checked-in workspace files and the embedded workspace content generated by `scripts/bootstrap-config.py`.
- Added a `Cost tracking (tokscale)` section to main's `TOOLS.md`.
- Added `Iteration Discipline` guidance to all six standing agent workspaces and mirrored those edits into the embedded bootstrap workspace content.
- Rewrote cost-awareness guidance for architect, coder, archivist, watchdog, and auditor to match the new thresholds and operating rules.
- Added Codex usage logging guidance and JSON log format guidance to coder `AGENTS.md` and `TOOLS.md`, plus matching embedded bootstrap content.
- Added the `/Projects/ai-homebase/codex-usage/` bootstrap directory and removed `/Projects/ai-homebase/budget-ledger.json` from bootstrap content.
- Updated `scripts/cron-messages/auditor-weekly-review.md` with explicit token caps and cheaper read patterns.
- Updated `scripts/cron-messages/watchdog-daily-digest.md` to reference `tokscale` instead of the removed manual ledger.
- Installed `tokscale` in both runtime images that need it:
  `images/openclaw-sandbox-coder/Dockerfile` and `images/openclaw-remote-docker/Dockerfile`.
- Updated `scripts/test-local-k3d.sh` so the seeded cron expectation and gateway-tooling expectation match the new watchdog activity check and the new `tokscale` dependency.
- Updated repo docs in `README.md`, `docs/services.md`, and `docs/configuration.md` so they no longer describe the old Codex default or the old archivist model default.

What to verify later during a real bootstrap, render, or disposable-environment test:

- `python3 scripts/bootstrap-config.py validate --config bootstrap.example.toml` succeeds in an environment that actually has Python available.
- Helm rendering reflects the updated embedded workspace files from `scripts/bootstrap-config.py`, not just the checked-in `charts/openclaw/files/workspaces/*` copies.
- The seeded Nextcloud bootstrap content now creates `/Projects/ai-homebase/codex-usage/` and no longer creates `/Projects/ai-homebase/budget-ledger.json`.
- The OpenClaw cron seeding path now creates `Watchdog nightly activity check` instead of `Archivist nightly grooming`.
- The watchdog heartbeat cron actually runs at the intended 30-minute frequency after seeding in a live gateway.
- The watchdog heartbeat message logic behaves correctly with the new 60-minute staleness threshold and does not create noisy false positives.
- The watchdog nightly activity check can read the heartbeat file and daily Codex usage file cheaply, and can trigger `agent:archivist:main` only on meaningfully active days.
- The watchdog daily digest can run `tokscale --openclaw --today --group-by model --json` successfully inside the gateway runtime.
- The watchdog budget-sentinel guidance is operationally valid:
  `tokscale --openclaw --today --json` and `openclaw status --usage` must both work in the gateway runtime used by watchdog.
- The coder sandbox image can run both `codex` and `tokscale headless codex exec ...`, and the documented Codex usage log format is practical to append in real coder sessions.
- The gateway image has `tokscale` available at runtime and the k3d smoke test expectation around gateway tooling still matches the actual image contents.
- The docs and workspace guidance around off-budget sessions, hard ceilings, and Codex logging are consistent with the user-facing coordination flow in practice.
- The embedded bootstrap workspace files in `scripts/bootstrap-config.py` still stay in sync with the checked-in workspace files after future edits.

Static validation completed:

- Repo-wide search confirmed the checked-in workspace files, cron messages, bootstrap content paths, and docs no longer rely on the old manual budget-ledger workflow.
- Repo-wide search confirmed the new tokscale references, Codex usage log path, 30-minute heartbeat frequency, and watchdog nightly activity check are present in the expected files.
- Reviewed the diffs to confirm `tokscale` is installed in both the coder sandbox image and the repo-managed OpenClaw gateway image.

Known validation gaps:

- This workspace does not have `python3` available directly, so `scripts/bootstrap-config.py validate` and `py_compile` could not be run locally without a Nix shell.
- The repo's canonical Nix-based validation and golden-refresh commands require access to the host Nix daemon, which is sandbox-blocked in this session unless elevated execution is approved.
- Golden files under `tests/golden/` still reflect the pre-change ledger-based content until `./scripts/ci/update_golden.sh` and `./scripts/ci/check_golden.sh` are run in a suitable environment.
- `charts/openclaw/values.yaml`, `charts/platform-stack/values.yaml`, and `images/openclaw-sandbox-coder/coder-init.sh` still intentionally carry `CODEX_MODEL: openai/gpt-5.3-codex` for the current sandbox runtime path because the user explicitly scoped that env/config rewiring to a later task.

Suggested later test sequence:

1. Run `python3 scripts/bootstrap-config.py validate --config bootstrap.example.toml`.
2. Run `python3 -m py_compile scripts/bootstrap-config.py`.
3. Run `nix-shell -p kubernetes-helm python3Packages.pyyaml --run "./scripts/ci/update_golden.sh"`.
4. Run `nix-shell -p kubernetes-helm python3Packages.pyyaml --run "./scripts/ci/check_golden.sh"`.
5. Render the shared platform stack and inspect the OpenClaw ConfigMap plus bootstrap project-content seed output for the updated workspaces, the removed `budget-ledger.json`, and the new `codex-usage/.gitkeep` path.
6. Seed the cron jobs in a disposable gateway and confirm `Watchdog nightly activity check` is present and `Archivist nightly grooming` is absent.
7. Verify `command -v tokscale` succeeds in both the gateway pod and the coder sandbox image.
