# Makefile for the libvirt OpenTofu experiment.
#
#   make help    list targets
#   make docs    render docs/*.mmd -> docs/*.svg
#   make apply   tofu init + apply (provisions the VM)
#
# Prereqs: OpenTofu (>= 1.6) in PATH; node/npx + perl for `make docs`.

MMDC   ?= npx -y @mermaid-js/mermaid-cli
TOFU   ?= tofu
TF_DIR := tf

DIAGRAMS := docs/architecture.svg docs/deployment-flow.svg

.DEFAULT_GOAL := help

.PHONY: help docs day0 init plan apply destroy output ip ssh fmt validate clean

help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

# --- documentation -----------------------------------------------------------

docs: $(DIAGRAMS) ## Render diagrams (docs/*.mmd -> docs/*.svg)

docs/%.svg: docs/%.mmd
	$(MMDC) -i $< -o $@
	# mmdc inlines the Recursive font as base64 (~200 KB/diagram); strip the
	# @font-face blocks and OFL license text so the committed SVGs stay small
	# and fall back to Arial/sans-serif with no visual regression.
	perl -0pi -e 's{/\*.*?SIL OPEN FONT LICENSE.*?\*/}{}gs; s/\@font-face\s*\{[^}]*\}//gs' $@

# --- host bootstrap ----------------------------------------------------------

day0: ## Bootstrap the host (packages, daemons, libvirt group, pool)
	sudo ./$(TF_DIR)/day0.sh

# --- opentofu ----------------------------------------------------------------

init: ## Install providers (idempotent)
	$(TOFU) -chdir=$(TF_DIR) init

plan: init ## Show the execution plan
	$(TOFU) -chdir=$(TF_DIR) plan

apply: init ## Provision (confirms before applying)
	$(TOFU) -chdir=$(TF_DIR) apply

destroy: init ## Tear the VM, network and volumes down
	$(TOFU) -chdir=$(TF_DIR) destroy

output: ## Show all outputs
	$(TOFU) -chdir=$(TF_DIR) output

ip: ## Print the guest IP only
	@$(TOFU) -chdir=$(TF_DIR) output -raw vm_ip

ssh: ## SSH into the guest (key-only, via ssh_command output)
	@eval "$$($(TOFU) -chdir=$(TF_DIR) output -raw ssh_command)"

fmt: ## Format the OpenTofu files
	$(TOFU) -chdir=$(TF_DIR) fmt -recursive

validate: init ## Validate the configuration
	$(TOFU) -chdir=$(TF_DIR) validate

clean: ## Delete rendered SVGs (make docs regenerates them)
	rm -f $(DIAGRAMS)
