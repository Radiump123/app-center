import 'package:app_center/flatpak/flatpak_model.dart';
import 'package:app_center/flatpak/flatpak_providers.dart';
import 'package:app_center/l10n.dart';
import 'package:app_center/layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yaru/yaru.dart';

/// Full-detail page for a single Flatpak application.
class FlatpakPage extends ConsumerWidget {
  const FlatpakPage({required this.app, super.key});

  final FlatpakApp app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final stateNotifier = ref.watch(flatpakAppProvider(app).notifier);
    final appState = ref.watch(flatpakAppProvider(app));

    return ResponsiveLayoutBuilder(
      builder: (context) {
        final layout = ResponsiveLayout.of(context);
        return SingleChildScrollView(
          child: Center(
            child: SizedBox(
              width: layout.totalWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: kPagePadding),
                  // --- Title row ---
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Placeholder icon
                      const _FlatpakIcon(),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appState.app.name,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              appState.app.id,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context).hintColor,
                                  ),
                            ),
                            if (appState.app.description != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                appState.app.description!,
                                style: Theme.of(context).textTheme.bodyMedium,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: kPagePadding),
                  // --- Action buttons ---
                  _ActionBar(
                    appState: appState,
                    onInstall: stateNotifier.install,
                    onRemove: stateNotifier.remove,
                  ),
                  if (appState.error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      appState.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: kPagePadding),
                  const Divider(),
                  const SizedBox(height: kPagePadding),
                  // --- Metadata ---
                  _InfoTile(
                    label: l10n.flatpakRemoteLabel,
                    value: appState.app.origin,
                  ),
                  _InfoTile(
                    label: l10n.snapPageVersionLabel,
                    value: appState.app.version.isNotEmpty
                        ? appState.app.version
                        : l10n.flatpakVersionUnknown,
                  ),
                  if (appState.app.license != null)
                    _InfoTile(
                      label: l10n.snapPageLicenseLabel,
                      value: appState.app.license!,
                    ),
                  if (appState.app.homepage != null) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      icon: const Icon(YaruIcons.external_link, size: 14),
                      label: Text(l10n.snapPageDeveloperWebsiteLabel),
                      onPressed: () {/* url_launcher integration */},
                    ),
                  ],
                  const SizedBox(height: kPagePadding),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FlatpakIcon extends StatelessWidget {
  const _FlatpakIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.secondaryContainer,
      ),
      child: Icon(
        YaruIcons.package_deb,
        size: 36,
        color: Theme.of(context).colorScheme.onSecondaryContainer,
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.appState,
    required this.onInstall,
    required this.onRemove,
  });

  final FlatpakAppState appState;
  final VoidCallback onInstall;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (appState.isBusy) {
      return Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: YaruCircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(width: 12),
          Text(
            appState.isInstalling
                ? l10n.snapActionInstallingLabel
                : l10n.snapActionRemovingLabel,
          ),
        ],
      );
    }

    if (appState.app.isInstalled) {
      return OutlinedButton(
        onPressed: onRemove,
        child: Text(l10n.snapActionRemoveLabel),
      );
    }

    return ElevatedButton(
      onPressed: onInstall,
      child: Text(l10n.snapActionInstallLabel),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
