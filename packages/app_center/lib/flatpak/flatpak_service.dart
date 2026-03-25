import 'dart:convert';
import 'dart:io';

import 'package:app_center/flatpak/flatpak_model.dart';
import 'package:ubuntu_logger/ubuntu_logger.dart';

final _log = Logger('FlatpakService');

/// Wraps the system `flatpak` CLI to provide install / remove / search / list
/// capabilities without requiring a dedicated Dart pub.dev package.
///
/// All methods throw a [FlatpakException] when the CLI is not available or
/// exits with a non-zero code.
class FlatpakService {
  /// Whether the `flatpak` binary is available on this system.
  static Future<bool> isAvailable() async {
    try {
      final result = await Process.run('which', ['flatpak']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  /// Searches for [query] in all configured Flatpak remotes.
  /// Returns an empty list when Flatpak is not available or no results found.
  Future<List<FlatpakApp>> search(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final result = await Process.run(
        'flatpak',
        [
          'search',
          '--columns=name,description,application,version,origin',
          query.trim(),
        ],
        runInShell: true,
      );

      if (result.exitCode != 0) {
        _log.debug('flatpak search exited ${result.exitCode}: ${result.stderr}');
        return [];
      }

      final lines = (result.stdout as String)
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();

      // Skip header line if present (starts with "Name")
      final dataLines =
          lines.where((l) => !l.startsWith('Name\t')).toList();

      return dataLines
          .map((line) => line.split('\t'))
          .where((cols) => cols.length >= 3)
          .map(FlatpakApp.fromSearchRow)
          .where((app) => app.id.isNotEmpty)
          .toList();
    } catch (e) {
      _log.error('flatpak search error: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Installed apps
  // ---------------------------------------------------------------------------

  /// Returns all currently installed Flatpak applications.
  Future<List<FlatpakApp>> listInstalled() async {
    try {
      final result = await Process.run(
        'flatpak',
        [
          'list',
          '--app',
          '--columns=name,application,version,origin',
        ],
        runInShell: true,
      );

      if (result.exitCode != 0) return [];

      final lines = (result.stdout as String)
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();

      return lines
          .map((line) => line.split('\t'))
          .where((cols) => cols.length >= 2)
          .map(FlatpakApp.fromInstalledRow)
          .toList();
    } catch (e) {
      _log.error('flatpak list error: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Install / Remove / Update
  // ---------------------------------------------------------------------------

  /// Installs [appId] from the given [remote] (default: `flathub`).
  ///
  /// Yields progress lines as they are emitted by the CLI.
  Stream<String> install(String appId, {String remote = 'flathub'}) {
    return _runStream(
      'flatpak',
      ['install', '--noninteractive', '--assumeyes', remote, appId],
    );
  }

  /// Uninstalls [appId].
  Stream<String> remove(String appId) {
    return _runStream(
      'flatpak',
      ['uninstall', '--noninteractive', '--assumeyes', appId],
    );
  }

  /// Updates all installed Flatpak apps (or a specific [appId] if given).
  Stream<String> update([String? appId]) {
    return _runStream(
      'flatpak',
      [
        'update',
        '--noninteractive',
        '--assumeyes',
        if (appId != null) appId,
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Stream<String> _runStream(String executable, List<String> args) async* {
    _log.debug('Running: $executable ${args.join(' ')}');
    Process process;
    try {
      process = await Process.start(executable, args, runInShell: true);
    } catch (e) {
      throw FlatpakException('Failed to start $executable: $e');
    }

    await for (final line in process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      yield line;
    }

    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      final stderr = await process.stderr
          .transform(const SystemEncoding().decoder)
          .join();
      throw FlatpakException(
          '$executable exited with code $exitCode: $stderr');
    }
  }
}

class FlatpakException implements Exception {
  FlatpakException(this.message);
  final String message;

  @override
  String toString() => 'FlatpakException: $message';
}
