RELEASE_NAME ?= platform-stack
NAMESPACE ?= ai-homebase
DEV_VALUES := charts/platform-stack/values-dev.yaml
K3D_VALUES := charts/platform-stack/values-k3d.yaml

.PHONY: help lint lint-k3d render render-k3d smoke-k3d

help:
	@echo "ai-homebase command wrappers"
	@echo
	@echo "Targets:"
	@echo "  lint        Lint with dev values profile"
	@echo "  lint-k3d    Lint with layered dev + k3d values profiles"
	@echo "  render      Render manifests using dev values profile"
	@echo "  render-k3d  Render manifests using layered dev + k3d profiles"
	@echo "  smoke-k3d   Deploy and run local k3d smoke checks"
	@echo "  help        Show this help output"
	@echo
	@echo "Examples:"
	@echo "  make lint"
	@echo "  make render > /tmp/platform-stack-dev.yaml"
	@echo "  make render-k3d > /tmp/platform-stack-k3d.yaml"
	@echo "  make smoke-k3d"

lint:
	./scripts/lint.sh --values-file $(DEV_VALUES)

lint-k3d:
	./scripts/lint.sh --values-file $(DEV_VALUES) --values-file $(K3D_VALUES)

render:
	./scripts/template.sh --release-name $(RELEASE_NAME) --namespace $(NAMESPACE) --values-file $(DEV_VALUES)

render-k3d:
	./scripts/template.sh --release-name $(RELEASE_NAME) --namespace $(NAMESPACE) --values-file $(DEV_VALUES) --values-file $(K3D_VALUES)

smoke-k3d:
	./scripts/test-local-k3d.sh --release-name $(RELEASE_NAME) --namespace $(NAMESPACE)
