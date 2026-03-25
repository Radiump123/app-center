import 'package:app_center/appstream/appstream.dart';
import 'package:app_center/constants.dart';
import 'package:app_center/flatpak/flatpak_model.dart';
import 'package:app_center/l10n.dart';
import 'package:app_center/search/search_provider.dart';
import 'package:app_center/snapd/snapd.dart';
import 'package:app_center/widgets/widgets.dart';
import 'package:appstream/appstream.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snapd/snapd.dart';
import 'package:yaru/yaru.dart';

// ---------------------------------------------------------------------------
// Auto-complete option types
// ---------------------------------------------------------------------------

sealed class AutoCompleteOption {
  String get title => switch (this) {
        AutoCompleteSnapOption(snap: final snap) => snap.titleOrName,
        AutoCompleteDebOption(deb: final deb) => deb.getLocalizedName(),
        AutoCompleteFlatpakOption(flatpak: final f) => f.name,
        AutoCompleteSearchOption(query: final q) => q,
      };
}

class AutoCompleteSnapOption extends AutoCompleteOption {
  AutoCompleteSnapOption(this.snap);
  final Snap snap;
}

class AutoCompleteDebOption extends AutoCompleteOption {
  AutoCompleteDebOption(this.deb);
  final AppstreamComponent deb;
}

class AutoCompleteFlatpakOption extends AutoCompleteOption {
  AutoCompleteFlatpakOption(this.flatpak);
  final FlatpakApp flatpak;
}

class AutoCompleteSearchOption extends AutoCompleteOption {
  AutoCompleteSearchOption(this.query);
  final String query;
}

// ---------------------------------------------------------------------------
// SearchField widget
// ---------------------------------------------------------------------------

class SearchField extends ConsumerStatefulWidget {
  const SearchField({
    required this.onSearch,
    required this.onSnapSelected,
    required this.onDebSelected,
    required this.onFlatpakSelected,
    required this.searchFocus,
    super.key,
  });

  final ValueChanged<String> onSearch;
  final ValueChanged<String> onSnapSelected;
  final ValueChanged<String> onDebSelected;
  final ValueChanged<FlatpakApp> onFlatpakSelected;
  final FocusNode searchFocus;

