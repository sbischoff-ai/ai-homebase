# Architecture

`ai-homebase` is structured as a modular platform:

1. **Core AI plane** (OpenClaw + OpenHands).
2. **Supporting personal-cloud services** (optional, enabled per environment).

This separation keeps the primary AI workflow deployable even when optional apps are disabled.

## 1) Core AI plane

### OpenClaw (general AI assistant)

OpenClaw is the general AI assistant service and primary user-facing assistant experience.

Responsibilities:

- User-facing assistant API/UI with ingress controlled per profile overlay (baseline and shipped overlays keep `openclaw.ingress.enabled: false`).
- Assistant chat/API interactions for general AI use.
- User/session-facing request handling and policy enforcement.
- Integration point for platform-level auth and assistant configuration.

Default posture:

- Private service posture by default (`openclaw.ingress.enabled: false` in baseline and shipped profile overlays); expose only through explicit environment ingress decisions.
- Smaller durable data profile than execution workloads.
- Security-sensitive due to user-facing interface.

### OpenHands (execution plane)

OpenHands is an agentic coding platform with a user-facing UI/API.

Responsibilities:

- Queue/job consumption.
- Workspace lifecycle and runtime execution.
- Artifact and status propagation back to control-plane integrations.
- Independent horizontal scaling under execution load.

Default posture:

- Profile-specific ingress posture: baseline/AKS/prod keep `openhands.ingress.enabled: false`; local dev/k3d overlays may enable ingress for direct UI/API workflows.
- Larger and more variable storage/compute profile.
- Node/isolation controls expected for production workloads.

## 2) Supporting personal-cloud services (optional)

These services are intentionally optional and toggleable:

- **Nextcloud**: collaboration and file sync.
- **Gitea**: git hosting and project collaboration.
- **Paperless-ngx**: document pipeline and archive.
- **Infisical**: in-cluster secret-management option.
- **wg-easy**: VPN management and secure private access.

They can run alongside the core plane for a single "personal cloud" footprint, but should not be treated as mandatory dependencies for core AI operations.

## Data and trust boundaries

High-level flow:

1. Users access OpenClaw for general AI assistant interactions.
2. Users access OpenHands for agentic coding workflows via UI/API.
3. Optional personal-cloud services are exposed when enabled for their own UI/API use cases.
4. Environment overlays enforce exposure, security, and policy posture per service.

Boundary goal:

- Expose user/API entrypoints for enabled services.
- Keep high-variance execution risk inside OpenHands with isolation controls.
- Keep optional services isolated behind explicit toggles and policy.

## Composition model in `platform-stack`

The umbrella chart provides:

- A single release for core + optional services.
- Service-level toggles (`<service>.enabled`) for optional components.
- Shared global values (`global.*`) for cross-service defaults.
- Per-service overrides for divergent runtime requirements.

## Intentional placeholders and hardening gaps

The architecture intentionally leaves operator decisions unresolved in source control:

- Queue and broker implementation details.
- External secret provider/store mappings.
- Final network policy allow/deny rules.
- Production-grade observability and alert routing.

Before production, close these gaps with environment-specific overlays and documented runbooks.
