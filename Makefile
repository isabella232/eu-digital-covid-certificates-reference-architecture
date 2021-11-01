SHELL:=/bin/bash
ROOT_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
PREFIX = $(shell cat $(ROOT_DIR)/terraform.tfvars| grep ^prefix | cut -d'"' -f2)
VERSION=$(shell git describe --long --tags)

define COMPLETION_TEXT_BODY
Congratulations!

APECOE's Privacy focused Blueprint of the EU Digital Green Certificate, (Version: "$(VERSION)") has been successfully deployed!

Please refer to the documentation, to issue and verify your signed test certificates. https://azure.github.io/eu-digital-covid-certificates-reference-architecture/ .

You can SSH into the regions Jumpbox to view the Kubernetes Cluster, Databases and key vaults secrets and perform operations, by the following commands:
EU jumpbox:
$(shell $(MAKE) -sC eudcc-eu print-ssh-cmd)

IE jumpbox:
$(shell $(MAKE) -sC eudcc-ie print-ssh-cmd)


To issue your first test Cert, in you Web Browser head to: $(shell $(MAKE) -sC eudcc-ie output-issuance-web-address)

Required Endpoints to apply when building the Android Apps:
- Issuance Service: $(shell $(MAKE) -sC eudcc-ie output-issuance-service-url)
- Business Rule Service: $(shell $(MAKE) -sC eudcc-ie output-businessrule-service-url)
- Verifier Service: $(shell $(MAKE) -sC eudcc-ie output-verifier-service-url)

Enjoy! 😀


endef
export COMPLETION_TEXT_BODY

ifeq ($(strip $(PREFIX)),)
	WORKSPACE = "default"
else
	WORKSPACE = $(PREFIX)
endif

.PHONY: all
all: checks certs terraform

.PHONY: checks
checks:
	@echo "Verifying terraform.tfvars file exists"
	@test -f terraform.tfvars || { echo "FAIL: Please create and populate the terraform.tfvars file before proceeding"; exit 1; }

	@echo "Ensure az CLI has access to the specified subscription"
	@az account show -s $$(cat terraform.tfvars| grep ^subscription_id | cut -d'"' -f2) &>/dev/null || { echo "FAIL: Please run \`az login\` before proceeding"; exit 1; }

.PHONY: certs
certs:
	$(ROOT_DIR)/scripts/generate-certs.sh

.PHONY: workspace
workspace: checks
	WORKSPACE=$(WORKSPACE) $(MAKE) -C eudcc-dev workspace
	WORKSPACE=$(WORKSPACE) $(MAKE) -C eudcc-eu workspace
	WORKSPACE=$(WORKSPACE) $(MAKE) -C eudcc-ie workspace

.PHONY: dev
dev: checks
	$(MAKE) -C eudcc-dev terraform
	$(MAKE) -C eudcc-dev ssh-config

.PHONY: eu
eu: checks
	$(MAKE) -C eudcc-eu all

.PHONY: ie
ie: checks
	$(MAKE) -C eudcc-ie all

.PHONY: terraform
terraform: workspace dev eu ie print-completion-msg

.PHONY: terraform-destroy
terraform-destroy: checks
	$(MAKE) -C eudcc-ie terraform-destroy
	$(MAKE) -C eudcc-eu terraform-destroy
	$(MAKE) -C eudcc-dev terraform-destroy

.PHONY: start-all-tunnels
start-all-tunnels: checks
	$(MAKE) -C eudcc-eu ssh-tunnel-start
	$(MAKE) -C eudcc-ie ssh-tunnel-start

.PHONY: stop-all-tunnels
stop-all-tunnels:
	$(MAKE) -C eudcc-eu ssh-tunnel-stop
	$(MAKE) -C eudcc-ie ssh-tunnel-stop

.PHONY: print-ssh-cmd
print-ssh-cmd:
	@$(MAKE) -C eudcc-eu print-ssh-cmd
	@$(MAKE) -C eudcc-ie print-ssh-cmd

.PHONY: print-hostnames
print-hostnames:
	@$(MAKE) -C eudcc-eu output-hostnames
	@$(MAKE) -C eudcc-ie output-hostnames

.PHONY: print-completion-msg
print-completion-msg:
	@echo "$$COMPLETION_TEXT_BODY"