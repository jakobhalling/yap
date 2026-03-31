UNAME := $(shell uname -s)

.PHONY: help release-and-run build-release run-release clean

.DEFAULT_GOAL := help

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

release-and-run: build-release run-release ## Build release and run the app

ifeq ($(UNAME),Darwin)

build-release: ## Build the app in release mode
	flutter build macos --release

run-release: ## Run the release build
	open build/macos/Build/Products/Release/yap.app

clean: ## Clean build artifacts
	flutter clean

else ifeq ($(OS),Windows_NT)

build-release:
	flutter build windows --release

run-release:
	start build\windows\x64\runner\Release\yap.exe

clean:
	flutter clean

else
$(error Unsupported platform: $(UNAME))
endif
