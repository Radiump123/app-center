import 'package:app_center/flatpak/flatpak_model.dart';
import 'package:app_center/flatpak/flatpak_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubuntu_service/ubuntu_service.dart';

/// Searches Flatpak remotes for [query].
///
/// Returns an empty list when Flatpak is unavailable or the query is blank.
final flatpakSearchProvider =
    FutureProvider.family<List<FlatpakApp>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];
  final service = getService<FlatpakService>();
  return service.search(query);
});
