# Terraform tasks for the fortune infrastructure.
#
# The workflows in .github/workflows/ are the authority on what runs in CI.
# These targets are the same commands for use from a laptop, and `make check`
# runs the two gates the infra pipeline's plan job runs first.
#
# The state bucket name contains the account ID, so it is resolved by calling
# AWS. That call is lazy: it happens only in a target that needs the bucket,
# and never for `make help`. Pass BUCKET=... to skip it.
#
# Override any variable on the command line, for example:
#   make plan BUCKET=fortune-tfstate-123456789012
#   make forward LOCAL_PORT=9000

PROJECT    ?= fortune
AWS_REGION ?= eu-west-1
LOCAL_PORT ?= 8080
TF         ?= terraform

ACCOUNT = $(shell aws sts get-caller-identity --query Account --output text 2>/dev/null)
BUCKET  ?= $(PROJECT)-tfstate-$(ACCOUNT)

BACKEND  = -backend-config="bucket=$(BUCKET)"
EPH_VARS = -var="state_bucket=$(BUCKET)"

DURABLE   := layers/durable
EPHEMERAL := layers/ephemeral

# Init markers. The two layers use an S3 backend, and backend initialisation is
# what writes .terraform/terraform.tfstate, so that file is the honest marker.
# Bootstrap keeps local state, so the directory itself is enough.
BOOTSTRAP_INIT := bootstrap/.terraform
DURABLE_INIT   := $(DURABLE)/.terraform/terraform.tfstate
EPHEMERAL_INIT := $(EPHEMERAL)/.terraform/terraform.tfstate

.DEFAULT_GOAL := help

.PHONY: help account require-aws fmt fmt-check validate check init \
	    bootstrap-plan bootstrap-apply bootstrap-output vars \
	    plan plan-durable plan-ephemeral \
	    apply apply-durable apply-ephemeral up down \
	    output verify session forward destroy-all clean

help: ## List the available targets
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	    | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-17s %s\n", $$1, $$2}'
	@echo ""
	@echo "Project: $(PROJECT)   Region: $(AWS_REGION)"
	@echo "Run 'make account' to resolve the account ID and state bucket."

# Every target that touches AWS depends on this. An expired session would
# otherwise resolve the account ID to an empty string, and the bucket name
# built from it would be wrong rather than missing.
require-aws:
	@aws sts get-caller-identity >/dev/null 2>&1 || { \
	    echo "AWS credentials are not valid. Run 'aws login', or 'aws sso login --profile default'."; \
	    exit 1; \
	}

account: require-aws ## Print the account ID and the state bucket name
	@echo "Account: $(ACCOUNT)"
	@echo "Bucket:  $(BUCKET)"

# ---------------------------------------------------------------------------
# Static checks. These need no AWS credentials and no state.
# ---------------------------------------------------------------------------

fmt: ## Rewrite every .tf file into canonical form
	$(TF) fmt -recursive .

fmt-check: ## Fail if any .tf file is not in canonical form
	$(TF) fmt -check -recursive .

validate: ## Validate all three roots
	$(TF) -chdir=bootstrap validate
	$(TF) -chdir=$(DURABLE) validate
	$(TF) -chdir=$(EPHEMERAL) validate

check: fmt-check validate ## Run both gates the plan job runs before planning

# ---------------------------------------------------------------------------
# Initialisation. A root is initialised on demand by the targets below, so
# this one is for reinitialising after a backend or provider change.
# ---------------------------------------------------------------------------

init: require-aws ## Reinitialise all three roots, reconfiguring the backends
	$(TF) -chdir=bootstrap init -input=false
	$(TF) -chdir=$(DURABLE) init -input=false -reconfigure $(BACKEND)
	$(TF) -chdir=$(EPHEMERAL) init -input=false -reconfigure $(BACKEND)

$(BOOTSTRAP_INIT):
	$(TF) -chdir=bootstrap init -input=false

$(DURABLE_INIT):
	@$(MAKE) --no-print-directory require-aws
	$(TF) -chdir=$(DURABLE) init -input=false $(BACKEND)

$(EPHEMERAL_INIT):
	@$(MAKE) --no-print-directory require-aws
	$(TF) -chdir=$(EPHEMERAL) init -input=false $(BACKEND)

# ---------------------------------------------------------------------------
# Bootstrap. Local state, applied by hand, once. It creates the state bucket
# that the two layers store their state in, so it cannot store its own there.
# Note there is no destroy target: the bucket carries prevent_destroy.
# ---------------------------------------------------------------------------

bootstrap-plan: require-aws $(BOOTSTRAP_INIT) ## Plan the bootstrap root
	$(TF) -chdir=bootstrap plan

