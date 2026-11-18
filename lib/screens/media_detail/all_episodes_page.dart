part of '../media_detail_screen.dart';

typedef _EpisodePageData = ({List<MediaItem> episodes, int count, bool hasMore});

class _AllEpisodesPage extends StatefulWidget {
  const _AllEpisodesPage({
    required this.title,
    required this.initial,
    required this.selected,
    required this.thumbnail,
    required this.loadNext,
  });

  final String title;
  final _EpisodePageData initial;
  final String? selected;
  final Widget Function(MediaItem episode) thumbnail;
  final Future<_EpisodePageData?> Function(int index) loadNext;

  @override
  State<_AllEpisodesPage> createState() => _AllEpisodesPageState();
}

class _AllEpisodesPageState extends State<_AllEpisodesPage> {
  late _EpisodePageData _data = widget.initial;
  ScrollController? _scrollController;
  bool _loading = false;
  bool _failed = false;

  void _queueNextPage() {
    if (_loading || _failed || !_data.hasMore) return;
    _loading = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (ModalRoute.of(context)?.isCurrent != true) {
        _loading = false;
        return;
      }
      final next = await widget.loadNext(_data.episodes.length);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = next == null || (next.hasMore && next.episodes.length <= _data.episodes.length);
        if (next != null) _data = next;
      });
    });
  }

  @override
  void dispose() {
    _scrollController?.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (ModalRoute.of(context)?.isCurrent == true) Navigator.pop(context, index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Focus(
      onKeyEvent: (_, event) => handleBackKeyNavigation(context, event),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: theme.colorScheme.surface,
          foregroundColor: theme.colorScheme.onSurface,
          titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(color: theme.colorScheme.onSurface),
          title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const gap = 12.0;
                    final available = math.max(1.0, constraints.maxWidth - 32);
                    final columns = ((available + gap) / 150).floor().clamp(1, 8);
                    final width = (available - gap * (columns - 1)) / columns;
                    final height = width * 9 / 16;
                    final extent = height + 10 + MediaQuery.textScalerOf(context).scale(14) * 2.8;
                    if (_scrollController == null) {
                      final selected = _data.episodes.indexWhere((episode) => episode.globalKey == widget.selected);
                      final rows = (_data.count + columns - 1) ~/ columns;
                      final maxOffset = math.max(0.0, 32 + rows * (extent + gap) - gap - constraints.maxHeight);
                      _scrollController = ScrollController(
                        initialScrollOffset: ((math.max(0, selected) ~/ columns) * (extent + gap)).clamp(
                          0.0,
                          maxOffset,
                        ),
                      );
                    }
                    return GridView.builder(
                      controller: _scrollController,
                      key: const ValueKey('detail_episode_grid'),
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisExtent: extent,
                        crossAxisSpacing: gap,
                        mainAxisSpacing: gap,
                      ),
                      itemCount: _data.count,
                      itemBuilder: (context, index) {
                        if (index >= _data.episodes.length - 1) _queueNextPage();
                        final episode = _data.episodes.elementAtOrNull(index);
                        final selected = episode != null && episode.globalKey == widget.selected;
                        final title = episode == null
                            ? t.common.episodeNumber(number: index + 1)
                            : episodeDisplayTitle(episode);
                        return Semantics(
                          selected: selected,
                          button: true,
                          child: FocusableWrapper(
                            key: ValueKey('all_episodes_item_$index'),
                            autofocus: selected,
                            disableScale: true,
                            delegateFocusBorder: true,
                            onSelect: () => _select(index),
                            child: InkWell(
                              canRequestFocus: false,
                              onTap: () => _select(index),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _DetailEpisodeFrame(
                                    episodeId: episode?.id ?? 'unloaded_$index',
                                    height: height,
                                    selected: selected,
                                    child: episode == null
                                        ? ColoredBox(color: theme.colorScheme.surfaceContainerLow)
                                        : widget.thumbnail(episode),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14, height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              if (_failed)
                TextButton(
                  onPressed: () {
                    setState(() => _failed = false);
                    _queueNextPage();
                  },
                  child: Text(t.common.retry),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
