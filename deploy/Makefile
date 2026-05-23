.PHONY: help preflight mgmt capi cluster platform validate export all clean

SCRIPTS := scripts
export PATH := $(CURDIR)/$(SCRIPTS):$(PATH)

help:
	@echo "hetzner-provision deploy targets:"
	@echo "  make preflight   - validate tools, env, server types"
	@echo "  make mgmt        - Kind management cluster"
	@echo "  make capi        - clusterctl init + Hetzner secrets"
	@echo "  make cluster     - generate/apply workload cluster + kubeconfig"
	@echo "  make platform    - install full-platform add-ons"
	@echo "  make validate    - smoke checks on workload cluster"
	@echo "  make export      - export CAPI manifests snapshot"
	@echo "  make all         - preflight through platform (no validate)"
	@echo "  make clean-mgmt  - delete Kind mgmt cluster (destructive)"

preflight:
	./$(SCRIPTS)/preflight.sh

mgmt:
	./$(SCRIPTS)/00-mgmt-kind.sh

capi: mgmt
	./$(SCRIPTS)/01-capi-init.sh

cluster: capi
	./$(SCRIPTS)/02-workload-cluster.sh

platform: cluster
	./$(SCRIPTS)/03-platform.sh

validate:
	./$(SCRIPTS)/04-validate.sh

export:
	./$(SCRIPTS)/05-export-snapshot.sh

all: preflight cluster platform

clean-mgmt:
	kind delete cluster --name "$${MGMT_CLUSTER_NAME:-hetzner-mgmt}" || true
