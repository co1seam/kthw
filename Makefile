.PHONY: help create status destroy

CYAN  := \033[36m
BOLD  := \033[1m
RESET := \033[0m

define HELP_SCRIPT
BEGIN {
	FS = ":.*##"
	printf "\nUsage:\n  make %s<target>%s\n", cyan, reset
} 
/^[a-zA-Z_0-9-]+:.*?##/ {
	printf " %s%-15s%s %s\n", cyan, $$1, reset, $$2 
}
/^##@/ {
	printf "\n%s%s%s\n", bold, substr($$0, 5), reset
}
endef
export HELP_SCRIPT

INSTANCES_FILE ?= instances
SSH_KEY_FILE   ?= $(HOME)/.ssh/id_ed25519.pub

CONTROLLERS   := $(shell awk -F: '!/^#/ && $$2=="controller" {print $$1}' $(INSTANCES_FILE))
WORKERS       := $(shell awk -F: '!/^#/ && $$2=="worker"	 {print $$1}' $(INSTANCES_FILE))
ALL_INSTANCES := $(shell awk -F: '!/^#/ && NF                {print $$1}' $(INSTANCES_FILE))

##@ General

help: ## Display this help
	@awk -v cyan="$(CYAN)" -v bold="$(BOLD)" -v reset="$(RESET)" "$$HELP_SCRIPT" $(MAKEFILE_LIST)

##@ VMs

create: ## Create all VMs
	@sudo ./scripts/create-vms.sh "$$(cat $(SSH_KEY_FILE))" "$(INSTANCES_FILE)"

destroy: ## Destroy all VMs and their disks
	@for vm in $(ALL_INSTANCES); do \
		echo "Destroing $$vm..."; \
		virsh destroy "$$vm" 2>/dev/null || true; \
		virsh undefine "$$vm" --remove-all-storage --nvram 2>/dev/null || true; \
	done
	@sudo rm -f /tmp/*-user-data.yaml /tmp/*-network-config.yaml

##@ Info

status: ## Show status of VMs, network and DHCP leases
	@printf "\n$(BOLD) --- Virtual Machines ---$(RESET)\n"
	@virsh list --all
	@printf "\n$(BOLD) --- Network ---$(RESET)\n"
	@virsh net-list --all
	@printf "\n$(BOLD) --- Instances ---$(RESET)\n"
	@awk -F: '!/^#/ && NF {printf " %-12s %-12s %-15s (%s MD, %s vCPU)\n", $$1, $$2, $$5, $$3, $$4}' $(INSTANCES_FILE)
