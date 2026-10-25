import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../danmaku/danmaku_api_client.dart';
import '../../../danmaku/danmaku_matcher.dart';
import '../../../danmaku/danmaku_parser.dart';
import '../../../danmaku/danmaku_session.dart';
import '../../../focus/focusable_slider.dart';
import '../../../focus/focusable_text_field.dart';
import '../../../utils/episode_titles.dart';
import '../../../i18n/strings.g.dart';
import '../../../media/media_item.dart';
import '../../../media/media_kind.dart';
import '../../../services/file_picker_service.dart';
import '../../../widgets/settings_page.dart';
import '../../../widgets/settings_section.dart';
import '../../../theme/settings_presentation.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/focusable_list_tile.dart';
import 'base_video_control_sheet.dart';
import 'danmaku_sources_sheet.dart';
import 'player_settings_controls.dart';

class DanmakuSettingsSheet extends StatefulWidget {
  final MediaItem? metadata;
  final DanmakuSession? session;
  final VoidCallback? onBack;
  final bool settingsPage;

  const DanmakuSettingsSheet({super.key, this.metadata, this.session, this.onBack, this.settingsPage = false});

  @override
  State<DanmakuSettingsSheet> createState() => _DanmakuSettingsSheetState();
}

class DanmakuSettingsPage extends StatelessWidget {
  const DanmakuSettingsPage({super.key, this.session});

  final DanmakuSession? session;

  @override
  Widget build(BuildContext context) => SettingsPage.slivers(
    title: Text(t.danmaku.title),
    slivers: [SliverFillRemaining(child: DanmakuSettingsSheet(session: session, settingsPage: true))],
  );
}

enum _DanmakuPanel { main, search, area, style }

class _DanmakuSettingsSheetState extends State<DanmakuSettingsSheet> {
  late final DanmakuSession _session = widget.session ?? DanmakuSession.instance;
  late final TextEditingController _query;
  final TextEditingController _keywords = TextEditingController();
  String _savedKeywords = '';
  DanmakuMatchContext? _observedContext;
  bool _initializing = true;
  bool _initializationFailed = false;
  bool _sourcesOpen = false;
  bool _addOnOpen = false;
  bool _sourcePickerOpen = false;
  bool _searching = false;
  bool _loading = false;
  bool _remember = true;
  _DanmakuPanel _panel = _DanmakuPanel.main;
  final _scroll = ScrollController();
  final _queryFocus = FocusNode(debugLabel: 'danmaku_search');
  int _requestGeneration = 0;
  String? _error;
  DanmakuAnime? _selectedAnime;
  List<DanmakuAnime> _animes = const [];
  List<DanmakuSearchHit> _hits = const [];

  /// Episode typed into the query (`第N集`); null follows the playing one.
  int? _targetEpisode;

