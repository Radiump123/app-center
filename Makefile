# ============================================================
# App Center — Makefile
# ============================================================
# Targets:
#   make setup      — install Flutter / FVM dependencies
#   make get        — pub get for all packages (bootstrap)
#   make build      — build the Linux app
#   make run        — run the app in debug mode
#   make test       — run all unit tests
#   make lint       — run dart analyze across all packages
#   make format     — dart format all sources
#   make clean      — delete build artefacts
#   make l10n       — regenerate localisation files
#   make codegen    — run build_runner code generation
#   make all        — setup + get + codegen + l10n + build
# ============================================================

FLUTTER     := fvm flutter
DART        := fvm dart
MELOS       := fvm dart run melos

.PHONY: all setup get build run test lint format clean l10n codegen

all: setup get codegen l10n build

## Install FVM and fetch dependencies
setup:
	@echo "→ Installing/Checking FVM…"
	@fvm --version >/dev/null 2>&1 || (echo "FVM not found, installing..." && bash scripts/install-fvm.sh)
	@echo "→ Activating Flutter via FVM…"
	fvm use

## pub get via melos (covers all workspace packages)
get:
	$(FLUTTER) pub get
	$(MELOS) bootstrap

## Build the Linux desktop app
build:
	$(MELOS) run build

## Run in debug mode
run:
	cd packages/app_center && $(FLUTTER) run -d linux

## Run all unit tests
test:
	$(MELOS) run test

## Static analysis
lint:
	$(MELOS) run analyze

## Format source code
format:
	$(MELOS) run format

## Remove build outputs
clean:
	$(MELOS) clean
	find . -name "*.g.dart" -not -path "*/ratings_client/*" -delete
	find . -name "*.freezed.dart" -delete

## Regenerate localisation ARB → Dart
l10n:
	$(MELOS) run gen-l10n

## Run code-generation (Riverpod, Freezed, JSON serialisable)
codegen:
	$(MELOS) run generate
