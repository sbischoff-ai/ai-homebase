RELEASE_NAME ?= platform-stack
NAMESPACE ?= ai-homebase
BOOTSTRAP_CONFIG ?= bootstrap.local.toml
K3D_CLUSTER_NAME ?= ai-homebase-dev
BASE_VALUES := charts/platform-stack/values.yaml
K3D_VALUES := charts/platform-stack/values-k3d.yaml
K3S_VALUES := charts/platform-stack/values-k3s.yaml

.PHONY: help lint lint-k3d lint-k3s render render-k3d render-k3s smoke-k3d

help:
	@echo "ai-homebase command wrappers"
	@echo
	@echo "Targets:"
	@echo "  lint        Lint with shared default values"
	@echo "  lint-k3d    Lint with layered values + k3d profile"
	@echo "  lint-k3s    Lint with layered values + k3s profile"
	@echo "  render      Render manifests using shared default values"
	@echo "  render-k3d  Render manifests using layered values + k3d profile"
	@echo "  render-k3s  Render manifests using layered values + k3s profile"
	@echo "  smoke-k3d   Run the full k3d bootstrap including smoke checks"
	@echo "  help        Show this help output"
	@echo
	@echo "Examples:"
	@echo "  make lint"
	@echo "  make render > /tmp/platform-stack.yaml"
	@echo "  make render-k3d > /tmp/platform-stack-k3d.yaml"
	@echo "  make render-k3s > /tmp/platform-stack-k3s.yaml"
	@echo "  make smoke-k3d BOOTSTRAP_CONFIG=bootstrap.local.toml"

lint:
	./scripts/lint.sh --values-file $(BASE_VALUES)

lint-k3d:
	./scripts/lint.sh --values-file $(BASE_VALUES) --values-file $(K3D_VALUES)

lint-k3s:
	./scripts/lint.sh --values-file $(BASE_VALUES) --values-file $(K3S_VALUES)

render:
	./scripts/template.sh --release-name $(RELEASE_NAME) --namespace $(NAMESPACE) --values-file $(BASE_VALUES)

render-k3d:
	./scripts/template.sh --release-name $(RELEASE_NAME) --namespace $(NAMESPACE) --values-file $(BASE_VALUES) --values-file $(K3D_VALUES)

render-k3s:
	./scripts/template.sh --release-name $(RELEASE_NAME) --namespace $(NAMESPACE) --values-file $(BASE_VALUES) --values-file $(K3S_VALUES)

smoke-k3d:
	./scripts/bootstrap-stack.sh --profile k3d --cluster-name $(K3D_CLUSTER_NAME) --bootstrap-config $(BOOTSTRAP_CONFIG) --release-name $(RELEASE_NAME) --namespace $(NAMESPACE)
