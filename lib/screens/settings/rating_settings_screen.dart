import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../focus/focusable_button.dart';
import '../../i18n/strings.g.dart';
import '../../services/settings_mutation_service.dart';
import '../../services/settings_service.dart';
import '../../utils/rating_display_policy.dart';
import '../../utils/rating_utils.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/focusable_list_tile.dart';
import '../../widgets/media_rating_badge.dart';
import '../../widgets/setting_tile.dart';
import '../../widgets/settings_builder.dart';
import '../../widgets/settings_page.dart';
import '../../widgets/settings_section.dart';

class RatingSettingsScreen extends StatefulWidget {
  const RatingSettingsScreen({super.key});

  @override
  State<RatingSettingsScreen> createState() => _RatingSettingsScreenState();
}

class _RatingSettingsScreenState extends State<RatingSettingsScreen> {
  bool _saving = false;

  Future<void> _write(Pref<List<String>> pref, List<String> value) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final failure = await const SettingsMutationService().write(context, pref, value, rebuildRoot: false);
      if (failure != null && mounted) showErrorSnackBar(context, failure.display);
    } catch (_) {
      if (mounted) showErrorSnackBar(context, t.settings.ratingSettingsSaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => SettingsBuilder(
    prefs: ratingDisplayPrefs,
    builder: (context) {
      final policy = currentRatingDisplayPolicy();
      final sources = policy.orderedSources;
      final disabled = policy.disabledSources.map(RatingDisplayPolicy.sourceGroup).toSet();
      return SettingsPage(
        title: Text(t.settings.ratings),
        children: [
          SettingsGroup(
            title: t.settings.display,
            children: [
              SettingSwitchTile(
                pref: SettingsService.showRatingBadges,
                icon: Symbols.star_rounded,
                title: t.settings.showRatingBadges,
                subtitle: t.settings.showRatingBadgesDescription,
              ),
            ],
          ),
          SettingsGroup(
            title: t.settings.ratingSources,
            children: [
              Padding(padding: const EdgeInsets.all(16), child: Text(t.settings.ratingSourcesDescription)),
              for (final (index, source) in sources.indexed)
                Column(
                  key: ValueKey('rating-source-$source'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FocusableSwitchListTile(
                      title: Text(ratingSourceLabel(source) ?? t.settings.otherRatingSources),
                      value: !disabled.contains(source),
                      onChanged: _saving
                          ? null
                          : (enabled) {
                              final next = {...disabled};
                              enabled ? next.remove(source) : next.add(source);
                              _write(SettingsService.disabledRatingSources, next.toList());
                            },
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 16, end: 16, bottom: 8),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          for (final direction in [-1, 1])
                            _moveButton(
                              source: source,
                              direction: direction,
                              enabled: !_saving && index + direction >= 0 && index + direction < sources.length,
                              onPressed: () {
                                final next = List<String>.of(sources);
                                next.removeAt(index);
                                next.insert(index + direction, source);
                                _write(SettingsService.ratingSourceOrder, next);
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      );
    },
  );

  Widget _moveButton({
    required String source,
    required int direction,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    final label = direction < 0 ? t.settings.moveRatingUp : t.settings.moveRatingDown;
    final activate = enabled ? onPressed : null;
    return Semantics(
      label: '$label: ${ratingSourceLabel(source) ?? t.settings.otherRatingSources}',
      child: FocusableButton(
        key: ValueKey('rating-$source-${direction < 0 ? 'up' : 'down'}'),
        onPressed: activate,
        child: TextButton.icon(
          onPressed: activate,
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          icon: AppIcon(direction < 0 ? Symbols.arrow_upward_rounded : Symbols.arrow_downward_rounded, size: 18),
          label: Text(label),
        ),
      ),
    );
  }
}
