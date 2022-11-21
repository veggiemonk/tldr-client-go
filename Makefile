# CHECK EXAMPLES: https://makefiletutorial.com/

GO   = $(shell which go)
BIN  = $(CURDIR)/bin

export GO111MODULE=on
export GCO_ENABLED=0

V = 0
Q = $(if $(filter 1,$V),,@)

## TOOLS
GOLANGCI_LINT = $(or $(shell which golangci-lint), $(error "Missing dependency - no golangci-lint in PATH. Run `make install-deps`"))
GODA          =$(or $(shell which goda), $(error "Missing dependency - no goda in PATH >> Run `make install-deps` "))
GOTEST        =$(or $(shell which gotest), $(error "Missing dependency - no gotest in PATH >> Run `make install-deps`"))
GOFUMPT       =$(or $(shell which gofumpt), $(error "Missing dependency - no gofumpt in PATH >> Run `make install-deps`"))

## PROJECT VARIABLES
GITSHA        =$(shell git rev-parse --short HEAD)
DATE		  =$(shell date -u '+%y%m%d%I%M')
VERSION       =$(shell echo $(DATE)-$(GITSHA))

## BUILD FLAGS
GOBUILD = -a -v -trimpath='true' -buildmode='exe' -buildvcs='true' -compiler='gc' -mod='vendor'
LDFLAGS = -X github.com/isacikgoz/tldr/pkg/cmd/version.cliVersion=$(VERSION)

# ==============================================================================
# MAIN TARGETS

.PHONY: bin
bin: ## Build the production binary file
	@echo "Building PROD binaries..."
	rm -rf "$(BIN)"
	mkdir -p "$(BIN)"
	@echo "VERSION: $(VERSION)"
	$(GO) generate ./...
	$(GO) build $(GOBUILD) -ldflags "$(LDFLAGS)" -o "$(BIN)/tldr" cmd/tldr/main.go

.PHONY: dev
dev: ## Build the binary file for development
	@echo "Building DEV binaries..."
	rm -rf "$(BIN)"
	mkdir -p "$(BIN)"
	@echo "VERSION: $(VERSION)"
	$(GO) generate ./...
	$(GO) build -mod='vendor' -o "$(BIN)/tldr" cmd/tldr/main.go

.PHONY: format
format: ## Format the code
	@echo "Formatting code..."
	$(GOFUMPT) -l -w .

.PHONY: lint
lint: format ## Lint the files
	@echo "Linting code..."
	$(GOLANGCI_LINT) --config=./.golangci.yml run --fix ./... -v

####TODO: https://github.com/hadolint/hadolint for dockerfiles

#gen-docs: go-install ## Generate CLI docs automatically
#	$(GO) run main.go generate docs docs/reference/commands.md

# ==============================================================================
# Install tools

install-deps: ## Install all dependencies
	@echo "installing dot for diagram"
	brew install graphviz
	@echo "installing golangci-lint for linting https://github/com/golangci/golangci-lint"
	brew install golangci-lint
	@echo "installing goda for code diagram https://github.com/loov/goda"
	$(GO) install github.com/loov/goda@latest
	@echo "installing gotest for testing https://github.com/rakyll/gotest"
	$(GO) install github.com/rakyll/gotest@latest
	@echo "installing gofumpt for formatting"
	$(GO) install mvdan.cc/gofumpt@latest

# ==============================================================================
# Running tests locally

.PHONY: test
test: ## Run all tests
	$(GOTEST) -v ./... -count=1

# ==============================================================================
# Modules support

.PHONY: deps-reset
deps-reset: ## Reset all dependencies
	git checkout -- go.mod
	$(GO) mod tidy
	$(GO) mod vendor

.PHONY: tidy
tidy: ## Update go.mod and go.sum
	$(GO) mod tidy
	$(GO) mod vendor

.PHONY: deps-upgrade
deps-upgrade: ## Upgrade all dependencies
	# go get $(go list -f '{{if not (or .Main .Indirect)}}{{.Path}}{{end}}' -m all)
	$(GO) get -u -v ./...
	$(GO) mod tidy
	$(GO) mod vendor

.PHONY: deps-cleancache
deps-cleancache: ## Clean the module download cache
	$(GO) clean -modcache

# To remove deps, example: go get github.com/pkg/errors@none


# ==============================================================================
# DOCS

# goda graph see https://github.com/loov/goda

.PHONY: graph
graph: ## Generate graph of dependencies
	@echo "Generating graph..."
	$(GODA) graph "github.com/isacikgoz/tldr/..." | dot -Tsvg -o docs/graph.svg

.PHONY: docs
docs:  ## update docs
	@echo "Generating docs..."
	mkdir -p bin
	$(GO) build -o bin/docs cmd/docs/*.go
	@mkdir -p ./docs/cmd ./docs/man/man1
	@./bin/docs --target=./docs/cmd
	@./bin/docs --target=./docs/man/man1 --kind=man
	@rm -f ./bin/docs

# ==============================================================================
# some other stuff

fluff:
	@echo "Deleting fluff files..."
	find . -name .DS_Store -type f -delete

.PHONY: list
list:
	@LC_ALL=C $(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/(^|\n)# Files(\n|$$)/,/(^|\n)# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'


.PHONY: help
help: ## Show help
	@echo Please specify a build target. The choices are:
	@grep -E '^[0-9a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "    \033[36m%-30s\033[0m %s\n", $$1, $$2}'
