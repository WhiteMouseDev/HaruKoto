ENV_FILE := .env
DART_DEFINE := --dart-define-from-file=$(ENV_FILE)
DEVICE ?= $(shell flutter devices 2>/dev/null | grep -i simulator | head -1 | sed 's/.*• \([^ ]*\) •.*/\1/')

# ─── Development ──────────────────────────────────
.PHONY: run run-web clean analyze test

run: ## Run on iOS simulator (debug)
	flutter run -d $(DEVICE) $(DART_DEFINE)

run-web: ## Run on Chrome
	flutter run -d chrome $(DART_DEFINE)

# ─── Build ────────────────────────────────────────
.PHONY: build-ios build-apk build-appbundle

build-ios: ## Build iOS (no codesign, for CI)
	flutter build ios --no-codesign $(DART_DEFINE)

build-apk: ## Build Android APK
	flutter build apk $(DART_DEFINE)

build-appbundle: ## Build Android App Bundle
	flutter build appbundle $(DART_DEFINE)

# ─── Quality ──────────────────────────────────────
.PHONY: analyze test format

analyze: ## Run flutter analyze
	flutter analyze

test: ## Run tests
	flutter test

format: ## Format code
	dart format lib test

# ─── Utilities ────────────────────────────────────
.PHONY: clean deps gen

clean: ## Clean build artifacts
	flutter clean

deps: ## Get dependencies
	flutter pub get

gen: ## Run build_runner code generation
	dart run build_runner build --delete-conflicting-outputs

# ─── Help ─────────────────────────────────────────
.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-18s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
