import 'package:flutter/material.dart';

import '../media/media_item.dart';
import '../services/settings_service.dart';
import '../utils/platform_detector.dart';
import 'media_grid_delegate.dart';
import 'settings_builder.dart';
import 'sliver_cross_axis_layout_builder.dart';

@immutable
class MediaCardSliverPosition {
  const MediaCardSliverPosition({
    required this.index,
    required this.itemCount,
    required this.columnCount,
    required this.isGrid,
    this.layoutEpoch,
  });

  final int index;
  final int itemCount;
  final int columnCount;
  final bool isGrid;
  final Object? layoutEpoch;

  bool get isFirstRow => index < columnCount;
  bool get isFirstColumn => index % columnCount == 0;
  bool get isLastColumn => index % columnCount == columnCount - 1;
  bool get disableScale => !isGrid;
}

typedef MediaCardSliverItemBuilder = Widget Function(BuildContext context, MediaCardSliverPosition position);

/// Shared list/grid sliver switch for media-card surfaces.
///
/// Consumers retain card construction and focus policy while this widget owns
/// the identical sliver wrappers, grid geometry, and delegate configuration.
class MediaCardSliverLayout extends StatelessWidget {
  const MediaCardSliverLayout({
    super.key,
    required this.viewMode,
    required this.itemCount,
    required this.density,
    required this.padding,
    required this.itemBuilder,
    this.findChildIndexCallback,
    this.fullBleedImage = false,
    this.useWideAspectRatio = false,
    this.shape,
    this.crossAxisExtentForColumnCount,
    this.onGridGeometry,
    this.listEpoch,
    this.gridEpochBuilder,
    this.minimumItemWidth,
  });

  final ViewMode viewMode;
  final int itemCount;
  final int density;
  final EdgeInsetsGeometry padding;
  final MediaCardSliverItemBuilder itemBuilder;
  final ChildIndexGetter? findChildIndexCallback;
  final bool fullBleedImage;
  final bool useWideAspectRatio;
  final CardShape? shape;
  final double? Function(double crossAxisExtent)? crossAxisExtentForColumnCount;
  final ValueChanged<MediaGridGeometry>? onGridGeometry;
  final Object? listEpoch;
  final Object? Function(MediaGridGeometry geometry)? gridEpochBuilder;
  final double? minimumItemWidth;

  @override
  Widget build(BuildContext context) {
    if (viewMode == ViewMode.list) {
      return SliverPadding(
        padding: padding,
        sliver: SliverList.builder(
          addAutomaticKeepAlives: false,
          addSemanticIndexes: false,
          itemCount: itemCount,
          findChildIndexCallback: findChildIndexCallback,
          itemBuilder: (context, index) => itemBuilder(
            context,
            MediaCardSliverPosition(
              index: index,
              itemCount: itemCount,
              columnCount: 1,
              isGrid: false,
              layoutEpoch: listEpoch,
            ),
          ),
        ),
      );
    }

    // Watched here — the single [MediaGridGeometry.resolve] call site — so
    // every grid re-lays out live when the grid-spacing setting changes,
    // without each screen adding the pref to its own watch list. The builder
    // ignores the value; resolve() reads it through the delegate's funnel.
    return SettingValueBuilder<GridSpacing>(
      pref: SettingsService.gridSpacing,
      builder: (context, _, _) => SliverPadding(
        padding: padding,
        sliver: SliverCrossAxisLayoutBuilder(
          builder: (context, crossAxisExtent) {
            final compactPosters =
                PlatformDetector.isMobile(context) &&
                !PlatformDetector.isTV() &&
                MediaQuery.sizeOf(context).width < 600 &&
                !useWideAspectRatio &&
                !fullBleedImage &&
                (shape == null || shape == CardShape.poster);
            final posterExtent = compactPosters ? crossAxisExtent.clamp(0.0, 341.0) : crossAxisExtent;
            final geometry = MediaGridGeometry.resolve(
              context: context,
              crossAxisExtent: posterExtent,
              crossAxisExtentForColumnCount: crossAxisExtentForColumnCount?.call(crossAxisExtent),
              density: density,
              useWideAspectRatio: useWideAspectRatio,
              fullBleedImage: fullBleedImage,
              shape: shape,
              minimumItemWidth: compactPosters ? null : minimumItemWidth,
              columnCountOverride: compactPosters ? 3 : null,
              spacingOverride: compactPosters ? 10 : null,
            );
            onGridGeometry?.call(geometry);
            final layoutEpoch = gridEpochBuilder?.call(geometry);
            final grid = SliverGrid.builder(
              addAutomaticKeepAlives: false,
              addSemanticIndexes: false,
              gridDelegate: geometry.delegate,
              itemCount: itemCount,
              findChildIndexCallback: findChildIndexCallback,
              itemBuilder: (context, index) => itemBuilder(
                context,
                MediaCardSliverPosition(
                  index: index,
                  itemCount: itemCount,
                  columnCount: geometry.columnCount,
                  isGrid: true,
                  layoutEpoch: layoutEpoch,
                ),
              ),
            );
            return compactPosters
                ? SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: (crossAxisExtent - posterExtent) / 2),
                    sliver: grid,
                  )
                : grid;
          },
        ),
      ),
    );
  }
}
