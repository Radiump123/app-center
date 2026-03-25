import 'package:app_center/flatpak/flatpak_model.dart';
import 'package:app_center/flatpak/flatpak_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubuntu_service/ubuntu_service.dart';

// ---------------------------------------------------------------------------
// Service availability
// ---------------------------------------------------------------------------

/// Whether the `flatpak` CLI is available on this machine.
final flatpakAvailableProvider = FutureProvider<bool>(
  (_) => FlatpakService.isAvailable(),
);

// ---------------------------------------------------------------------------
// Installed apps
// ---------------------------------------------------------------------------

/// All currently installed Flatpak applications.
final installedFlatpaksProvider = FutureProvider<List<FlatpakApp>>(
  (ref) => getService<FlatpakService>().listInstalled(),
);

// ---------------------------------------------------------------------------
// Per-app state
// ---------------------------------------------------------------------------

/// The state of a single Flatpak app (install / remove / idle).
enum FlatpakActionState { idle, installing, removing, error }

class FlatpakAppNotifier extends StateNotifier<FlatpakAppState> {
  FlatpakAppNotifier(this._service, FlatpakApp app)
      : super(FlatpakAppState(app: app));

  final FlatpakService _service;

  Future<void> install() async {
    state = state.copyWith(actionState: FlatpakActionState.installing, error: null);
    try {
      await _service.install(state.app.id, remote: state.app.origin).drain<void>();
      state = state.copyWith(
        actionState: FlatpakActionState.idle,
        app: state.app.copyWith(isInstalled: true),
      );
    } catch (e) {
      state = state.copyWith(
        actionState: FlatpakActionState.error,
        error: e.toString(),
      );
    }
  }

  Future<void> remove() async {
    state = state.copyWith(actionState: FlatpakActionState.removing, error: null);
    try {
      await _service.remove(state.app.id).drain<void>();
      state = state.copyWith(
        actionState: FlatpakActionState.idle,
        app: state.app.copyWith(isInstalled: false),
      );
    } catch (e) {
      state = state.copyWith(
        actionState: FlatpakActionState.error,
        error: e.toString(),
      );
    }
  }
}

class FlatpakAppState {
  const FlatpakAppState({
    required this.app,
    this.actionState = FlatpakActionState.idle,
    this.error,
  });

  final FlatpakApp app;
  final FlatpakActionState actionState;
  final String? error;

  bool get isInstalling => actionState == FlatpakActionState.installing;
  bool get isRemoving => actionState == FlatpakActionState.removing;
  bool get isBusy =>
      actionState == FlatpakActionState.installing ||
      actionState == FlatpakActionState.removing;

  FlatpakAppState copyWith({
    FlatpakApp? app,
    FlatpakActionState? actionState,
    String? error,
  }) {
    return FlatpakAppState(
      app: app ?? this.app,
      actionState: actionState ?? this.actionState,
      error: error,
    );
  }
}

final flatpakAppProvider = StateNotifierProvider.family
    .autoDispose<FlatpakAppNotifier, FlatpakAppState, FlatpakApp>(
  (ref, app) => FlatpakAppNotifier(getService<FlatpakService>(), app),
);