  @override
  ConsumerState<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<SearchField> {
  bool _optionsAvailable = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return RawAutocomplete<AutoCompleteOption>(
      optionsBuilder: (query) async {
        ref.read(queryProvider.notifier).state = query.text;
        final options = await ref.watch(autoCompleteProvider.future);
        if (options.snaps.isEmpty &&
            options.debs.isEmpty &&
            options.flatpaks.isEmpty) {
          return [];
        }
        _optionsAvailable = true;
        final snapOptions = options.snaps
            .take(3)
            .map<AutoCompleteOption>(AutoCompleteSnapOption.new)
            .toList();
        final debOptions = options.debs
            .take(3)
            .map<AutoCompleteOption>(AutoCompleteDebOption.new)
            .toList();
        final flatpakOptions = options.flatpaks
            .take(3)
            .map<AutoCompleteOption>(AutoCompleteFlatpakOption.new)
            .toList();
        return <AutoCompleteOption>[
          AutoCompleteSearchOption(query.text),
          ...debOptions,
          ...snapOptions,
          ...flatpakOptions,
        ];
      },
      displayStringForOption: (option) => option.title,
      optionsViewBuilder: (context, onSelected, options) {
        final snapOptions = options.whereType<AutoCompleteSnapOption>();
        final debOptions = options.whereType<AutoCompleteDebOption>();
        final flatpakOptions = options.whereType<AutoCompleteFlatpakOption>();
        final searchOption =
            options.whereType<AutoCompleteSearchOption>().single;
        final highlightedOption =
            options.elementAt(AutocompleteHighlightedOption.of(context));

        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            child: SizedBox(
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: [
                  // --- Deb section (shown first as default) ---
                  if (debOptions.isNotEmpty) ...[
                    ListTile(
                      title: Text(
                        l10n.searchFieldDebSection,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    ...debOptions.map(
                      (e) => _AutoCompleteTile(
                        option: e,
                        onTap: () => onSelected(e),
                        selected: e == highlightedOption,
                      ),
                    ),
                    const Divider(),
                  ],
                  // --- Snap section ---
                  if (snapOptions.isNotEmpty) ...[
                    ListTile(
                      title: Text(
                        l10n.searchFieldSnapSection,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    ...snapOptions.map(
                      (e) => _AutoCompleteTile(
                        option: e,
                        onTap: () => onSelected(e),
                        selected: e == highlightedOption,
                      ),
                    ),
                    const Divider(),
                  ],
                  // --- Flatpak section ---
                  if (flatpakOptions.isNotEmpty) ...[
                    ListTile(
                      title: Text(
                        l10n.searchFieldFlatpakSection,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    ...flatpakOptions.map(
                      (e) => _AutoCompleteTile(
                        option: e,
                        onTap: () => onSelected(e),
                        selected: e == highlightedOption,
                      ),
                    ),
                    const Divider(),
                  ],
                  _AutoCompleteTile(
                    option: searchOption,
                    onTap: () => onSelected(searchOption),
                    selected: searchOption == highlightedOption,
                  ),
                ],
              ),
            ),
          ),
        );
      },
      onSelected: (option) => switch (option) {
        AutoCompleteSnapOption(snap: final snap) =>
          widget.onSnapSelected(snap.name),
        AutoCompleteDebOption(deb: final deb) => widget.onDebSelected(deb.id),
        AutoCompleteFlatpakOption(flatpak: final f) =>
          widget.onFlatpakSelected(f),
        AutoCompleteSearchOption(query: final q) => widget.onSearch(q),
      },
      fieldViewBuilder: (context, controller, node, onFieldSubmitted) {
        return Focus(
          focusNode: widget.searchFocus,
          child: Consumer(
            builder: (context, ref, child) {
              ref.listen(queryProvider, (prev, next) {
                if (!node.hasPrimaryFocus) controller.text = next ?? '';
              });

              return TextField(
                style: Theme.of(context).textTheme.bodyMedium,
                textAlignVertical: TextAlignVertical.center,
                cursorWidth: 1,
                focusNode: node,
                controller: controller,
                onChanged: (_) => _optionsAvailable = false,
                onSubmitted: (query) => _optionsAvailable
                    ? onFieldSubmitted()
                    : widget.onSearch(query),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: kSearchFieldContentPadding,
                  prefixIcon: kSearchFieldPrefixIcon,
                  prefixIconConstraints: kSearchFieldIconConstraints,
                  hintText: l10n.searchFieldSearchHint,
                  suffixIcon: AnimatedBuilder(
                    animation: controller,
                    builder: (context, child) {
                      return YaruIconButton(
                        icon: Icon(
                          YaruIcons.edit_clear,
                          size: 16,
                          color:
                              Theme.of(context).inputDecorationTheme.iconColor,
                        ),
                        onPressed: controller.text.isEmpty
                            ? null
                            : () {
                                controller.clear();
                                node.requestFocus();
                              },
                      );
                    },
                  ),
                  suffixIconConstraints: kSearchFieldIconConstraints,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _AutoCompleteTile extends StatelessWidget {
  const _AutoCompleteTile({
    required this.option,
    required this.onTap,
    required this.selected,
  });

  static const _iconSize = 32.0;

  final AutoCompleteOption option;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (option) {
      AutoCompleteSnapOption(snap: final snap) => ListTile(
          selected: selected,
          title: Text(snap.titleOrName),
          leading: AppIcon(
            size: _iconSize,
            iconUrl: snap.iconUrl,
          ),
          onTap: onTap,
        ),
      AutoCompleteDebOption(deb: final deb) => ListTile(
          selected: selected,
          title: Text(deb.getLocalizedName()),
          leading: AppIcon(
            size: _iconSize,
            iconUrl:
                deb.icons.whereType<AppstreamRemoteIcon>().firstOrNull?.url,
          ),
          onTap: onTap,
        ),
      AutoCompleteFlatpakOption(flatpak: final f) => ListTile(
          selected: selected,
          title: Text(f.name),
          subtitle: f.description != null
              ? Text(
                  f.description!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          leading: const AppIcon(size: _iconSize, iconUrl: null),
          onTap: onTap,
        ),
      AutoCompleteSearchOption(query: final query) => ListTile(
          selected: selected,
          title: Text(l10n.searchFieldSearchForLabel(query)),
          onTap: onTap,
        ),
    };
  }
}
