# ============================================================
# App Center — Justfile
# Run tasks with: just <recipe>
# Install just:   cargo install just  OR  snap install just
# ============================================================

app_dir  := "packages/app_center"
flutter  := "fvm flutter"
dart     := "fvm dart"
melos    := "fvm dart run melos"

# List all available recipes
default:
    @just --list

# ── Setup ────────────────────────────────────────────────────

# Install FVM and activate the pinned Flutter version
setup:
    bash scripts/install-fvm.sh
    fvm use

# Bootstrap all workspace packages (pub get)
get:
    {{melos}} bootstrap

# Full first-time setup: install deps, generate code, build
all: setup get codegen build

# ── Development ──────────────────────────────────────────────

# Run the app in debug mode on Linux desktop
run:
    cd {{app_dir}} && {{flutter}} run -d linux

# Build a release binary
build:
    cd {{app_dir}} && {{flutter}} build linux --release

# Build + run immediately
dev: build
    cd {{app_dir}} && {{flutter}} run -d linux --release

# ── Code generation ──────────────────────────────────────────

# Run build_runner (Riverpod / Freezed / JSON)
codegen:
    cd {{app_dir}} && {{dart}} run build_runner build --delete-conflicting-outputs

# Watch mode — regenerate on file changes
codegen-watch:
    cd {{app_dir}} && {{dart}} run build_runner watch --delete-conflicting-outputs

# Regenerate Flutter l10n files
l10n:
    cd {{app_dir}} && {{flutter}} gen-l10n

# ── Quality ──────────────────────────────────────────────────

# Run all unit tests
test:
    cd {{app_dir}} && {{flutter}} test

# Run tests with coverage
test-coverage:
    cd {{app_dir}} && {{flutter}} test --coverage
    genhtml coverage/lcov.info -o coverage/html

# Static analysis
lint:
    cd {{app_dir}} && {{dart}} analyze --fatal-infos

# Format source code (fails on dirty files — good for CI)
format:
    cd {{app_dir}} && {{dart}} format --set-exit-if-changed lib test

# Auto-fix formatting
fmt:
    cd {{app_dir}} && {{dart}} format lib test

# ── Cleanup ───────────────────────────────────────────────────

# Remove all build outputs and generated files
clean:
    cd {{app_dir}} && {{flutter}} clean
    find . -name "*.g.dart" -not -path "*/ratings_client/*" -delete
    find . -name "*.freezed.dart" -delete

# Remove only generated Dart files
clean-gen:
    find . -name "*.g.dart" -not -path "*/ratings_client/*" -delete
    find . -name "*.freezed.dart" -delete

# ── Utilities ─────────────────────────────────────────────────

# Check that flatpak is installed on this machine
check-flatpak:
    @flatpak --version 2>/dev/null && echo "✓ Flatpak is available" || echo "✗ Flatpak not found — install via: sudo apt install flatpak"

# Add Flathub remote if missing
setup-flathub:
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    @echo "✓ Flathub remote ready"

# Print build environment info
info:
    @echo "Flutter:" && {{flutter}} --version
    @echo "Dart:"    && {{dart}} --version
    @echo "Flatpak:" && (flatpak --version 2>/dev/null || echo "not installed")
