import 'dart:async';

import 'package:app_center/appstream/appstream.dart';
import 'package:app_center/flatpak/flatpak_model.dart';
import 'package:app_center/flatpak/flatpak_search.dart';
import 'package:app_center/snapd/snapd.dart';
import 'package:appstream/appstream.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snapd/snapd.dart';

/// The available package formats that can be searched / displayed.
enum PackageFormat {
  /// Show results from all sources (deb + snap + flatpak) together.
  all,

  /// Debian packages via PackageKit (APT). **Default.**
  deb,

  /// Snap packages via the Snap Store.
  snap,

  /// Flatpak applications via configured remotes (e.g. Flathub).
  flatpak,
}

// ---------------------------------------------------------------------------
// Current search query
// ---------------------------------------------------------------------------

final queryProvider = StateProvider<String?>((_) => null);

// ---------------------------------------------------------------------------
// Package format filter — DEB is the default
// ---------------------------------------------------------------------------

/// Defaults to [PackageFormat.deb] so that native Debian packages are shown
/// first, which is what most Ubuntu users expect.
final packageFormatProvider = StateProvider.autoDispose<PackageFormat>(
  (_) => PackageFormat.deb,
);

// ---------------------------------------------------------------------------
// Auto-complete
// ---------------------------------------------------------------------------

typedef AutoCompleteOptions = ({
  Iterable<Snap> snaps,
  Iterable<AppstreamComponent> debs,
  Iterable<FlatpakApp> flatpaks,
});

final autoCompleteProvider = FutureProvider<AutoCompleteOptions>((ref) async {
  final query = ref.watch(queryProvider);

  // Debounce — wait until the user stops typing.
  final completer = Completer<void>();
  ref.onDispose(completer.complete);

  await Future<void>.delayed(const Duration(milliseconds: 100));

  if ((query?.isNotEmpty ?? true) && !completer.isCompleted) {
    final results = await Future.wait([
      ref.watch(snapSearchProvider(SnapSearchParameters(query: query)).future),
      ref.watch(appstreamSearchProvider(query ?? '').future),
      ref.watch(flatpakSearchProvider(query ?? '').future),
    ]);
    final snaps = results[0] as List<Snap>;
    final debs = results[1] as List<AppstreamComponent>;
    final flatpaks = results[2] as List<FlatpakApp>;
    return (snaps: snaps, debs: debs, flatpaks: flatpaks);
  }
  return (
    snaps: <Snap>[],
    debs: <AppstreamComponent>[],
    flatpaks: <FlatpakApp>[],
  );
});
