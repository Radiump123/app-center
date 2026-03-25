import 'dart:convert';

/// Represents a Flatpak application as reported by the `flatpak` CLI.
class FlatpakApp {
  const FlatpakApp({
    required this.id,
    required this.name,
    required this.version,
    required this.origin,
    required this.isInstalled,
    this.description,
    this.iconUrl,
    this.homepage,
    this.license,
    this.downloadSize,
  });

  /// Application ID, e.g. `org.gnome.Calculator`
  final String id;

  /// Human-readable name, e.g. `GNOME Calculator`
  final String name;

  /// Installed or available version string
  final String version;

  /// The Flatpak remote / origin, e.g. `flathub`
  final String origin;

  /// Whether the app is currently installed on the system
  final bool isInstalled;

  final String? description;
  final String? iconUrl;
  final String? homepage;
  final String? license;

  /// Download size in bytes, if known
  final int? downloadSize;

  /// Creates a [FlatpakApp] from a tab-separated `flatpak search` or
  /// `flatpak list` output row.
  ///
  /// `flatpak search` columns (--columns=name,description,application,version,origin):
  ///   0: name  1: description  2: application  3: version  4: origin
  ///
  /// `flatpak list` columns (--columns=name,application,version,origin):
  ///   0: name  1: application  2: version  3: origin
  factory FlatpakApp.fromSearchRow(List<String> cols) {
    // cols from `flatpak search --columns=name,description,application,version,origin`
    final name = cols.elementAtOrElse(0, (_) => 'Unknown');
    final description = cols.elementAtOrElse(1, (_) => '');
    final id = cols.elementAtOrElse(2, (_) => '');
    final version = cols.elementAtOrElse(3, (_) => '');
    final origin = cols.elementAtOrElse(4, (_) => 'flathub');
    return FlatpakApp(
      id: id,
      name: name,
      version: version,
      origin: origin,
      isInstalled: false,
      description: description,
    );
  }

  factory FlatpakApp.fromInstalledRow(List<String> cols) {
    // cols from `flatpak list --columns=name,application,version,origin`
    final name = cols.elementAtOrElse(0, (_) => 'Unknown');
    final id = cols.elementAtOrElse(1, (_) => '');
    final version = cols.elementAtOrElse(2, (_) => '');
    final origin = cols.elementAtOrElse(3, (_) => 'flathub');
    return FlatpakApp(
      id: id,
      name: name,
      version: version,
      origin: origin,
      isInstalled: true,
    );
  }

  /// Produces a copy with the given fields replaced.
  FlatpakApp copyWith({
    String? id,
    String? name,
    String? version,
    String? origin,
    bool? isInstalled,
    String? description,
    String? iconUrl,
    String? homepage,
    String? license,
    int? downloadSize,
  }) {
    return FlatpakApp(
      id: id ?? this.id,
      name: name ?? this.name,
      version: version ?? this.version,
      origin: origin ?? this.origin,
      isInstalled: isInstalled ?? this.isInstalled,
      description: description ?? this.description,
      iconUrl: iconUrl ?? this.iconUrl,
      homepage: homepage ?? this.homepage,
      license: license ?? this.license,
      downloadSize: downloadSize ?? this.downloadSize,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is FlatpakApp && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'FlatpakApp(id: $id, name: $name, installed: $isInstalled)';
}

extension _ListAtOrElse<T> on List<T> {
  T elementAtOrElse(int index, T Function(int) orElse) =>
      index < length ? this[index] : orElse(index);
}
