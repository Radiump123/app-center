import 'package:app_center/appstream/appstream.dart';
import 'package:app_center/error/error.dart';
import 'package:app_center/flatpak/flatpak.dart';
import 'package:app_center/l10n.dart';
import 'package:app_center/layout.dart';
import 'package:app_center/search/search.dart';
import 'package:app_center/snapd/multisnap_model.dart';
import 'package:app_center/snapd/snapd.dart';
import 'package:app_center/store/store.dart';
import 'package:app_center/widgets/widgets.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubuntu_widgets/ubuntu_widgets.dart';
import 'package:yaru/yaru.dart';

/// The main search results page.
///
/// Shows a filter bar (format + sort order) and then the appropriate result
/// list for the currently selected [PackageFormat].
class SearchPage extends StatelessWidget {
  const SearchPage({super.key, this.query, String? category})
      : initialCategoryName = category;

  final String? query;
  final String? initialCategoryName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final initialCategory = initialCategoryName?.toSnapCategoryEnum();
    return ResponsiveLayoutBuilder(
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: kPagePadding) +
                ResponsiveLayout.of(context).padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Page heading ---
                if (query != null)
                  Semantics(
                    focused: true,
                    header: true,
                    child: Text(
                      l10n.searchPageTitle(query!),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                if (initialCategory != null)
                  Semantics(
                    focused: true,
                    header: true,
                    child: Text(
                      initialCategory.localize(l10n),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                const SizedBox(height: 8),
                // --- Filter / sort row ---
                Row(
                  children: [
                    // Sort (only relevant for snap results)
                    Text(l10n.searchPageSortByLabel),
                    const SizedBox(width: 8),
                    Consumer(
                      builder: (context, ref, child) {
                        final sortOrder = ref.watch(snapSortOrderProvider);
                        return MenuButtonBuilder<SnapSortOrder?>(
                          expanded: false,
                          values: const [
                            null,
                            SnapSortOrder.alphabeticalAsc,
                            SnapSortOrder.alphabeticalDesc,
                            SnapSortOrder.downloadSizeAsc,
                            SnapSortOrder.downloadSizeDesc,
                          ],
                          itemBuilder: (context, sortOrder, child) => Text(
                            sortOrder?.localize(l10n) ??
                                l10n.snapSortOrderRelevance,
                          ),
                          onSelected: (value) => ref
                              .read(snapSortOrderProvider.notifier)
                              .state = value,
                          child: Text(
                            sortOrder?.localize(l10n) ??
                                l10n.snapSortOrderRelevance,
                          ),
                        );
                      },
                    ),
                    if (query != null) ...[
                      const SizedBox(width: 24),
                      Text(l10n.searchPageFilterByLabel),
                      const SizedBox(width: 8),
                      // --- Package format selector ---
                      Expanded(
                        child: Consumer(
                          builder: (context, ref, child) {
                            final current =
                                ref.watch(packageFormatProvider);
                            return MenuButtonBuilder<PackageFormat>(
                              values: PackageFormat.values,
                              itemBuilder:
                                  (context, packageFormat, child) =>
                                      Text(packageFormat.localize(l10n)),
                              onSelected: (value) => ref
                                  .read(packageFormatProvider.notifier)
                                  .state = value,
                              child: Text(current.localize(l10n)),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // --- Category selector (snap only) ---
                      Expanded(
                        child: Consumer(
                          builder: (context, ref, child) {
                            final fmt = ref.watch(packageFormatProvider);
                            if (fmt == PackageFormat.snap ||
                                fmt == PackageFormat.all) {
                              return MenuButtonBuilder<SnapCategoryEnum?>(
                                values: <SnapCategoryEnum?>[null] +
                                    SnapCategoryEnum.values
                                        .whereNot((c) => c.hidden)
                                        .toList(),
                                itemBuilder: (context, category, child) =>
                                    Text(
                                  category?.localize(l10n) ??
                                      l10n.snapCategoryAll,
                                ),
                                onSelected: (value) => ref
                                    .read(
                                      snapCategoryProvider(initialCategory)
                                          .notifier,
                                    )
                                    .state = value,
                                child: Text(
                                  ref
                                          .watch(
                                            snapCategoryProvider(
                                              initialCategory,
                                            ),
                                          )
                                          ?.localize(l10n) ??
                                      l10n.snapCategoryAll,
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ],
                  ],
                ),
                if (initialCategory == SnapCategoryEnum.gameDev ||
                    initialCategory == SnapCategoryEnum.gameEmulators ||
                    initialCategory == SnapCategoryEnum.gnomeGames ||
                    initialCategory == SnapCategoryEnum.kdeGames) ...[
                  const SizedBox(height: kPagePadding),
                  InstallAll(initialCategory: initialCategory),
                ],
              ],
            ),
          ),
          // --- Results area ---
          Expanded(
            child: Consumer(
              builder: (context, ref, child) {
                final packageFormat = initialCategoryName != null
                    ? PackageFormat.snap
                    : ref.watch(packageFormatProvider);
                return switch (packageFormat) {
                  PackageFormat.snap => _SnapSearchResults(
                      initialCategory: initialCategory,
                      query: query,
                    ),
                  PackageFormat.deb => _DebSearchResults(query: query),
                  PackageFormat.flatpak =>
                    _FlatpakSearchResults(query: query),
                  PackageFormat.all => _AllSearchResults(
                      initialCategory: initialCategory,
                      query: query,
                    ),
                };
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// InstallAll helper (unchanged)
// ---------------------------------------------------------------------------

class InstallAll extends ConsumerWidget {
  const InstallAll({required this.initialCategory, super.key});

  final SnapCategoryEnum? initialCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final multiSnapModel = ref.watch(multiSnapModelProvider(initialCategory!));
    return Center(
      child: ElevatedButton(
        onPressed: multiSnapModel.installAll,
        child: Text(l10n.installAll),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Snap results
// ---------------------------------------------------------------------------

class _SnapSearchResults extends ConsumerWidget {
  const _SnapSearchResults({this.initialCategory, this.query});

  final SnapCategoryEnum? initialCategory;
  final String? query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final category = ref.watch(snapCategoryProvider(initialCategory));
    final results = ref.watch(
      sortedSnapSearchProvider(
        SnapSearchParameters(query: query, category: category),
      ),
    );
    return results.when(
      data: (data) => data.isNotEmpty
          ? ResponsiveLayoutScrollView(
              slivers: [
                AppCardGrid.fromSnaps(
                  snaps: data,
                  onTap: (snap) => StoreNavigator.pushSearchSnap(
                    context,
                    name: snap.name,
                    query: query,
                  ),
                ),
              ],
            )
          : _EmptyState(
              message: category == null
                  ? l10n.searchPageNoResults(query!)
                  : l10n.searchPageNoResultsCategory,
              hint: category == null
                  ? l10n.searchPageNoResultsHint
                  : l10n.searchPageNoResultsCategoryHint,
            ),
      error: (error, stack) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(
          snapSearchProvider(
            SnapSearchParameters(query: query, category: category),
          ),
        ),
      ),
      loading: () => const Center(child: YaruCircularProgressIndicator()),
    );
  }
}

// ---------------------------------------------------------------------------
// Deb results
// ---------------------------------------------------------------------------

class _DebSearchResults extends ConsumerWidget {
  const _DebSearchResults({this.query});

  final String? query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final results = ref.watch(appstreamSearchProvider(query ?? ''));
    return results.when(
      data: (data) => data.isNotEmpty
          ? ResponsiveLayoutScrollView(
              slivers: [
                AppCardGrid.fromDebs(
                  debs: data,
                  onTap: (deb) => StoreNavigator.pushDeb(
                    context,
                    id: deb.id,
                  ),
                ),
              ],
            )
          : _EmptyState(
              message: l10n.searchPageNoResults(query ?? ''),
              hint: l10n.searchPageNoResultsHint,
            ),
      error: (error, stack) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(appstreamSearchProvider(query ?? '')),
      ),
      loading: () => const Center(child: YaruCircularProgressIndicator()),
    );
  }
}

// ---------------------------------------------------------------------------
// Flatpak results
// ---------------------------------------------------------------------------

class _FlatpakSearchResults extends ConsumerWidget {
  const _FlatpakSearchResults({this.query});

  final String? query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final results = ref.watch(flatpakSearchProvider(query ?? ''));
    return results.when(
      data: (data) => data.isNotEmpty
          ? ResponsiveLayoutScrollView(
              slivers: [
                _FlatpakCardGrid(
                  apps: data,
                  onTap: (app) => _showFlatpakPage(context, app),
                ),
              ],
            )
          : _EmptyState(
              message: l10n.searchPageNoResults(query ?? ''),
              hint: l10n.searchPageNoResultsHint,
            ),
      error: (error, stack) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(flatpakSearchProvider(query ?? '')),
      ),
      loading: () => const Center(child: YaruCircularProgressIndicator()),
    );
  }
}

// ---------------------------------------------------------------------------
// All results (combined)
// ---------------------------------------------------------------------------

class _AllSearchResults extends ConsumerWidget {
  const _AllSearchResults({this.initialCategory, this.query});

  final SnapCategoryEnum? initialCategory;
  final String? query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    final debResults = ref.watch(appstreamSearchProvider(query ?? ''));
    final snapResults = ref.watch(
      sortedSnapSearchProvider(
        SnapSearchParameters(
          query: query,
          category: ref.watch(snapCategoryProvider(initialCategory)),
        ),
      ),
    );
    final flatpakResults = ref.watch(flatpakSearchProvider(query ?? ''));

    final hasAny = [debResults, snapResults, flatpakResults]
        .any((r) => r.valueOrNull?.isNotEmpty ?? false);
    final allLoading = [debResults, snapResults, flatpakResults]
        .every((r) => r.isLoading);

    if (allLoading) {
      return const Center(child: YaruCircularProgressIndicator());
    }

    if (!hasAny &&
        [debResults, snapResults, flatpakResults].every((r) => !r.isLoading)) {
      return _EmptyState(
        message: l10n.searchPageNoResults(query ?? ''),
        hint: l10n.searchPageNoResultsHint,
      );
    }

    return ResponsiveLayoutScrollView(
      slivers: [
        // Debs first (preferred)
        if (debResults.valueOrNull?.isNotEmpty ?? false) ...[
          _SectionHeader(label: l10n.packageFormatDebLabel),
          AppCardGrid.fromDebs(
            debs: debResults.value!,
            onTap: (deb) => StoreNavigator.pushDeb(context, id: deb.id),
          ),
        ],
        // Then snaps
        if (snapResults.valueOrNull?.isNotEmpty ?? false) ...[
          _SectionHeader(label: l10n.packageFormatSnapLabel),
          AppCardGrid.fromSnaps(
            snaps: snapResults.value!,
            onTap: (snap) => StoreNavigator.pushSearchSnap(
              context,
              name: snap.name,
              query: query,
            ),
          ),
        ],
        // Then flatpaks
        if (flatpakResults.valueOrNull?.isNotEmpty ?? false) ...[
          _SectionHeader(label: l10n.packageFormatFlatpakLabel),
          _FlatpakCardGrid(
            apps: flatpakResults.value!,
            onTap: (app) => _showFlatpakPage(context, app),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

void _showFlatpakPage(BuildContext context, FlatpakApp app) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(app.name)),
        body: FlatpakPage(app: app),
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, required this.hint});

  final String message;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: ResponsiveLayout.of(context).padding,
      child: Column(
        children: [
          const Spacer(),
          Text(
            message,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            hint,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

/// A sliver heading used in the "All" view to label each source section.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
        child: Text(
          label,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// A simple grid of Flatpak app cards.
class _FlatpakCardGrid extends StatelessWidget {
  const _FlatpakCardGrid({required this.apps, required this.onTap});

  final List<FlatpakApp> apps;
  final void Function(FlatpakApp) onTap;

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisExtent: 200,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final app = apps[index];
          return _FlatpakCard(app: app, onTap: () => onTap(app));
        },
        childCount: apps.length,
      ),
    );
  }
}

class _FlatpakCard extends StatelessWidget {
  const _FlatpakCard({required this.app, required this.onTap});

  final FlatpakApp app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppIcon(size: 64, iconUrl: null),
              const SizedBox(height: 8),
              Text(
                app.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                app.origin,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).hintColor,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Localisation extension for PackageFormat
// ---------------------------------------------------------------------------

extension PackageFormatL10n on PackageFormat {
  String localize(AppLocalizations l10n) {
    return switch (this) {
      PackageFormat.all => l10n.packageFormatAllLabel,
      PackageFormat.deb => l10n.packageFormatDebLabel,
      PackageFormat.snap => l10n.packageFormatSnapLabel,
      PackageFormat.flatpak => l10n.packageFormatFlatpakLabel,
    };
  }
}
