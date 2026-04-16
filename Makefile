# Mini Credit Development Makefile
# Run from: development/
# Usage: make <target> [SERVICES=service1,service2]

.DEFAULT_GOAL := help

# Color codes
RED    := \033[0;31m
GREEN  := \033[0;32m
YELLOW := \033[1;33m
CYAN   := \033[0;36m
NC     := \033[0m

BACKEND_DIR := ../app

# Shared docker compose prefix (env layering)
COMPOSE_ENV := --env-file vendor.env \
	--env-file deployment/deployment.env \
	--env-file deployment/sensitive.env \
	--env-file derived.env

# Production-like stack (images from Dockerfiles)
COMPOSE_STACK := docker compose --project-name mini-credit $(COMPOSE_ENV) -f docker-compose.yml

# Dev stack (bind mounts + docker-compose.dev.yml overrides)
COMPOSE_DEV := docker compose --project-name mini-credit $(COMPOSE_ENV) -f docker-compose.yml -f docker-compose.dev.yml

# Required files for deployment
REQUIRED_FILES := \
	vendor.env \
	derived.env \
	deployment/deployment.env \
	deployment/sensitive.env \
	deployment/ssl/cert.pem \
	deployment/ssl/key.pem

.PHONY: help up dev-up dev-infra-up down logs status destroy \
	db-push db-gen db-studio \
	test-up test-down test-unit test-integration test-e2e \
	validate ssl-gen hosts-add restart

##@ General

help: ## Show available commands
	@echo "$(CYAN)Mini Credit Development Commands$(NC)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make $(CYAN)<target>$(NC) [SERVICES=service1,service2]\n\n"} \
		/^[a-zA-Z_-]+:.*?##/ { printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2 } \
		/^##@/ { printf "\n$(YELLOW)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(YELLOW)Domains (add to /etc/hosts → 127.0.0.1):$(NC)"
	@echo "  mini-credit.local           → redirects to app"
	@echo "  app.mini-credit.local       Frontend"
	@echo "  api.mini-credit.local       API"
	@echo "  templates.mini-credit.local React Email"

##@ Validation

validate: ## Pre-flight checks before deployment
	@echo "$(CYAN)Validating environment...$(NC)"
	@FAIL=0; \
	for f in $(REQUIRED_FILES); do \
		if [ ! -f "$$f" ]; then \
			echo "  $(RED)✗ Missing: $$f$(NC)"; \
			FAIL=1; \
		else \
			echo "  $(GREEN)✓ Found: $$f$(NC)"; \
		fi; \
	done; \
	if ! docker info > /dev/null 2>&1; then \
		echo "  $(RED)✗ Docker daemon not running$(NC)"; \
		FAIL=1; \
	else \
		echo "  $(GREEN)✓ Docker running$(NC)"; \
	fi; \
	if [ "$$FAIL" = "1" ]; then \
		echo ""; \
		echo "$(RED)Validation failed. Run:$(NC)"; \
		echo "  cp -r deployment.example/ deployment/"; \
		echo "  # edit deployment/deployment.env and deployment/sensitive.env"; \
		echo "  make ssl-gen   # generate SSL certificates"; \
		exit 1; \
	fi; \
	echo "$(GREEN)✓ All checks passed$(NC)"

##@ Setup

ssl-gen: ## Generate local SSL certificates (requires mkcert)
	@echo "$(CYAN)Generating SSL certificates...$(NC)"
	@./provisioning/ssl/generate.sh
	@echo "$(GREEN)✓ SSL certificates ready$(NC)"

MINI_CREDIT_HOSTS_LINE := 127.0.0.1 mini-credit.local app.mini-credit.local api.mini-credit.local templates.mini-credit.local

hosts-add: ## Add local domains to /etc/hosts (requires sudo)
	@echo "$(CYAN)Adding domains to /etc/hosts...$(NC)"
	@if grep -Fx "$(MINI_CREDIT_HOSTS_LINE)" /etc/hosts 2>/dev/null; then \
		echo "$(YELLOW)✓ Full Mini Credit hosts line already present$(NC)"; \
	else \
		sudo sh -c 'echo "$(MINI_CREDIT_HOSTS_LINE)" >> /etc/hosts' && \
		echo "$(GREEN)✓ Mini Credit hosts line appended$(NC)"; \
	fi

##@ Application

up: validate ## Build images and start full stack (postgres, redis, mailpit, api, worker, frontend, templates)
	@echo "$(CYAN)Starting Mini Credit stack...$(NC)"
	@$(COMPOSE_STACK) up -d --build --wait --remove-orphans
	@echo ""
	@echo "$(GREEN)✓ Mini Credit running:$(NC)"
	@echo "  http://localhost:4000  frontend"
	@echo "  http://localhost:3000  api"
	@echo "  http://localhost:3100  templates"
	@echo "  http://localhost:8025  mailpit"

dev-up: validate ## Dev mode: bind-mount app, frontend, templates; hot reload
	@echo "$(CYAN)Starting Mini Credit in dev mode...$(NC)"
	@$(COMPOSE_DEV) up -d --remove-orphans
	@echo ""
	@echo "$(GREEN)✓ Mini Credit dev mode:$(NC)"
	@echo "  http://localhost:4000  frontend"
	@echo "  http://localhost:3000  api"
	@echo "  http://localhost:3100  templates"
	@echo "  http://localhost:8025  mailpit"
	@echo ""
	@echo "$(YELLOW)Source trees are mounted — changes reload in containers$(NC)"

dev-infra-up: validate ## Postgres, Redis, Mailpit, Templates (no api/worker/frontend)
	@echo "$(CYAN)Starting infra + templates...$(NC)"
	@$(COMPOSE_STACK) up -d --remove-orphans \
		mini-credit-postgres \
		mini-credit-redis \
		mini-credit-mailpit \
		mini-credit-postgres-init \
		mini-credit-templates
	@$(COMPOSE_STACK) up -d --wait \
		mini-credit-postgres \
		mini-credit-redis \
		mini-credit-mailpit \
		mini-credit-templates
	@echo "$(GREEN)✓ Infra ready (postgres:5432, redis:6379, mailpit:1025/8025)$(NC)"
	@echo "$(GREEN)  http://localhost:3100  templates$(NC)"

down: ## Stop all services
	@echo "$(CYAN)Stopping services...$(NC)"
	@$(COMPOSE_DEV) down --remove-orphans 2>/dev/null || $(COMPOSE_STACK) down --remove-orphans
	@echo "$(GREEN)✓ Stopped$(NC)"

restart: ## Restart services (no validation)
	@echo "$(CYAN)Restarting services...$(NC)"
	@$(COMPOSE_DEV) restart $(if $(SERVICES),$(shell echo $(SERVICES) | tr ',' ' '),) 2>/dev/null \
		|| $(COMPOSE_STACK) restart $(if $(SERVICES),$(shell echo $(SERVICES) | tr ',' ' '),)
	@echo "$(GREEN)✓ Restarted$(NC)"

destroy: ## Stop all services and remove volumes
	@echo "$(YELLOW)Destroying services and data...$(NC)"
	@$(COMPOSE_DEV) down -v --remove-orphans 2>/dev/null || $(COMPOSE_STACK) down -v --remove-orphans
	@echo "$(GREEN)✓ Destroyed$(NC)"


##@ Observability

logs: ## Follow logs (SERVICES=mini-credit-api,mini-credit-worker)
	@if [ -n "$(SERVICES)" ]; then \
		$(COMPOSE_DEV) logs --follow --tail=100 $$(echo $(SERVICES) | tr ',' ' ') 2>/dev/null \
			|| $(COMPOSE_STACK) logs --follow --tail=100 $$(echo $(SERVICES) | tr ',' ' '); \
	else \
		$(COMPOSE_DEV) logs --follow --tail=100 2>/dev/null || $(COMPOSE_STACK) logs --follow --tail=100; \
	fi

status: ## Show service status
	@$(COMPOSE_DEV) ps 2>/dev/null || $(COMPOSE_STACK) ps


##@ Database

db-push: ## Push Drizzle schema to DB
	@cd $(BACKEND_DIR) && npm run db:push

db-gen: ## Generate Drizzle migration
	@cd $(BACKEND_DIR) && npm run db:gen

db-studio: ## Open Drizzle Studio
	@cd $(BACKEND_DIR) && npm run db:studio


##@ Testing

COMPOSE_TEST := docker compose --project-name mini-credit-test -f docker-compose.test.yml

test-up: ## Start test infra (postgres:5433, redis:6380)
	@echo "$(CYAN)Starting test infra...$(NC)"
	@$(COMPOSE_TEST) up -d --wait
	@echo "$(GREEN)✓ Test infra ready (postgres:5433, redis:6380)$(NC)"

test-down: ## Stop test infra
	@echo "$(CYAN)Stopping test infra...$(NC)"
	@$(COMPOSE_TEST) down
	@echo "$(GREEN)✓ Test infra stopped$(NC)"

test-unit: ## Run unit tests
	@cd $(BACKEND_DIR) && npm run test:unit

test-integration: ## Run integration tests (needs test infra)
	@cd $(BACKEND_DIR) && npm run test:integration

test-e2e: ## Run e2e tests (needs test infra)
	@cd $(BACKEND_DIR) && npm run test:e2e
