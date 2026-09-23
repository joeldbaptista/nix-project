# Development tasks for the fortune service.
#
# The pipeline in .github/workflows/app.yml is the authority on what must pass
# before a deployment. `make check` runs the same two gates it does, so a green
# check here means the pipeline's lint and test jobs will also be green.
#
# Override any variable on the command line, for example:
#   make build TAG=v2
#   make run PORT=9000

PYTHON ?= python3
VENV   := .venv
BIN    := $(VENV)/bin
STAMP  := $(VENV)/.installed

PROJECT    ?= fortune
IMAGE      ?= fortune-app
TAG        ?= local
PORT       ?= 8080
CONTAINER  ?= fortune-local
AWS_REGION ?= eu-west-1

# The repository is not under git yet, so the fallback keeps this working.
GIT_SHA ?= $(shell git rev-parse HEAD 2>/dev/null || echo local)

.DEFAULT_GOAL := help

.PHONY: help venv lint format test check build run smoke serve db seed clean clean-all

help: ## List the available targets
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	    | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-10s %s\n", $$1, $$2}'
	@echo ""
	@echo "Image: $(IMAGE):$(TAG)   Port: $(PORT)   Commit: $(GIT_SHA)"

# The stamp depends on pyproject.toml, so dependencies reinstall when they
# change and not on every invocation.
$(STAMP): pyproject.toml
	$(PYTHON) -m venv $(VENV)
	$(BIN)/pip install --quiet --upgrade pip
	$(BIN)/pip install --quiet -e ".[dev]"
	@touch $@

venv: $(STAMP) ## Create the virtual environment and install dependencies

lint: $(STAMP) ## Check style and formatting, exactly as the pipeline does
	$(BIN)/ruff check .
	$(BIN)/ruff format --check .

format: $(STAMP) ## Rewrite the code to satisfy the formatter and the fixable rules
	$(BIN)/ruff format .
	$(BIN)/ruff check --fix .

test: $(STAMP) ## Run the unit tests
	$(BIN)/pytest -q

check: lint test ## Run everything the pipeline gates a deployment on

build: ## Build the container image for this machine's architecture
	docker build --build-arg GIT_SHA=$(GIT_SHA) -t $(IMAGE):$(TAG) .

run: build ## Build, then run the image in the foreground
	docker run --rm -p $(PORT):8080 --name $(CONTAINER) $(IMAGE):$(TAG)

smoke: build ## Build, start the container, call both endpoints, then remove it
	@docker rm -f $(CONTAINER) >/dev/null 2>&1 || true
	@docker run -d --rm -p $(PORT):8080 --name $(CONTAINER) $(IMAGE):$(TAG) >/dev/null
	@for i in $$(seq 1 30); do \
	    curl -fsS http://localhost:$(PORT)/health >/dev/null 2>&1 && break; \
	    sleep 0.5; \
	done
	@echo "GET /health -> $$(curl -fsS http://localhost:$(PORT)/health)"
	@echo "GET /       -> $$(curl -fsS http://localhost:$(PORT)/)"
	@docker rm -f $(CONTAINER) >/dev/null

serve: $(STAMP) ## Run the service locally with reload, no container involved
	$(BIN)/uvicorn fortune.main:app --host 127.0.0.1 --port $(PORT) --reload

db: $(STAMP) ## Build the fortune cookie database into ./cookie.duckdb for inspection
	$(BIN)/python -m fortune.cookies cookie.duckdb
	@echo "Wrote cookie.duckdb. It is git-ignored, and the image builds its own copy."

# The one target that reaches AWS. It is the manual seed step from the runbook:
# an ECS service cannot start a task from an empty repository, so the first
# image is pushed by hand before the ephemeral layer is applied.
seed: ## Build for x86_64 and push the seed image to ECR (needs AWS credentials)
	@account=$$(aws sts get-caller-identity --query Account --output text); \
	registry="$$account.dkr.ecr.$(AWS_REGION).amazonaws.com"; \
	echo "Pushing to $$registry/$(PROJECT)/app:main"; \
	aws ecr get-login-password --region $(AWS_REGION) \
	    | docker login --username AWS --password-stdin "$$registry"; \
	docker build --platform linux/amd64 --build-arg GIT_SHA=seed \
	    -t "$$registry/$(PROJECT)/app:main" .; \
	docker push "$$registry/$(PROJECT)/app:main"

clean: ## Remove caches, build output and a local database
	rm -rf .pytest_cache .ruff_cache build dist
	rm -f cookie.duckdb cookie.duckdb.wal
	@find . -path ./$(VENV) -prune -o -name '__pycache__' -print0 \
	    | xargs -0 rm -rf
	@find . -path ./$(VENV) -prune -o -name '*.egg-info' -print0 \
	    | xargs -0 rm -rf

clean-all: clean ## Also remove the virtual environment and the local image
	rm -rf $(VENV)
	-docker rmi $(IMAGE):$(TAG)
