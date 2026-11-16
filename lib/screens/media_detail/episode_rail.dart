import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Visual episode groups are independent of the server's paging size.
int groupForEpisodeIndex(int index) => math.max(0, index) ~/ 10;

String episodeGroupLabel(int group, int loadedCount) => '${group * 10 + 1}–${math.min((group + 1) * 10, loadedCount)}';

/// A continuous rail of confirmed episodes. Paging remains owned by the detail
/// screen; an unknown server total never becomes an empty episode card.
class DetailEpisodeRail extends StatefulWidget {
  const DetailEpisodeRail({
    super.key,
    required this.episodeCount,
    required this.height,
    required this.itemBuilder,
    required this.groupsBuilder,
    required this.onPositionChanged,
    required this.resetToken,
    this.initialIndex = 0,
    this.hasTail = false,
    this.canLoadMore = false,
    this.onLoadMore,
    this.onRequestIndex,
    this.itemWidth = cardWidth,
  });

  static const double cardWidth = 202;
  static const double gap = 12;
  static const double itemExtent = cardWidth + gap;

  final double itemWidth;
  final int episodeCount;
  final double height;
  final IndexedWidgetBuilder itemBuilder;
  final Widget Function(BuildContext, int, ValueChanged<int>) groupsBuilder;
  final ValueChanged<int> onPositionChanged;
  final Object resetToken;
  final int initialIndex;
  final bool hasTail;
  final bool canLoadMore;
  final VoidCallback? onLoadMore;
  final Future<bool> Function(int index)? onRequestIndex;

  @override
  State<DetailEpisodeRail> createState() => _DetailEpisodeRailState();
}

class _DetailEpisodeRailState extends State<DetailEpisodeRail> {
  double get _itemExtent => widget.itemWidth + DetailEpisodeRail.gap;
  late final ScrollController _controller;
  late final ValueNotifier<int> _group;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController()..addListener(_onScroll);
    _group = ValueNotifier(groupForEpisodeIndex(widget.initialIndex));
    _schedulePosition(widget.initialIndex);
  }

  @override
  void didUpdateWidget(covariant DetailEpisodeRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resetToken != oldWidget.resetToken) {
      _group.value = groupForEpisodeIndex(widget.initialIndex);
      _schedulePosition(widget.initialIndex);
    } else if (widget.episodeCount != oldWidget.episodeCount || widget.canLoadMore != oldWidget.canLoadMore) {
      _schedulePaging();
    }
  }

  void _schedulePosition(int index) {
    final token = widget.resetToken;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.resetToken != token || !_controller.hasClients) return;
      _controller.jumpTo(_offsetFor(index));
      _onScroll();
    });
  }

  void _schedulePaging() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onScroll();
    });
  }

  double _offsetFor(int index) =>
      (math.max(0, index) * _itemExtent).clamp(0.0, _controller.position.maxScrollExtent).toDouble();

  Future<void> _scrollToGroup(int group) async {
    final token = widget.resetToken;
    final index = group * 10;
    final needsPage = index >= widget.episodeCount;
    if (widget.onRequestIndex != null && !await widget.onRequestIndex!(index)) return;
    if (!mounted || token != widget.resetToken) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || token != widget.resetToken || !_controller.hasClients) return;
    if (needsPage) {
      // Fixed-extent lists may retain the previous page's scroll metrics until
      // they move. A jump lays out the newly loaded group without letting the
      // old extent clamp an animation to the previous page's last episode.
      _controller.jumpTo(index * _itemExtent);
    } else {
      _scrollToIndex(index);
    }
  }

  void _scrollToIndex(int index) {
    if (!_controller.hasClients) return;
    final offset = math.max(0, index) * _itemExtent;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpTo(offset);
    } else {
      _controller.animateTo(offset, duration: const Duration(milliseconds: 240), curve: Curves.easeOut);
    }
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final index = (_controller.offset / _itemExtent).round().clamp(0, math.max(0, widget.episodeCount - 1)).toInt();
    _group.value = groupForEpisodeIndex(index);
    widget.onPositionChanged(index);
    // Measure the real tail, excluding the trailing alignment space.
    final tailDistance =
        widget.episodeCount * _itemExtent - (_controller.offset + _controller.position.viewportDimension);
    if (widget.canLoadMore && tailDistance <= _itemExtent * 2) {
      widget.onLoadMore?.call();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _group.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        height: widget.height,
        child: LayoutBuilder(
          builder: (context, constraints) => ListView.builder(
            key: const ValueKey('detail_episode_rail_scroll'),
            // Real trailing space lets even a short final group align its first
            // card with the viewport's left edge, without adding episode items.
            padding: EdgeInsets.only(right: math.max(0, constraints.maxWidth - _itemExtent)),
            controller: _controller,
            scrollDirection: Axis.horizontal,
            itemExtent: _itemExtent,
            itemCount: widget.episodeCount + (widget.hasTail ? 1 : 0),
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(right: DetailEpisodeRail.gap),
              child: widget.itemBuilder(context, index),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      ValueListenableBuilder<int>(
        valueListenable: _group,
        builder: (context, group, _) => widget.groupsBuilder(context, group, _scrollToGroup),
      ),
    ],
  );
}
