.PHONY: help create

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


##@ General

help: ## Display this help
	@awk -v cyan="$(CYAN)" -v bold="$(BOLD)" -v reset="$(RESET)" "$$HELP_SCRIPT" $(MAKEFILE_LIST)

##@ VMs

create: ## Create all VMs
	sudo ./scripts/create-vms.sh "$$(cat ~/.ssh/id_ed25519.pub)"