bootstrap-apply: require-aws $(BOOTSTRAP_INIT) ## Apply the bootstrap root. Needs bootstrap/terraform.tfvars
	$(TF) -chdir=bootstrap apply

bootstrap-output: ## Show the bootstrap outputs
	$(TF) -chdir=bootstrap output

vars: require-aws ## Publish the bootstrap outputs as GitHub repository variables
	@$(TF) -chdir=bootstrap output -json github_variables_to_set \
	    | jq -r 'to_entries[] | "\(.key)\t\(.value)"' \
	    | while IFS=$$'\t' read -r k v; do echo "setting $$k"; gh variable set "$$k" --body "$$v"; done

# ---------------------------------------------------------------------------
# The two layers. Durable first and ephemeral second, always, because the
# ephemeral layer reads the durable layer's outputs through remote state.
# Consequently the ephemeral targets fail until the durable layer is applied.
# ---------------------------------------------------------------------------

plan-durable: require-aws $(DURABLE_INIT) ## Plan the durable layer
	$(TF) -chdir=$(DURABLE) plan -lock-timeout=5m

plan-ephemeral: require-aws $(EPHEMERAL_INIT) ## Plan the ephemeral layer
	$(TF) -chdir=$(EPHEMERAL) plan -lock-timeout=5m $(EPH_VARS)

plan: plan-durable plan-ephemeral ## Plan both layers, durable first

apply-durable: require-aws $(DURABLE_INIT) ## Apply the durable layer
	$(TF) -chdir=$(DURABLE) apply -lock-timeout=5m

apply-ephemeral: require-aws $(EPHEMERAL_INIT) ## Apply the ephemeral layer
	$(TF) -chdir=$(EPHEMERAL) apply -lock-timeout=5m $(EPH_VARS)

apply: apply-durable apply-ephemeral ## Apply both layers, durable first

up: apply-ephemeral ## Bring the environment up. The local equivalent of env-up

# Terraform prompts for confirmation here, deliberately. The env-down workflow
# passes -auto-approve because nothing can answer a prompt at 21:00 UTC, but a
# person running this has a keyboard.
down: require-aws $(EPHEMERAL_INIT) ## Take the environment down. Destroys the ephemeral layer only
	$(TF) -chdir=$(EPHEMERAL) destroy -lock-timeout=5m $(EPH_VARS)

# ---------------------------------------------------------------------------
# Reaching the running service. There is no public ingress, so every route
# goes through Session Manager, which opens no inbound port on the bastion.
# ---------------------------------------------------------------------------

output: require-aws ## Show the ephemeral layer's outputs
	$(TF) -chdir=$(EPHEMERAL) output

verify: require-aws ## Print the two commands that reach the service
	@$(TF) -chdir=$(EPHEMERAL) output -json verify_commands \
	    | jq -r '.open_session, .port_forward'

session: require-aws ## Open an SSM session on the bastion
	@id=$$($(TF) -chdir=$(EPHEMERAL) output -raw bastion_instance_id); \
	echo "Connecting to $$id"; \
	aws ssm start-session --target "$$id"

forward: require-aws ## Forward the service's port 8080 to a local port (LOCAL_PORT, default 8080)
	@id=$$($(TF) -chdir=$(EPHEMERAL) output -raw bastion_instance_id); \
	echo "Forwarding app.$(PROJECT).internal:8080 to localhost:$(LOCAL_PORT)"; \
	aws ssm start-session --target "$$id" \
	    --document-name AWS-StartPortForwardingSessionToRemoteHost \
	    --parameters host=app.$(PROJECT).internal,portNumber=8080,localPortNumber=$(LOCAL_PORT)

# ---------------------------------------------------------------------------
# Teardown and housekeeping.
# ---------------------------------------------------------------------------

# Guarded, because it removes the VPC, the ECR repository and the IAM roles as
# well. Bootstrap is untouched either way: the state bucket carries
# prevent_destroy, so removing it means editing bootstrap/state.tf first.
destroy-all: ## Destroy both layers. Requires CONFIRM=yes
	@if [ "$(CONFIRM)" != "yes" ]; then \
	    echo "Refusing: this destroys the durable layer too."; \
	    echo "Run 'make destroy-all CONFIRM=yes' if that is what you want."; \
	    exit 1; \
	fi
	@$(MAKE) --no-print-directory require-aws
	$(TF) -chdir=$(EPHEMERAL) destroy -lock-timeout=5m $(EPH_VARS)
	$(TF) -chdir=$(DURABLE) destroy -lock-timeout=5m

clean: ## Remove saved plan files
	rm -f bootstrap/tfplan $(DURABLE)/tfplan $(EPHEMERAL)/tfplan