  @override
  void initState() {
    super.initState();
    _observedContext = _session.mediaContext;
    _query = TextEditingController(text: _suggestedQuery(widget.metadata));
    _session.addListener(_rebuild);
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      _initializing = true;
      _initializationFailed = false;
    });
    try {
      await _session.initialize();
      if (!mounted) return;
      _savedKeywords = _session.presentation.blockedKeywords.join('\n');
      _keywords.text = _savedKeywords;
      setState(() {
        _initializing = false;
        if (_session.enabled && _session.sources.isEmpty && _session.comments.isEmpty) {
          _sourcesOpen = true;
          _addOnOpen = true;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _initializationFailed = true;
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant DanmakuSettingsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.metadata?.globalKey != widget.metadata?.globalKey) {
      _requestGeneration++;
      _query.text = _suggestedQuery(widget.metadata);
      _animes = const [];
      _hits = const [];
      _selectedAnime = null;
      _targetEpisode = null;
      _searching = false;
      _loading = false;
      _error = null;
    }
  }

  @override
  void dispose() {
    _requestGeneration++;
    _session.removeListener(_rebuild);
    _queryFocus.dispose();
    _scroll.dispose();
    _query.dispose();
    _keywords.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (!mounted) return;
    final keywords = _session.presentation.blockedKeywords.join('\n');
    if (keywords != _savedKeywords) {
      _savedKeywords = keywords;
      _keywords.text = keywords;
    }
    if (!identical(_observedContext, _session.mediaContext)) {
      _observedContext = _session.mediaContext;
      _requestGeneration++;
      _query.text = _session.displayQuery;
      _animes = const [];
      _hits = const [];
      _selectedAnime = null;
      _targetEpisode = null;
      _searching = false;
      _loading = false;
      _error = null;
    }
    setState(() {});
  }

  String _suggestedQuery(MediaItem? item) {
    if (item == null) return '';
    if (item.kind != MediaKind.episode) return item.title ?? '';
    final title = item.grandparentTitle ?? item.title ?? '';
    final season = item.parentIndex;
    final episode = effectiveEpisodeIndex(item);
    return danmakuDisplayQuery(
      season == null ? title : '$title 第$season季',
      episode == null ? null : episode + _session.episodeOffset,
    );
  }

  void _showPanel(_DanmakuPanel panel) {
    _requestGeneration++;
    _queryFocus.unfocus();
    setState(() {
      _panel = panel;
      _loading = false;
      _searching = false;
      _error = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scroll.hasClients) _scroll.jumpTo(0);
      if (panel == _DanmakuPanel.search) _queryFocus.requestFocus();
    });
  }

  Future<void> _setEpisodeOffset(int value) async {
    final context = _session.mediaContext;
    await _session.setEpisodeOffset(value);
    if (!mounted || !identical(context, _session.mediaContext)) return;
    setState(() {
      _targetEpisode = null;
      _query.text = _session.displayQuery.isNotEmpty ? _session.displayQuery : _suggestedQuery(widget.metadata);
    });
  }

  Future<void> _save(Future<void> Function() operation) async {
    try {
      await operation();
      if (mounted) setState(() => _error = null);
    } catch (_) {
      if (mounted) {
        setState(() => _error = t.danmaku.saveFailed);
        _toast(t.danmaku.saveFailed);
      }
    }
  }

  void _openSources({bool add = false}) {
    _requestGeneration++;
    setState(() {
      _sourcesOpen = true;
      _addOnOpen = add;
      _searching = false;
      _loading = false;
      _animes = const [];
      _hits = const [];
      _selectedAnime = null;
    });
  }

  Future<void> _setEnabled(bool enabled) async {
    await _save(() => _session.updateStyle(enabled: enabled));
    if (!mounted || !enabled || !_session.enabled || _session.comments.isNotEmpty) return;
    if (!_session.sources.any((source) => source.enabled)) {
      _openSources(add: _session.sources.isEmpty);
    }
  }

  Future<void> _selectSource(String? sourceId) async {
    _requestGeneration++;
    setState(() {
      _sourcePickerOpen = false;
      _animes = const [];
      _hits = const [];
      _selectedAnime = null;
      _searching = false;
      _loading = false;
    });
    await _save(() => _session.selectSource(sourceId));
  }

  Future<void> _search() async {
    final parsed = parseDanmakuQuery(_query.text);
    final query = parsed.keyword;
    if (query.length < 2) {
      setState(() => _error = t.danmaku.queryTooShort);
      return;
    }
    if (!_session.sources.any((source) => source.enabled)) {
      _openSources(add: _session.sources.isEmpty);
      return;
    }
    final generation = ++_requestGeneration;
    setState(() {
      _searching = true;
      _error = null;
      _animes = const [];
      _hits = const [];
      _selectedAnime = null;
    });
    try {
      final animes = rankDanmakuWorks(await _session.search(query), query);
      if (!mounted || generation != _requestGeneration) return;
      _targetEpisode = parsed.episode;
      setState(() {
        _animes = animes;
        _error = animes.isEmpty ? t.danmaku.noCandidates : null;
      });
      // A confident match goes straight to its episode list.
      final confident = confidentDanmakuWork(animes, query);
      if (confident != null) {
        _searching = false;
        await _selectAnime(confident);
        return;
      }
    } catch (_) {
      if (mounted && generation == _requestGeneration) setState(() => _error = t.danmaku.searchFailed);
    } finally {
      if (mounted && generation == _requestGeneration) setState(() => _searching = false);
    }
  }

  Future<void> _selectAnime(DanmakuAnime anime) async {
    final generation = ++_requestGeneration;
    setState(() {
      _selectedAnime = anime;
      _loading = true;
      _error = null;
      _hits = const [];
    });
    try {
      final hits = await _session.episodes(anime);
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _hits = hits;
        _error = hits.isEmpty ? t.danmaku.noEpisodes : null;
      });
    } catch (_) {
      if (mounted && generation == _requestGeneration) setState(() => _error = t.danmaku.searchFailed);
    } finally {
      if (mounted && generation == _requestGeneration) setState(() => _loading = false);
    }
  }

  Future<void> _loadHit(DanmakuSearchHit hit) async {
    final generation = ++_requestGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!_session.enabled) await _session.updateStyle(enabled: true);
      if (!mounted || generation != _requestGeneration) return;
      await _session.loadEpisode(hit, remember: _remember);
      if (!mounted || generation != _requestGeneration) return;
      _toast(t.danmaku.loaded(count: _session.comments.length, source: hit.label));
      if (mounted && BaseVideoControlSheet.embeddedIn(context)) _showPanel(_DanmakuPanel.main);
    } catch (_) {
      if (mounted && generation == _requestGeneration) setState(() => _error = t.danmaku.loadFailed);
    } finally {
      if (mounted && generation == _requestGeneration) setState(() => _loading = false);
    }
  }

  Future<void> _pickLocal() async {
    final contextAtStart = _session.mediaContext;
    final itemAtStart = widget.metadata?.globalKey;
    bool stillCurrent() =>
        mounted && identical(contextAtStart, _session.mediaContext) && itemAtStart == widget.metadata?.globalKey;
    try {
      final result = await FilePickerService.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xml', 'json'],
        withData: true,
      );
      if (!stillCurrent()) return;
      final file = (result == null || result.files.isEmpty) ? null : result.files.first;
      final bytes = file?.bytes;
      if (file == null || bytes == null) return;
      final comments = DanmakuParser.parse(utf8.decode(bytes, allowMalformed: true));
      if (!_session.enabled) {
        try {
          await _session.updateStyle(enabled: true);
        } catch (_) {
          if (stillCurrent()) setState(() => _error = t.danmaku.saveFailed);
          return;
        }
      }
      if (!stillCurrent()) return;
      _requestGeneration++;
      _session.load(comments, sourceLabel: file.name);
      setState(() {
        _error = null;
        _searching = false;
        _loading = false;
      });
      _toast(t.danmaku.loaded(count: comments.length, source: file.name));
      if (mounted && BaseVideoControlSheet.embeddedIn(context)) _showPanel(_DanmakuPanel.main);
    } catch (_) {
      if (stillCurrent()) setState(() => _error = t.danmaku.localImportFailed);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _sourceName(String? sourceId) {
    for (final source in _session.sources) {
      if (source.id == sourceId) return source.name;
    }
    return t.danmaku.sourceAutomatic;
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing || _initializationFailed) {
      return BaseVideoControlSheet(
        title: t.danmaku.title,
        onBack: widget.onBack,
        icon: Symbols.subtitles_rounded,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _initializing
              ? const Center(heightFactor: 1, child: CircularProgressIndicator())
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DanmakuErrorText(t.danmaku.loadingFailed),
                    DanmakuActionButton(label: t.common.retry, onPressed: _initialize),
                    _localImportTile(),
                  ],
                ),
        ),
      );
    }
    if (_sourcesOpen) {
      final sources = DanmakuSourcesSheet(
        session: _session,
        addOnOpen: _addOnOpen,
        onBack: () => setState(() => _sourcesOpen = false),
      );
      if (!widget.settingsPage) return sources;
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(() => _sourcesOpen = false);
        },
        child: sources,
      );
    }
    final embedded = BaseVideoControlSheet.embeddedIn(context);
    final loaded = _session.sourceLabel;
    final targetEpisode = _session.mediaContext?.episodeNumber ?? widget.metadata?.index;
    final suggested = _session.suggestedEpisode(_hits, episode: _targetEpisode);
    final animes = _animes.isEmpty && !_searching
        ? rankDanmakuWorks(_session.candidates, _session.suggestedQuery)
        : _animes;
    final recommendedWork = confidentDanmakuWork(animes, parseDanmakuQuery(_query.text).keyword);
    final enabled = embedded
        ? PlayerDrawerToggle(label: t.danmaku.show, value: _session.enabled, onChanged: _setEnabled)
        : FocusableSwitchListTile(
            key: const ValueKey('danmaku-enabled'),
            contentPadding: widget.settingsPage ? null : EdgeInsets.zero,
            title: Text(t.danmaku.show),
            subtitle: Text(loaded == null ? t.danmaku.notLoaded : t.danmaku.currentSource(source: loaded)),
            value: _session.enabled,
            onChanged: _setEnabled,
          );
    final heatmap = embedded
        ? PlayerDrawerToggle(
            label: t.danmaku.heatmap,
            value: _session.heatmapEnabled,
            onChanged: (value) => _save(() => _session.updateStyle(heatmapEnabled: value)),
          )
        : FocusableSwitchListTile(
            key: const ValueKey('danmaku-heatmap'),
            contentPadding: widget.settingsPage ? null : EdgeInsets.zero,
            title: Text(t.danmaku.heatmap),
            subtitle: Text(t.danmaku.heatmapDescription),
            value: _session.heatmapEnabled,
            onChanged: (value) => _save(() => _session.updateStyle(heatmapEnabled: value)),
          );
    final sources = FocusableListTile(
      key: const ValueKey('danmaku-manage-sources'),
      contentPadding: widget.settingsPage ? null : EdgeInsets.zero,
      leading: const AppIcon(Symbols.dns_rounded),
      title: Text(t.danmaku.sources),
      subtitle: Text(t.danmaku.sourceCount(count: _session.sources.length)),
      trailing: const AppIcon(Symbols.chevron_right_rounded),
      onTap: () => _openSources(add: _session.sources.isEmpty),
    );
    final offset = embedded
        ? PlayerDrawerStepper(
            key: const ValueKey('danmaku-time-offset'),
            label: t.danmaku.timeOffset,
            valueText: t.danmaku.offsetValue(value: _session.offsetMs),
            onDecrement: () => _save(() => _session.updateStyle(offsetMs: _session.offsetMs - 500)),
            onIncrement: () => _save(() => _session.updateStyle(offsetMs: _session.offsetMs + 500)),
          )
        : _slider(
            sliderKey: const ValueKey('danmaku-time-offset'),
            title: t.danmaku.timeOffset,
            description: t.danmaku.timeOffsetDescription,
            valueText: t.danmaku.offsetValue(value: _session.offsetMs),
            value: _session.offsetMs.toDouble(),
            min: -60000,
            max: 60000,
            divisions: 240,
            onChanged: (value) => _save(() => _session.updateStyle(offsetMs: value.round())),
          );
    final styleControls = <Widget>[
      _slider(
        sliderKey: const ValueKey('danmaku-opacity'),
        title: t.danmaku.opacity,
        valueText: '${(_session.opacity * 100).round()}%',
        value: _session.opacity,
        min: 0.2,
        max: 1,
        divisions: 8,
        onChanged: (value) => _save(() => _session.updateStyle(opacity: value)),
      ),
      _slider(
        sliderKey: const ValueKey('danmaku-font-size'),
        title: t.danmaku.fontSize,
        valueText: embedded
            ? '${_session.fontSize.round()}'
            : t.danmaku.fontSizeValue(value: _session.fontSize.round()),
        value: _session.fontSize,
        min: 12,
        max: 28,
        divisions: 8,
        onChanged: (value) => _save(() => _session.updateStyle(fontSize: value)),
      ),
    ];
    final matchControls = <Widget>[
      FocusableSwitchListTile(
        contentPadding: widget.settingsPage ? null : EdgeInsets.zero,
        title: Text(t.danmaku.remember),
        subtitle: Text(t.danmaku.rememberDescription),
        value: _remember,
        onChanged: (value) => setState(() => _remember = value),
      ),
      FocusableSwitchListTile(
        contentPadding: widget.settingsPage ? null : EdgeInsets.zero,
        title: Text(t.danmaku.withRelated),
        value: _session.withRelated,
        onChanged: (value) => _save(() => _session.updateStyle(withRelated: value)),
      ),
      FocusableListTile(
        contentPadding: widget.settingsPage ? null : EdgeInsets.zero,
        title: Text(t.danmaku.conversion),
        subtitle: Text(switch (_session.chConvert) {
          1 => t.danmaku.conversionSimplified,
          2 => t.danmaku.conversionTraditional,
          _ => t.danmaku.conversionNone,
        }),
        trailing: const AppIcon(Symbols.swap_horiz_rounded),
        onTap: () => _save(() => _session.updateStyle(chConvert: (_session.chConvert + 1) % 3)),
      ),
    ];
    final searchControls = <Widget>[
      if (!embedded) _localImportTile(),
      if (!embedded) Text(t.danmaku.onlineSearch, style: Theme.of(context).textTheme.titleMedium),
      FocusableTextField(
        key: const ValueKey('danmaku-search-query'),
        controller: _query,
        focusNode: _queryFocus,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(hintText: t.danmaku.queryHint, border: const OutlineInputBorder(), isDense: true),
        onSubmitted: (_) => _search(),
      ),
      DanmakuActionButton(
        label: _searching ? t.danmaku.searching : t.danmaku.searchTitles,
        icon: Symbols.search_rounded,
        onPressed: _searching || _loading ? null : _search,
      ),
      FocusableListTile(
        contentPadding: widget.settingsPage ? null : EdgeInsets.zero,
        title: Text(t.danmaku.sourceSelection),
        subtitle: Text(_sourceName(_session.selectedSourceId)),
        trailing: AppIcon(_sourcePickerOpen ? Symbols.expand_less_rounded : Symbols.expand_more_rounded),
        onTap: () => setState(() => _sourcePickerOpen = !_sourcePickerOpen),
      ),
      if (_sourcePickerOpen) ...[
        FocusableListTile(
          title: Text(t.danmaku.sourceAutomatic),
          selected: _session.selectedSourceId == null,
          trailing: _session.selectedSourceId == null ? const AppIcon(Symbols.check_rounded) : null,
          onTap: () => _selectSource(null),
        ),
        for (final source in _session.sources.where((source) => source.enabled))
          FocusableListTile(
            title: Text(source.name),
            selected: _session.selectedSourceId == source.id,
            trailing: _session.selectedSourceId == source.id ? const AppIcon(Symbols.check_rounded) : null,
            onTap: () => _selectSource(source.id),
          ),
      ],
      for (final failure in _session.sourceFailures.entries)
        DanmakuErrorText(
          t.danmaku.sourceFailure(source: _sourceName(failure.key), reason: danmakuFailureMessage(failure.value)),
        ),
      if (_selectedAnime == null)
        for (final anime in animes)
          FocusableListTile(
            title: Text(anime.title),
            subtitle: Text(_sourceName(anime.sourceId)),
            selected: identical(anime, recommendedWork),
            trailing: identical(anime, recommendedWork)
                ? Text(t.danmaku.recommended)
                : const AppIcon(Symbols.chevron_right_rounded),
            onTap: _loading ? null : () => _selectAnime(anime),
          ),
      if (_selectedAnime != null) ...[
        FocusableListTile(
          title: Text(_selectedAnime!.title),
          subtitle: Text(t.danmaku.changeTitle),
          leading: const AppIcon(Symbols.arrow_back_rounded),
          onTap: () {
            _requestGeneration++;
            setState(() {
              _selectedAnime = null;
              _hits = const [];
              _loading = false;
              _error = null;
            });
          },
        ),
        Text(t.danmaku.selectEpisode, style: Theme.of(context).textTheme.titleMedium),
      ],
      if (_loading) const Center(heightFactor: 1, child: CircularProgressIndicator()),
      for (final hit in [?suggested, ..._hits.where((hit) => !identical(hit, suggested))])
        FocusableListTile(
          title: Text(hit.label),
          subtitle: hit.commentCount == null ? null : Text(t.danmaku.commentCount(count: hit.commentCount!)),
          selected: identical(hit, suggested),
          trailing: identical(hit, suggested) ? Text(t.danmaku.recommended) : const AppIcon(Symbols.download_rounded),
          onTap: _loading ? null : () => _loadHit(hit),
        ),
      if (widget.metadata?.kind == MediaKind.episode)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PlayerDrawerStepper(
              key: const ValueKey('danmaku-episode-offset'),
              label: t.danmaku.episodeOffset,
              valueText: '${_session.episodeOffset}',
              onDecrement: () => _save(() => _setEpisodeOffset(_session.episodeOffset - 1)),
              onIncrement: () => _save(() => _setEpisodeOffset(_session.episodeOffset + 1)),
              onReset: () => _save(() => _setEpisodeOffset(0)),
            ),
            Text(
              targetEpisode == null
                  ? t.danmaku.episodeOffsetDescription
                  : '${t.danmaku.episodeOffsetDescription}\n${t.danmaku.targetEpisode(number: targetEpisode + _session.episodeOffset)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
    ];
    final body = ListView(
      controller: _scroll,
      shrinkWrap: !widget.settingsPage,
      padding: widget.settingsPage ? const EdgeInsets.only(bottom: 24) : const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (_error != null) DanmakuErrorText(_error!),
        if (widget.settingsPage) ...[
          SettingsGroup(title: t.settings.general, children: [enabled, sources, heatmap]),
          SettingsGroup(title: t.danmaku.remember, children: [offset, ...matchControls]),
          SettingsGroup(title: t.settings.display, children: [...styleControls, ..._presentationControls()]),
          SettingsGroup(
            title: t.danmaku.onlineSearch,
            children: [
              Padding(
                padding: const EdgeInsets.all(13),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: searchControls),
              ),
            ],
          ),
        ] else if (embedded && _panel == _DanmakuPanel.search) ...[
          ...searchControls,
          const SizedBox(height: 12),
          matchControls.first,
        ] else if (embedded && _panel == _DanmakuPanel.area) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final count in [4, 8, 12])
                PlayerDrawerChoice(
                  label: t.danmaku.topRows(n: count),
                  selected: _session.presentation.scrollLines == count,
                  onTap: () => _save(() => _session.updateStyle(scrollLines: count)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          for (final row in [
            ('scroll', t.danmaku.scrollLines, _session.presentation.scrollLines),
            ('top', t.danmaku.topLines, _session.presentation.topLines),
            ('bottom', t.danmaku.bottomLines, _session.presentation.bottomLines),
          ])
            PlayerDrawerStepper(
              key: ValueKey('danmaku-${row.$1}-lines'),
              label: row.$2,
              valueText: '${row.$3}',
              onDecrement: () => _setLines(row.$1, (row.$3 - 1).clamp(0, 30)),
              onIncrement: () => _setLines(row.$1, (row.$3 + 1).clamp(0, 30)),
            ),
          const SizedBox(height: 12),
          _buildAreaPreview(),
          const SizedBox(height: 12),
          Text(t.danmaku.displayAreaDescription, style: Theme.of(context).textTheme.bodySmall),
        ] else if (embedded && _panel == _DanmakuPanel.style) ...[
          ..._presentationControls().take(2),
          ..._presentationControls().skip(5),
          const Divider(height: 24),
          ...matchControls.skip(1),
        ] else if (embedded) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .03),
              border: Border.all(color: Colors.white.withValues(alpha: .07)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _session.displayQuery.isNotEmpty
                      ? _session.displayQuery
                      : widget.metadata?.displayTitle ?? t.danmaku.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  loaded == null
                      ? t.danmaku.notLoaded
                      : '$loaded · ${t.danmaku.commentCount(count: _session.comments.length)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              PlayerDrawerChoice(
                key: const ValueKey('danmaku-open-search'),
                feedbackOnChange: false,
                label: t.danmaku.onlineSearch,
                selected: false,
                onTap: () => _showPanel(_DanmakuPanel.search),
              ),
              PlayerDrawerChoice(
                key: const ValueKey('danmaku-local-import'),
                feedbackOnChange: false,
                label: t.danmaku.localImport,
                selected: false,
                onTap: _pickLocal,
              ),
            ],
          ),
          enabled,
          heatmap,
          FocusableListTile(
            key: const ValueKey('danmaku-open-area'),
            contentPadding: EdgeInsets.zero,
            leading: const AppIcon(Symbols.vertical_align_top_rounded, size: 18),
            title: Text(t.danmaku.displayArea),
            subtitle: Text(t.danmaku.topRows(n: _session.presentation.scrollLines)),
            trailing: const AppIcon(Symbols.chevron_right_rounded, size: 18),
            onTap: () => _showPanel(_DanmakuPanel.area),
          ),
          ...styleControls,
          offset,
          FocusableListTile(
            key: const ValueKey('danmaku-open-style'),
            contentPadding: EdgeInsets.zero,
            leading: const AppIcon(Symbols.tune_rounded, size: 18),
            title: Text(t.danmaku.styleAndFilters),
            trailing: const AppIcon(Symbols.chevron_right_rounded, size: 18),
            onTap: () => _showPanel(_DanmakuPanel.style),
          ),
          sources,
        ] else ...[
          enabled,
          ...styleControls,
          heatmap,
          offset,
          const Divider(),
          sources,
          ...searchControls,
          ...matchControls,
          const Divider(),
          ..._presentationControls(),
        ],
      ],
    );
    if (widget.settingsPage) return SettingsAppearance(child: body);
    return BaseVideoControlSheet(
      title: embedded
          ? switch (_panel) {
              _DanmakuPanel.search => t.danmaku.onlineSearch,
              _DanmakuPanel.area => t.danmaku.displayArea,
              _DanmakuPanel.style => t.danmaku.styleAndFilters,
              _DanmakuPanel.main => t.danmaku.title,
            }
          : t.danmaku.title,
      onBack: embedded && _panel != _DanmakuPanel.main ? () => _showPanel(_DanmakuPanel.main) : widget.onBack,
      icon: Symbols.subtitles_rounded,
      child: body,
    );
  }

  void _setLines(String kind, int count) => _save(
    () => _session.updateStyle(
      scrollLines: kind == 'scroll' ? count : null,
      topLines: kind == 'top' ? count : null,
      bottomLines: kind == 'bottom' ? count : null,
    ),
  );

  Widget _buildAreaPreview() {
    final count = _session.presentation.scrollLines;
    return Semantics(
      label: t.danmaku.topRows(n: count),
      child: Container(
        key: const ValueKey('danmaku-area-preview'),
        height: 104,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .035),
          border: Border.all(color: Colors.white.withValues(alpha: .12)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var row = 0; row < 12; row++)
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: row < count ? .65 - (row % 3) * .12 : .9,
                    child: Container(
                      height: 2,
                      color: row < count ? Colors.white.withValues(alpha: .8) : Colors.white.withValues(alpha: .08),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _localImportTile() => FocusableListTile(
    key: const ValueKey('danmaku-local-import'),
    contentPadding: widget.settingsPage ? null : EdgeInsets.zero,
    leading: const AppIcon(Symbols.folder_open_rounded),
    title: Text(t.danmaku.localImport),
    subtitle: Text(t.danmaku.localImportDescription),
    onTap: _pickLocal,
  );

  List<Widget> _presentationControls() {
    final style = _session.presentation;
    return [
      _slider(
        sliderKey: const ValueKey('danmaku-speed'),
        title: t.danmaku.speed,
        valueText: '${style.speed.toStringAsFixed(2)}x',
        value: style.speed,
        min: 0.25,
        max: 3,
        divisions: 11,
        onChanged: (value) => _save(() => _session.updateStyle(speed: value)),
      ),
      _slider(
        sliderKey: const ValueKey('danmaku-max-on-screen'),
        title: t.danmaku.maxOnScreen,
        valueText: '${style.maxOnScreen}',
        value: style.maxOnScreen.toDouble(),
        min: 1,
        max: 200,
        divisions: 199,
        onChanged: (value) => _save(() => _session.updateStyle(maxOnScreen: value.round())),
      ),
      for (final row in [
        ('scroll', t.danmaku.scrollLines, style.scrollLines),
        ('top', t.danmaku.topLines, style.topLines),
        ('bottom', t.danmaku.bottomLines, style.bottomLines),
      ])
        _slider(
          sliderKey: ValueKey('danmaku-${row.$1}-lines'),
          title: row.$2,
          valueText: '${row.$3}',
          value: row.$3.toDouble(),
          min: 0,
          max: 30,
          divisions: 30,
          onChanged: (value) => _save(
            () => _session.updateStyle(
              scrollLines: row.$1 == 'scroll' ? value.round() : null,
              topLines: row.$1 == 'top' ? value.round() : null,
              bottomLines: row.$1 == 'bottom' ? value.round() : null,
            ),
          ),
        ),
      FocusableSwitchListTile(
        key: const ValueKey('danmaku-prevent-overlap'),
        contentPadding: widget.settingsPage ? null : EdgeInsets.zero,
        title: Text(t.danmaku.preventOverlap),
        value: style.preventOverlap,
        onChanged: (value) => _save(() => _session.updateStyle(preventOverlap: value)),
      ),
      FocusableSwitchListTile(
        key: const ValueKey('danmaku-merge-duplicates'),
        contentPadding: widget.settingsPage ? null : EdgeInsets.zero,
        title: Text(t.danmaku.mergeDuplicates),
        subtitle: Text(t.danmaku.duplicateDescription),
        value: style.mergeDuplicates,
        onChanged: (value) => _save(() => _session.updateStyle(mergeDuplicates: value)),
      ),
      FocusableTextField(
        key: const ValueKey('danmaku-blocked-keywords'),
        controller: _keywords,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: t.danmaku.blockedKeywords,
          hintText: t.danmaku.blockedKeywordsHint,
          border: const OutlineInputBorder(),
        ),
      ),
      DanmakuActionButton(
        label: t.common.save,
        onPressed: () => _save(() => _session.updateStyle(blockedKeywords: _keywords.text.split('\n'))),
      ),
      Text(t.danmaku.countSemantics, style: Theme.of(context).textTheme.bodySmall),
    ];
  }

  Widget _slider({
    Key? sliderKey,
    required String title,
    String? description,
    required String valueText,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    if (BaseVideoControlSheet.embeddedIn(context)) {
      return PlayerDrawerRange(
        key: sliderKey,
        label: title,
        valueText: valueText,
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.settingsPage ? 13 : 0, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(title, style: widget.settingsPage ? SettingsPresentation.title(context) : null),
              Text(valueText, style: widget.settingsPage ? SettingsPresentation.value(context) : null),
            ],
          ),
          if (description != null) Text(description, style: Theme.of(context).textTheme.bodySmall),
          Semantics(
            label: title,
            value: valueText,
            child: FocusableSlider(
              key: sliderKey,
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              semanticFormatterCallback: (_) => valueText,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
