import 'dart:async';
import '../media/ids.dart';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:plezy/widgets/app_icon.dart';
import '../widgets/server_activities_button.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import '../focus/focusable_action_bar.dart';
import '../focus/hub_vertical_navigation.dart';
import '../focus/locked_hub_controller.dart';
import '../focus/input_mode_tracker.dart';
import '../focus/key_event_utils.dart';

import '../media/media_item.dart';
import '../media/media_item_types.dart';
import '../media/media_server_client.dart';
import '../media/media_hub.dart';
import '../utils/home_hero_selection.dart';
import '../utils/media_image_helper.dart';
import '../widgets/cycling_media_backdrop.dart';
import '../widgets/vidhub_ambient_backdrop.dart';
import '../utils/ambient_palette_extractor.dart';
import '../widgets/fusion_home_hero.dart';
import '../widgets/hero_metadata_badges.dart';
import '../widgets/backend_badge.dart';
import '../navigation/home_theme.dart';
import '../navigation/navigation_tabs.dart';
import '../widgets/optimized_media_image.dart' show ClearLogoImage;
import '../widgets/toolbar_scrim.dart';
import '../widgets/system_clock.dart';
import '../providers/discover_provider.dart';
import '../theme/home_typography.dart';
import '../theme/mono_presentation.dart';
import '../providers/multi_server_provider.dart';
import '../providers/watch_state_store.dart';
import '../widgets/hub_section.dart';
import '../widgets/app_menu.dart';
import '../widgets/clickable_cursor.dart';
import '../widgets/profile_switching_overlay.dart';
import 'profile/profile_switch_screen.dart';
import 'profile/profile_teardown.dart';
import '../profiles/active_profile_provider.dart';
import '../profiles/profile.dart';
import '../profiles/profile_activation.dart';
import '../profiles/profile_avatar.dart';
import '../services/settings_service.dart';
import '../widgets/settings_builder.dart';
import '../widgets/fitting_title_text.dart';
import '../widgets/tv_browse_rail.dart';
import '../widgets/tv_spotlight_scaffold.dart';
import '../mixins/refreshable.dart';
import '../mixins/tab_visibility_aware.dart';
import '../i18n/strings.g.dart';
import '../utils/app_logger.dart';
import '../utils/dialogs.dart';
import '../utils/hub_icons.dart';
import '../utils/media_navigation_helper.dart';
import '../utils/provider_extensions.dart';
import '../utils/snackbar_helper.dart';
import '../utils/video_player_navigation.dart';
import '../utils/layout_constants.dart';
import '../utils/platform_detector.dart';
import '../utils/tone_mapped_logo_image.dart';
import '../theme/mono_tokens.dart';
import 'libraries/content_state_builder.dart';
import 'libraries/state_messages.dart';
import 'discover_loading_skeleton.dart';
import 'main_screen.dart';
import '../navigation/settings_shortcut.dart';
import '../watch_together/watch_together.dart';
import '../providers/companion_remote_provider.dart';
import '../widgets/companion_remote/remote_session_dialog.dart';
import 'companion_remote/mobile_remote_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key, this.heroRandom});

  @visibleForTesting
  final math.Random? heroRandom;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with Refreshable, ManualRefreshable, FullRefreshable, TabVisibilityAware, FocusableTab, WidgetsBindingObserver {
  ThemeData get _cinemaTheme => HomeTypography.apply(
    Theme.of(context),
    tv: PlatformDetector.isTV(),
    tablet: MonoPresentation.isTablet(context),
    artworkSurface: HomeThemeScope.colorOf(context),
  ).copyWith(scaffoldBackgroundColor: HomeThemeScope.colorOf(context));

  static const Duration _heroAutoScrollDuration = Duration(seconds: 8);
  static const Duration _indicatorUpdateInterval = Duration(milliseconds: 200);

  /// Data + refresh policy live in [DiscoverProvider]; this state keeps only
  /// UI concerns (hero carousel, focus, spotlight). The proxy getters keep
  /// the build code reading naturally.
  late final DiscoverProvider _discover;
  int _seenLoadGeneration = 0;
  bool _heroLoadInProgress = false;
  bool _heroStartedEmpty = false;
  bool _heroHasNavigated = false;

  String? _selectedHomeServerId;
  String? _sourceSnapshotId;
  List<MediaItem>? _sourceItemsInput;
  List<MediaHub>? _sourceHubsInput;
  List<MediaItem> _sourceItems = const [];
  List<MediaItem> _sourceHeroItems = const [];
  final Map<String?, HomeHeroSelection> _heroSelections = {};
  HomeHeroSelection get _heroSelection =>
      _heroSelections.putIfAbsent(_selectedHomeServerId, () => HomeHeroSelection(random: widget.heroRandom));
  List<MediaHub> _sourceHubs = const [];
  void _syncSourceLists() {
    if (_sourceSnapshotId == _selectedHomeServerId &&
        identical(_sourceItemsInput, _discover.onDeck) &&
        identical(_sourceHubsInput, _discover.hubs) &&
        !_heroSelection.needsResample) {
      return;
    }
    _sourceSnapshotId = _selectedHomeServerId;
    _sourceItemsInput = _discover.onDeck;
    _sourceHubsInput = _discover.hubs;
    _sourceItems = _selectedHomeServerId == null
        ? _discover.onDeck
        : _discover.onDeck.where((item) => item.serverId == _selectedHomeServerId).toList();
    _sourceHubs = _selectedHomeServerId == null
        ? _discover.hubs
        : _discover.hubs.where((hub) => hub.serverId == _selectedHomeServerId).toList();
    _sourceHeroItems = _heroSelection.update(_sourceItems.followedBy(_sourceHubs.expand((hub) => hub.items)));
  }

  List<MediaItem> get _onDeck {
    _syncSourceLists();
    return _sourceItems;
  }

  List<MediaItem> get _heroItems {
    _syncSourceLists();
    return _sourceHeroItems;
  }

  List<MediaHub> get _hubs {
    _syncSourceLists();
    return _sourceHubs;
  }

  bool get _hasMoreContinueWatching => _discover.hasMoreContinueWatching;
  bool get _isLoading => _discover.isLoading;
  bool get _areHubsLoading => _discover.areHubsLoading;
  String? get _errorMessage => _discover.errorMessage == null ? null : t.errors.unableToLoad(context: t.discover.title);

  bool _switchingProfile = false;
  final PageController _heroController = PageController();
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<int> _heroIndex = ValueNotifier<int>(0);

  /// Last decoded hero artwork per item, kept for items not yet selected.
  final Map<String, ImageProvider> _heroReadyImages = {};
  Timer? _autoScrollTimer;
  Timer? _indicatorTimer;
  final ValueNotifier<double> _indicatorProgress = ValueNotifier(0.0);
  bool _isAutoScrollPaused = false;
  bool _reduceMotion = false;
  bool _heroFocusPausedAutoScroll = false;
  final TvSpotlightController _spotlight = TvSpotlightController();
  bool _isTabVisible = true;

  bool _initialLoadComplete = false;
  bool _pendingTvBrowseRailFocus = false;

  /// Primary focus when the rail claim was armed; see [_railClaimAbandoned].
  FocusNode? _railClaimFocusOrigin;

  GlobalKey<HubSectionState>? _continueWatchingHubKey;
  final Map<String, GlobalKey<HubSectionState>> _hubKeysByIdentity = {};
  List<GlobalKey<HubSectionState>> _orderedHubKeys = const [];
  final _tvBrowseRailKey = GlobalKey<TvBrowseRailState>();
  final _hubFocusMemory = HubFocusMemory();

  late FocusNode _heroFocusNode;
  final _actionBarKey = GlobalKey<FocusableActionBarState>();
  final _serverActivitiesButtonKey = GlobalKey<ServerActivitiesButtonState>();
  final _userMenuKey = GlobalKey<AppMenuButtonState<String>>();

  /// Backend-neutral hero client lookup. Returns the actual
  /// [MediaServerClient] for the item's server (Plex or Jellyfin) so
  /// [MediaImageHelper] uses the right transcoder for sized URLs.
  MediaServerClient? _getMediaClientForItem(MediaItem? item) {
    final serverId = item?.serverId;
    if (serverId == null) {
      return context.tryGetMediaClientForServer(null);
    }
    return context.tryGetMediaClientForServer(ServerId(serverId));
  }

  String _hubIdentity(MediaHub hub) => '${hub.serverId ?? ''}:${hub.identifier ?? hub.id}';

  /// Rebuild the per-hub focus keys, keyed by hub *identity* rather than
  /// list position so a row's focus memory follows it when the provider
  /// re-sorts hubs (library-order change). Existing keys are reused to avoid
  /// mass deep unmounts (ARM32 stack overflow during finalizeTree);
  /// duplicate identities get positional suffixes so two rows can never
  /// share a GlobalKey.
  void _updateHubKeys() {
    final occurrences = <String, int>{};
    final liveIdentities = <String>{};
    final ordered = <GlobalKey<HubSectionState>>[];
    for (final hub in _hubs) {
      var identity = _hubIdentity(hub);
      final occurrence = occurrences.update(identity, (n) => n + 1, ifAbsent: () => 0);
      if (occurrence > 0) identity = '$identity#$occurrence';
      liveIdentities.add(identity);
      ordered.add(_hubKeysByIdentity.putIfAbsent(identity, GlobalKey<HubSectionState>.new));
    }
    _hubKeysByIdentity.removeWhere((identity, _) => !liveIdentities.contains(identity));
    _orderedHubKeys = ordered;
    _continueWatchingHubKey ??= GlobalKey<HubSectionState>();
  }

  List<GlobalKey<HubSectionState>> get _allHubKeys {
    final keys = <GlobalKey<HubSectionState>>[];
    if (_continueWatchingHubKey != null && _onDeck.isNotEmpty) {
      keys.add(_continueWatchingHubKey!);
    }
    keys.addAll(_orderedHubKeys);
    return keys;
  }

  bool get _isHeroSectionVisible => _heroItems.isNotEmpty && context.settingsRead(SettingsService.showHeroSection);

  // Memoized on provider list identity (the provider always replaces _onDeck/
  // _hubs with fresh instances on change, never mutates in place) so unrelated
  // rebuilds hand TvBrowseRail the same hubs list and its didUpdateWidget
  // fast path — and the cached rail widget below — kick in.
  List<MediaHub>? _tvBrowseHubsCache;
  (List<MediaItem>, List<MediaHub>, bool, String)? _tvBrowseHubsCacheKey;

  List<MediaHub> get _tvBrowseHubs {
    final key = (_onDeck, _hubs, _hasMoreContinueWatching, t.discover.continueWatching);
    if (_tvBrowseHubsCache != null && key == _tvBrowseHubsCacheKey) return _tvBrowseHubsCache!;
    final hubs = <MediaHub>[];
    if (_onDeck.isNotEmpty) {
      hubs.add(_continueWatchingHub);
    }
    hubs.addAll(_hubs.where((hub) => hub.items.isNotEmpty));
    _tvBrowseHubsCache = hubs;
    _tvBrowseHubsCacheKey = key;
    return hubs;
  }

  /// The synthesized Continue Watching row, rendered ahead of the backend hubs
  /// on both the mobile list and the TV rail.
  MediaHub get _continueWatchingHub => MediaHub(
    id: 'continue_watching',
    title: t.discover.continueWatching,
    type: 'mixed',
    identifier: '_continue_watching_',
    size: _onDeck.length + (_hasMoreContinueWatching ? 1 : 0),
    more: _hasMoreContinueWatching,
    items: _onDeck,
  );

  void _setSpotlightItem(MediaItem item) {
    _spotlight.select(item);
  }

  void _syncHomeTheme(MediaItem? item) {
    final controller = HomeThemeScope.read(context);
    if (controller == null) return;
    final paths =
        item?.heroArtCandidates(containerAspectRatio: MediaQuery.sizeOf(context).aspectRatio) ?? const <String>[];
    if (item == null || paths.isEmpty) {
      unawaited(controller.select(item?.globalKey, null));
      return;
    }
    controller.prepare(item.globalKey);
    // PageView builds the incoming page as soon as the swipe starts, so its
    // artwork usually decodes before onPageChanged selects it. Reuse that
    // image; the backdrop reports each image only once.
    final ready = _heroReadyImages[item.globalKey];
    if (ready != null && _isTabVisible) unawaited(controller.select(item.globalKey, _paletteImage(ready)));
  }

  static ImageProvider _paletteImage(ImageProvider image) => AmbientPaletteExtractor.samplingProvider(image);

  void _onHeroImageReady(MediaItem item, ImageProvider image) {
    _heroReadyImages[item.globalKey] = image;
    final selected = _heroItems.isEmpty ? null : _heroItems[_heroIndex.value.clamp(0, _heroItems.length - 1)];
    if (selected?.globalKey != item.globalKey || !_isTabVisible) return;
    unawaited(HomeThemeScope.read(context)?.select(item.globalKey, _paletteImage(image)));
  }

  void _syncSpotlightTheme() => _syncHomeTheme(_spotlight.resolve(_tvBrowseHubs));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final changed = reduceMotion != _reduceMotion;
    _reduceMotion = reduceMotion;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (PlatformDetector.isTV()) {
        _syncSpotlightTheme();
      } else {
        _syncHomeTheme(_heroItems.isEmpty ? null : _heroItems[_heroIndex.value.clamp(0, _heroItems.length - 1)]);
      }
      if (_reduceMotion) {
        _autoScrollTimer?.cancel();
        _stopIndicatorProgress();
      } else if (changed && _isTabVisible) {
        _startAutoScroll();
      }
    });
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  void _focusTopActions() {
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
    if (MainScreenFocusScope.of(context, listen: false)?.hasTopNavigation == true) {
      MainScreenFocusScope.focusSidebarOf(context);
      return;
    }
    final actionBar = _actionBarKey.currentState;
    if (actionBar != null) {
      actionBar.requestFocusOnFirst();
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
      _actionBarKey.currentState?.requestFocusOnFirst();
    });
  }

  void _focusTopBoundary() {
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
    if (PlatformDetector.isTV()) {
      _focusTopActions();
    } else if (_isHeroSectionVisible) {
      _heroFocusNode.requestFocus();
    } else {
      _focusTopActions();
    }
    _scrollToTop();
  }

  void _focusContentFromAppBar() {
    if (PlatformDetector.isTV()) {
      _focusTvBrowseRailWhenReady(immediate: true);
      return;
    }

    if (_isHeroSectionVisible) {
      _heroFocusNode.requestFocus();
      return;
    }

    final keys = _allHubKeys;
    if (keys.isNotEmpty) {
      keys.first.currentState?.requestFocusFromMemory();
    }
  }

  void _focusTvBrowseRailWhenReady({bool immediate = false}) {
    if (!PlatformDetector.isTV()) return;
    if (!_isTabVisible || !(ModalRoute.of(context)?.isCurrent ?? false)) {
      _pendingTvBrowseRailFocus = false;
      return;
    }

    _pendingTvBrowseRailFocus = true;
    _railClaimFocusOrigin = FocusManager.instance.primaryFocus;
    if (immediate && _tvBrowseHubs.isNotEmpty) {
      final rail = _tvBrowseRailKey.currentState;
      if (rail != null) {
        _pendingTvBrowseRailFocus = false;
        rail.requestFocus();
        return;
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_isTabVisible || !(ModalRoute.of(context)?.isCurrent ?? false)) {
        _pendingTvBrowseRailFocus = false;
        return;
      }
      if (_tvBrowseHubs.isEmpty) return;
      final rail = _tvBrowseRailKey.currentState;
      if (rail == null) return;
      _pendingTvBrowseRailFocus = false;
      rail.requestFocus();
    });
  }

  /// A rail-focus request stays armed while the rail has no hubs to focus
  /// (empty first load), so hubs landing later still receive it. It must not
  /// outlive the user's own navigation: hubs arriving minutes later would
  /// yank the remote off a sidebar item the user has since moved to.
  ///
  /// Where focus *sits* cannot tell those apart — MainScreen hands a tab over
  /// while focus is still on the sidebar item that selected it, and that
  /// request is as live as one made from a bare scope. What distinguishes a
  /// stale claim is that focus *moved* after the request was armed and now
  /// rests on a control off this screen. A bare scope — MainScreen's content
  /// scope before any child has focus — is "nowhere yet", not a destination.
  bool get _railClaimAbandoned {
    final node = FocusManager.instance.primaryFocus;
    if (identical(node, _railClaimFocusOrigin)) return false;
    final focusContext = node?.context;
    if (node == null || node is FocusScopeNode || focusContext == null) return false;
    return !identical(focusContext.findAncestorStateOfType<_DiscoverScreenState>(), this);
  }

  void _applyPendingTvBrowseRailFocus() {
    if (!_pendingTvBrowseRailFocus) return;
    if (_railClaimAbandoned) {
      _pendingTvBrowseRailFocus = false;
      return;
    }
    _focusTvBrowseRailWhenReady();
  }

  /// Handle vertical navigation between hubs
  /// Returns true if the navigation was handled
  bool _handleVerticalNavigation(int hubIndex, bool isUp) {
    final keys = _allHubKeys;
    return navigateVerticalHubRows(
      hubCount: keys.length,
      hubIndex: hubIndex,
      isUp: isUp,
      onTopBoundary: _focusTopBoundary,
      requestFocus: (targetIndex) {
        keys[targetIndex].currentState?.requestFocusFromMemory();
      },
    );
  }

  void _navigateToSidebar() {
    MainScreenFocusScope.focusSidebarOf(context);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _heroFocusNode = FocusNode(debugLabel: 'hero_section');
    _heroFocusNode.addListener(_onHeroFocusChanged);
    _discover = context.read<DiscoverProvider>();
    _seenLoadGeneration = _discover.loadGeneration;
    _discover.addListener(_onDiscoverChanged);
    _spotlight.addListener(_syncSpotlightTheme);
    _updateHubKeys();
    unawaited(_discover.ensureLoaded());
    _startAutoScroll();
    // Prepared data need not emit a new load event after this screen mounts.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onDiscoverChanged();
    });
  }

  /// Mirror provider changes into this state's UI concerns: rebuild, apply
  /// pending TV-rail focus, and keep the hero carousel index in sync — a
  /// background updates preserve the batch and index, clamping only when
  /// an item actually disappears from the available catalog.
  /// Everything the build reads from the provider (list identities — the
  /// provider replaces lists on change — plus the scalar flags). Notifies
  /// that leave this unchanged (e.g. a watch-state-driven Continue Watching
  /// refresh that found nothing new) skip the setState so the whole screen —
  /// TV rail included — is not rebuilt for nothing.
  (List<MediaItem>, List<MediaHub>, bool, bool, bool, String?) get _renderSignature =>
      (_onDeck, _hubs, _hasMoreContinueWatching, _isLoading, _areHubsLoading, _discover.errorMessage);

  (List<MediaItem>, List<MediaHub>, bool, bool, bool, String?)? _seenRenderSignature;

  void _onDiscoverChanged() {
    if (!mounted) return;
    final generation = _discover.loadGeneration;
    final isNewLoad = generation != _seenLoadGeneration;
    _seenLoadGeneration = generation;
    final loading = _isLoading || _areHubsLoading;
    final startingLoad = loading && !_heroLoadInProgress;
    final finishInitialPool = !loading && _heroLoadInProgress && _heroStartedEmpty && !_heroHasNavigated;
    _heroLoadInProgress = loading;
    if (startingLoad) {
      _heroStartedEmpty = _sourceHeroItems.isEmpty;
      _heroHasNavigated = false;
    }
    // Cold-start Continue Watching may arrive first. Once recommendations
    // finish, sample the complete pool unless the user has begun browsing.
    if (finishInitialPool) _heroSelection.reroll();
    final heroOutOfBounds = _heroIndex.value >= _heroItems.length;
    final resetHero = heroOutOfBounds || finishInitialPool;
    final signature = _renderSignature;
    final renderChanged = isNewLoad || heroOutOfBounds || signature != _seenRenderSignature;
    _seenRenderSignature = signature;

    if (renderChanged) {
      setState(() {
        if (resetHero) _heroIndex.value = 0;
        _updateHubKeys();
      });
    }
    _applyPendingTvBrowseRailFocus();
    if (PlatformDetector.isTV()) {
      _syncSpotlightTheme();
    } else {
      _syncHomeTheme(_heroItems.isEmpty ? null : _heroItems[_heroIndex.value.clamp(0, _heroItems.length - 1)]);
    }

    if (resetHero && _heroController.hasClients && _heroItems.isNotEmpty) {
      _heroController.jumpToPage(0);
    }
    // Focus hero when fresh content lands, but only if no modal route is on top
    if (isNewLoad &&
        !_heroHasNavigated &&
        !PlatformDetector.isTV() &&
        _heroItems.isNotEmpty &&
        (ModalRoute.of(context)?.isCurrent ?? false)) {
      _heroFocusNode.requestFocus();
    }

    // On initial load, focus content so the user doesn't start on the toolbar
    if (!_initialLoadComplete) {
      if (PlatformDetector.isTV() && (_onDeck.isNotEmpty || _hubs.isNotEmpty)) {
        _initialLoadComplete = true;
        _focusTvBrowseRailWhenReady();
      } else if (!PlatformDetector.isTV() && _heroItems.isNotEmpty) {
        _initialLoadComplete = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
          if (_heroFocusNode.canRequestFocus) {
            _heroFocusNode.requestFocus();
          }
        });
      }
    }
  }

  void _onHeroFocusChanged() {
    if (!PlatformDetector.isTV()) return;

    if (_heroFocusNode.hasFocus) {
      _heroFocusPausedAutoScroll = true;
      _autoScrollTimer?.cancel();
      _stopIndicatorProgress();
      return;
    }

    if (_heroFocusPausedAutoScroll) {
      _heroFocusPausedAutoScroll = false;
      if (_isTabVisible && !_isAutoScrollPaused) _startAutoScroll();
    }
  }

  /// Handle key events for the hero section.
  KeyEventResult _handleHeroKeyEvent(FocusNode node, KeyEvent event) {
    final backResult = handleBackKeyAction(event, _navigateToSidebar);
    if (backResult != KeyEventResult.ignored) return backResult;

    return dpadKeyHandler(
      onDown: () {
        final keys = _allHubKeys;
        if (keys.isNotEmpty) keys.first.currentState?.requestFocusFromMemory();
      },
      onUp: _focusTopActions,
      onLeft: () {
        if (_heroIndex.value > 0) {
          _heroController.previousPage(duration: tokens(context).slow, curve: Curves.easeInOut);
        } else {
          _navigateToSidebar();
        }
      },
      onRight: () {
        if (_heroIndex.value < _heroItems.length - 1) {
          _heroController.nextPage(duration: tokens(context).slow, curve: Curves.easeInOut);
        }
      },
      onSelect: () {
        final heroIndex = _heroIndex.value;
        if (_heroItems.isNotEmpty && heroIndex < _heroItems.length) {
          navigateToMediaItem(context, _heroItems[heroIndex]);
        }
      },
    )(node, event);
  }

  @override
  void dispose() {
    _discover.removeListener(_onDiscoverChanged);
    WidgetsBinding.instance.removeObserver(this);
    _autoScrollTimer?.cancel();
    _indicatorTimer?.cancel();
    _spotlight.dispose();
    _indicatorProgress.dispose();
    _heroIndex.dispose();
    _heroController.dispose();
    _scrollController.dispose();
    _heroFocusNode.removeListener(_onHeroFocusChanged);
    _heroFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Restart auto-scroll only if discover tab is visible
      if (_isTabVisible && !_isAutoScrollPaused) _startAutoScroll();
      // Stale hubs refetch on every resume — cheap timestamp check, and a
      // desktop window-focus gain after hours away should refresh too (#1646).
      final startedFullPass = _discover.refreshIfStale();
      // Refresh continue watching on mobile only
      // (on desktop, "resumed" fires on every window focus gain)
      if (!startedFullPass && (Platform.isIOS || Platform.isAndroid)) {
        unawaited(_discover.refreshContinueWatching());
      }
    } else if (state == AppLifecycleState.inactive || state == AppLifecycleState.hidden) {
      // Stop animations to prevent scroll state corruption while backgrounded
      _autoScrollTimer?.cancel();
      _stopIndicatorProgress();
    }
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    if (PlatformDetector.isTV()) return;
    if (_reduceMotion) return;
    if (_isAutoScrollPaused) return;

    _startIndicatorProgress();
    _autoScrollTimer = Timer.periodic(_heroAutoScrollDuration, (timer) {
      if (_heroItems.isEmpty || !_heroController.hasClients || _isAutoScrollPaused) {
        return;
      }

      // Validate current index is within bounds before calculating next page
      if (_heroIndex.value >= _heroItems.length) _heroIndex.value = 0;

      final nextPage = (_heroIndex.value + 1) % _heroItems.length;
      // onPageChanged restarts the timer and the progress fill.
      _heroController.animateToPage(nextPage, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    });
  }

  void _startIndicatorProgress() {
    if (!mounted) return;
    _indicatorTimer?.cancel();
    _indicatorProgress.value = 0.0;
    final totalSteps = _heroAutoScrollDuration.inMilliseconds ~/ _indicatorUpdateInterval.inMilliseconds;
    int step = 0;
    _indicatorTimer = Timer.periodic(_indicatorUpdateInterval, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      step++;
      _indicatorProgress.value = (step / totalSteps).clamp(0.0, 1.0);
      if (step >= totalSteps) {
        timer.cancel();
      }
    });
  }

  void _stopIndicatorProgress() {
    _indicatorTimer?.cancel();
  }

  void _resetAutoScrollTimer() {
    _autoScrollTimer?.cancel();
    _startAutoScroll();
  }

  void _pauseAutoScroll() {
    setState(() {
      _isAutoScrollPaused = true;
    });
    _autoScrollTimer?.cancel();
    _stopIndicatorProgress();
  }

  void _resumeAutoScroll() {
    setState(() {
      _isAutoScrollPaused = false;
    });
    _startAutoScroll();
  }

  @override
  void onTabHidden() {
    _isTabVisible = false;
    _pendingTvBrowseRailFocus = false;
    _autoScrollTimer?.cancel();
    _stopIndicatorProgress();
  }

  @override
  void onTabShown() {
    _isTabVisible = true;
    // Artwork that decoded while hidden was not applied to the theme.
    if (!PlatformDetector.isTV()) {
      _syncHomeTheme(_heroItems.isEmpty ? null : _heroItems[_heroIndex.value.clamp(0, _heroItems.length - 1)]);
    }
    _discover.refreshIfStale();
    if (!_isAutoScrollPaused) {
      _startAutoScroll();
    }
  }

  @override
  void focusActiveTabIfReady() {
    if (PlatformDetector.isTV()) {
      _focusTvBrowseRailWhenReady();
      return;
    }
    _focusTopBoundary();
  }

  @override
  void manualRefresh() => unawaited(_refreshFromToolbar());

  Future<void> _refreshFromToolbar() async {
    final outcome = await _discover.refreshNow();
    if (!mounted) return;
    if (outcome == DiscoverRefreshOutcome.refreshed || outcome == DiscoverRefreshOutcome.degraded) {
      setState(() {
        _heroSelection.reroll();
        _syncSourceLists();
        _heroIndex.value = 0;
      });
      if (_heroController.hasClients && _heroItems.isNotEmpty) _heroController.jumpToPage(0);
    }
    switch (outcome) {
      case DiscoverRefreshOutcome.failed:
        showErrorSnackBar(context, t.errors.unableToLoad(context: t.discover.title));
      case DiscoverRefreshOutcome.degraded:
        appLogger.w('Discover refresh completed with partial server failures');
      case DiscoverRefreshOutcome.cancelled:
      case DiscoverRefreshOutcome.refreshed:
        break;
    }
  }

  // Public method to refresh content (for normal navigation)
  @override
  void refresh() {
    // Returning to Home reuses its data and artwork. Watch-state events still
    // patch the provider directly; only stale data needs a navigation refresh.
    _discover.refreshIfStale();
  }

  // Public method to fully reload all content (for profile switches)
  @override
  void fullRefresh() {
    unawaited(_discover.load());
  }

  @override
  void primeRefresh() {
    unawaited(_discover.ensureLoaded());
  }

  /// Whether the loaded hubs span more than one connected server.
  bool _hubsSpanMultipleServers() {
    final serverIds = _hubs.where((hub) => hub.serverId != null).map((hub) => hub.serverId).toSet();
    return serverIds.length > 1;
  }

  Future<void> _handleLogout() async {
    final confirm = await showConfirmDialog(
      context,
      title: t.common.logout,
      message: t.messages.logoutConfirm,
      confirmText: t.common.logout,
      isDestructive: true,
    );

    if (confirm && mounted) {
      await logoutAllProfiles(context);
    }
  }

  void _handleSwitchProfile(BuildContext context) {
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute(builder: (context) => const ProfileSwitchScreen()));
  }

  void _handleOpenSettings(BuildContext context) {
    final mainScope = MainScreenFocusScope.of(context, listen: false);
    if (mainScope != null) {
      mainScope.openSettings?.call();
      return;
    }

    Navigator.push(context, buildSettingsRoute());
  }

  /// Build the [FocusableAction] wrapping the user menu.
  /// Pulls live state from [ActiveProfileProvider]; the menu reuses
  /// [_userMenuItems] for the menu contents so d-pad and tap paths
  /// stay in sync.
  FocusableAction _buildUserMenuAction(BuildContext context) {
    final activeProvider = context.watch<ActiveProfileProvider>();
    final active = activeProvider.active;
    final profiles = activeProvider.profiles;

    final servers = context.watch<MultiServerProvider>();
    final currentItem = _heroItems.isEmpty ? null : _heroItems[_heroIndex.value.clamp(0, _heroItems.length - 1)];
    final selectedId = _selectedHomeServerId ?? currentItem?.serverId ?? servers.onlineServerIds.firstOrNull;
    final client = selectedId == null ? null : servers.getClientForServer(ServerId(selectedId));
    final backend = client?.backend ?? currentItem?.backend;
    final label = _selectedHomeServerId == null && servers.onlineServerIds.length > 1
        ? t.libraries.allSources
        : client?.serverName ?? currentItem?.serverName ?? backend?.name ?? t.libraries.allSources;
    return FocusableAction(
      onPressed: _switchingProfile ? null : () => _userMenuKey.currentState?.showButtonMenu(focusFirstItem: true),
      child: AppMenuButton<String>(
        key: _userMenuKey,
        enabled: !_switchingProfile,
        tooltip: t.libraries.allSources,
        adaptiveSheet: true,
        anchorAlignment: AppMenuAnchorAlignment.end,
        onSelected: (value) => unawaited(_handleUserMenuAction(context, value)),
        entriesBuilder: (context) =>
            _userMenuItems(context, activeProfile: active, profiles: profiles, activeProvider: activeProvider),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0x8533363c),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: .12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (backend != null) ...[
                BackendBadge(backend: backend, size: 24, color: BackendBadge.brandColor(backend)),
                const SizedBox(width: 7),
              ],
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 5),
              const AppIcon(Symbols.expand_more_rounded, size: 16, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  List<AppMenuEntry<String>> _userMenuItems(
    BuildContext context, {
    required Profile? activeProfile,
    required List<Profile> profiles,
    required ActiveProfileProvider activeProvider,
  }) {
    final theme = _cinemaTheme;
    final switchable = profiles.where((p) => p.id != activeProfile?.id).toList();
    final servers = context.read<MultiServerProvider>();

    return [
      AppMenuItem<String>(
        value: 'source:',
        label: t.libraries.allSources,
        icon: Symbols.dns_rounded,
        selected: _selectedHomeServerId == null,
      ),
      for (final id in servers.onlineServerIds)
        if (servers.getClientForServer(ServerId(id)) case final client?)
          AppMenuItem<String>(
            value: 'source:$id',
            label: client.serverName ?? client.backend.name,
            leading: BackendBadge(backend: client.backend, size: 24),
            selected: _selectedHomeServerId == id,
          ),
      const AppMenuDivider(),
      for (final p in switchable)
        AppMenuItem<String>(
          value: 'profile:${p.id}',
          leading: ProfileAvatar(profile: p, size: 24, avatarUrl: activeProvider.avatarUrlFor(p.id)),
          label: p.displayName,
          trailing: p.isPinProtected
              ? AppIcon(Symbols.lock_rounded, fill: 1, size: 14, color: theme.colorScheme.onSurfaceVariant)
              : null,
        ),
      if (switchable.isNotEmpty) const AppMenuDivider(),
      AppMenuItem<String>(value: 'manage_profiles', icon: Symbols.group_rounded, label: t.profiles.sectionTitle),
      AppMenuItem<String>(value: 'refresh', icon: Symbols.refresh_rounded, label: t.common.refresh),
      AppMenuItem<String>(value: 'remote', icon: Symbols.phone_android_rounded, label: t.companionRemote.title),
      AppMenuItem<String>(value: 'settings', icon: Symbols.settings_rounded, label: t.common.settings),
      AppMenuItem<String>(value: 'logout', icon: Symbols.logout_rounded, label: t.common.logout),
    ];
  }

  Future<void> _handleUserMenuAction(BuildContext context, String value) async {
    if (_switchingProfile) return;
    if (value.startsWith('source:')) {
      setState(() {
        final id = value.substring('source:'.length);
        _selectedHomeServerId = id.isEmpty ? null : id;
        _heroHasNavigated = true;
        _heroIndex.value = 0;
        _updateHubKeys();
      });
      if (_heroController.hasClients && _heroItems.isNotEmpty) _heroController.jumpToPage(0);
      _syncHomeTheme(_heroItems.firstOrNull);
      _resetAutoScrollTimer();
      return;
    }
    if (value == 'refresh') {
      manualRefresh();
      return;
    }
    if (value == 'remote') {
      if (PlatformDetector.shouldActAsRemoteHost(context)) {
        unawaited(RemoteSessionDialog.show(context));
      } else {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const MobileRemoteScreen()));
      }
      return;
    }
    if (value == 'logout') {
      unawaited(_handleLogout());
      return;
    }
    if (value == 'manage_profiles') {
      _handleSwitchProfile(context);
      return;
    }
    if (value == 'settings') {
      _handleOpenSettings(context);
      return;
    }
    if (value.startsWith('profile:')) {
      final id = value.substring('profile:'.length);
      final active = context.read<ActiveProfileProvider>();
      final target = active.profiles.where((p) => p.id == id).firstOrNull;
      if (target == null) return;
      await _switchProfileFromMenu(target);
    }
  }

  Future<void> _switchProfileFromMenu(Profile profile) async {
    if (_switchingProfile) return;
    setState(() => _switchingProfile = true);
    try {
      await switchProfileFromUi(context, profile);
    } finally {
      if (mounted) {
        setState(() => _switchingProfile = false);
      }
    }
  }

  /// 40px dark glass circle matching the source pill. It sits over artwork in
  /// both appearances, so the foreground stays white.
  Widget _glassIconButton({required String tooltip, required IconData icon, required VoidCallback? onPressed}) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        backgroundColor: const Color(0x8533363c),
        side: BorderSide(color: Colors.white.withValues(alpha: .12)),
      ),
      icon: AppIcon(icon, size: 22, color: Colors.white),
    );
  }

  Widget _buildOverlaidAppBar() {
    final mainScope = MainScreenFocusScope.of(context, listen: false);
    if (mainScope?.hasTopNavigation == true) {
      return ToolbarScrim(
        overArtwork: true,
        child: Row(children: [_buildUserMenuAction(context).child!, const Spacer()]),
      );
    }
    if (!PlatformDetector.shouldUseSideNavigation(context)) {
      return ToolbarScrim(
        overArtwork: true,
        child: Row(
          children: [
            _buildUserMenuAction(context).child!,
            const Spacer(),
            _glassIconButton(
              tooltip: t.common.search,
              icon: Symbols.search_rounded,
              onPressed: () => mainScope?.selectTab?.call(NavigationTabId.search),
            ),
            const SizedBox(width: 8),
            _glassIconButton(
              tooltip: t.common.options,
              icon: Symbols.more_horiz_rounded,
              onPressed: mainScope?.openNavigation,
            ),
          ],
        ),
      );
    }
    final colorScheme = _cinemaTheme.colorScheme;
    final foregroundColor = colorScheme.onSurface;
    return ToolbarScrim(
      overArtwork: true,
      child: Row(
        children: [
          if (!PlatformDetector.isTV())
            Text(
              t.discover.title,
              style: _cinemaTheme.textTheme.titleLarge?.copyWith(color: foregroundColor, fontWeight: .bold),
            ),
          const Spacer(),
          // TV only: a fullscreen leanback app hides the system clock, while a
          // phone status bar and a desktop menu bar already show one.
          if (PlatformDetector.isTV()) ...[
            SystemClock(
              style: _cinemaTheme.textTheme.titleMedium?.copyWith(color: foregroundColor, fontWeight: .w500),
            ),
            const SizedBox(width: 12),
          ],
          Consumer2<WatchTogetherProvider, CompanionRemoteProvider>(
            builder: (context, watchTogether, companionRemote, _) {
              final isDesktop = PlatformDetector.shouldActAsRemoteHost(context);
              void openWatchTogether() =>
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const WatchTogetherScreen()));
              void openCompanionRemote() {
                if (isDesktop) {
                  RemoteSessionDialog.show(context);
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const MobileRemoteScreen()));
                }
              }

              return FocusableActionBar(
                key: _actionBarKey,
                onNavigateLeft: _navigateToSidebar,
                onNavigateDown: _focusContentFromAppBar,
                actions: [
                  FocusableAction(icon: Symbols.refresh_rounded, iconColor: foregroundColor, onPressed: manualRefresh),
                  // Watch Together
                  FocusableAction(
                    onPressed: openWatchTogether,
                    child: Stack(
                      children: [
                        IconButton(
                          icon: AppIcon(
                            Symbols.group_rounded,
                            fill: watchTogether.isInSession ? 1 : 0,
                            color: watchTogether.isInSession ? colorScheme.primary : foregroundColor,
                          ),
                          onPressed: openWatchTogether,
                          tooltip: t.watchTogether.title,
                        ),
                        if (watchTogether.isInSession && watchTogether.participantCount > 1)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: const BorderRadius.all(Radius.circular(8)),
                              ),
                              child: Text(
                                '${watchTogether.participantCount}',
                                style: TextStyle(color: colorScheme.onPrimary, fontSize: 10, fontWeight: .bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Companion Remote
                  FocusableAction(
                    onPressed: openCompanionRemote,
                    child: Stack(
                      children: [
                        IconButton(
                          icon: AppIcon(
                            Symbols.phone_android_rounded,
                            fill: companionRemote.isConnected ? 1 : 0,
                            color: companionRemote.isConnected ? colorScheme.primary : foregroundColor,
                          ),
                          onPressed: openCompanionRemote,
                          tooltip: t.companionRemote.title,
                        ),
                        if (companionRemote.isConnected)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.fromBorderSide(BorderSide(color: foregroundColor, width: 1)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Server Tasks — Plex-only (`/activities` API has no
                  // Jellyfin equivalent), hide the button entirely on
                  // Jellyfin-only profiles so the chrome doesn't show
                  // a permanently empty popover.
                  if (PlatformDetector.isDesktop(context) &&
                      context.select<MultiServerProvider, bool>((p) => p.hasOnlinePlexServers))
                    FocusableAction(
                      onPressed: () => _serverActivitiesButtonKey.currentState?.togglePanel(),
                      child: ServerActivitiesButton(key: _serverActivitiesButtonKey),
                    ),
                  // User menu — profiles + sign out
                  _buildUserMenuAction(context),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Theme.of(context).brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Theme(
        data: HomeTypography.apply(
          Theme.of(context),
          tv: PlatformDetector.isTV(),
          tablet: MonoPresentation.isTablet(context),
        ),
        child: Builder(
          builder: (context) => SettingsBuilder(
            prefs: const [
              SettingsService.showServerNameOnHubs,
              SettingsService.showHeroSection,
              SettingsService.hideSpoilers,
              SettingsService.libraryDensity,
              SettingsService.episodePosterMode,
            ],
            builder: (context) => _buildContent(context),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final svc = SettingsService.instance;
    final showHeroSection = svc.read(SettingsService.showHeroSection);
    // Only the true cold-start frame owns the whole page. On-deck is
    // published independently from hubs, so keeping the full skeleton alive
    // while hubs finish would cover an already-available hero.
    final isInitialLoading = _isLoading && _onDeck.isEmpty && _hubs.isEmpty;
    final showHubLoadingSkeleton = !isInitialLoading && _areHubsLoading && _hubs.isEmpty;

    if (PlatformDetector.isTV()) {
      return Theme(
        data: _cinemaTheme.copyWith(scaffoldBackgroundColor: HomeThemeScope.colorOf(context)),
        child: Builder(builder: (context) => _buildTvContent(context, isInitialLoading: isInitialLoading)),
      );
    }

    final showServerNameOnHubs = svc.read(SettingsService.showServerNameOnHubs);
    final hubsSpanMultipleServers = _hubsSpanMultipleServers();

    final bottomPadding = MediaQuery.paddingOf(context).bottom + 100;
    final continueWatchingHub = _onDeck.isEmpty ? null : _continueWatchingHub;
    return Theme(
      data: _cinemaTheme.copyWith(scaffoldBackgroundColor: HomeThemeScope.colorOf(context)),
      child: Material(
        color: HomeThemeScope.colorOf(context),
        child: Stack(
          children: [
            CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Hero Section (Continue Watching) - at top of screen
                Builder(
                  builder: (context) {
                    if (_heroItems.isNotEmpty && showHeroSection) {
                      return _buildHeroSection();
                    }
                    if (isInitialLoading) return const SliverToBoxAdapter(child: SizedBox.shrink());
                    // Add top padding when hero is not shown
                    return SliverToBoxAdapter(
                      child: SizedBox(height: kToolbarHeight + MediaQuery.paddingOf(context).top + 16),
                    );
                  },
                ),
                if (isInitialLoading)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: math.max(0, MediaQuery.sizeOf(context).height - MediaQuery.paddingOf(context).top - 8),
                      child: const Padding(
                        padding: EdgeInsets.only(bottom: 76),
                        child: DiscoverLoadingSkeleton(isTv: false),
                      ),
                    ),
                  ),
                if (_errorMessage != null) SliverErrorState(message: _errorMessage!, onRetry: _discover.load),
                if (!isInitialLoading && _errorMessage == null) ...[
                  if (continueWatchingHub != null)
                    SliverToBoxAdapter(
                      child: HubSection(
                        showWatchProgress: true,
                        key: _continueWatchingHubKey,
                        hub: continueWatchingHub,
                        focusMemory: _hubFocusMemory,
                        icon: hubIconFor(continueWatchingHub),
                        onRefresh: _discover.updateItem,
                        onRemoveFromContinueWatching: _discover.refreshContinueWatching,
                        isInContinueWatching: true,
                        episodePosterModeOverride: EpisodePosterMode.episodeThumbnail,
                        cardWidthOverride: MonoPresentation.isTablet(context)
                            ? 280
                            : math.min(224, MediaQuery.sizeOf(context).width * .62),
                        loadMoreItems: _discover.loadAllContinueWatching,
                        onVerticalNavigation: (isUp) => _handleVerticalNavigation(0, isUp),
                        onNavigateUp: _focusTopBoundary,
                        onNavigateToSidebar: _navigateToSidebar,
                      ),
                    ),
                  if (showHubLoadingSkeleton)
                    SliverToBoxAdapter(child: DiscoverHubLoadingSkeleton(rows: _onDeck.isEmpty ? 3 : 2)),

                  // Recommendation Hubs (Trending, Top in Genre, etc.)
                  for (int i = 0; i < _hubs.length; i++)
                    SliverToBoxAdapter(
                      child: HubSection(
                        showWatchProgress: false,
                        showRatingBadge: true,
                        key: i < _orderedHubKeys.length ? _orderedHubKeys[i] : null,
                        hub: _hubs[i],
                        cardWidthOverride:
                            MediaQuery.sizeOf(context).width < 600 &&
                                _hubs[i].items.every((item) => item.isMovie || item.isShow)
                            ? math.min(111, MediaQuery.sizeOf(context).width * .33)
                            : null,
                        focusMemory: _hubFocusMemory,
                        icon: hubIconFor(_hubs[i]),
                        showServerName: showServerNameOnHubs || hubsSpanMultipleServers,
                        onRefresh: _discover.updateItem,
                        // Hub index is i + 1 if continue watching exists, otherwise i
                        onVerticalNavigation: (isUp) => _handleVerticalNavigation(_onDeck.isNotEmpty ? i + 1 : i, isUp),
                        onNavigateUp: (i == 0 && _onDeck.isEmpty) ? _focusTopBoundary : null,
                        onNavigateToSidebar: _navigateToSidebar,
                      ),
                    ),

                  if (_onDeck.isEmpty && _hubs.isEmpty && !_areHubsLoading && !_isLoading)
                    SliverEmptyState(
                      message: t.discover.noContentAvailable,
                      subtitle: t.discover.addMediaToLibraries,
                      icon: Symbols.movie_rounded,
                    ),

                  SliverToBoxAdapter(child: SizedBox(height: 24 + bottomPadding)),
                ],
              ],
            ),
            // Overlaid app bar — excluded from default focus traversal so that
            // initial/tab-switch focus lands on content (hero/hubs), not the toolbar.
            // Toolbar buttons are still reachable via explicit UP from hero section.
            if (_heroItems.isEmpty || !showHeroSection || PlatformDetector.shouldUseSideNavigation(context))
              Positioned(top: 0, left: 0, right: 0, child: ExcludeFocusTraversal(child: _buildOverlaidAppBar())),
            if (_switchingProfile) const ProfileSwitchingOverlay(),
          ],
        ),
      ),
    );
  }

  // Cached so unrelated _buildTvContent rebuilds (loading flags, spotlight
  // geometry) hand Element.updateChild the identical widget instance and the
  // whole rail subtree is skipped. Rebuilt only when its actual inputs change.
  TvBrowseRail? _tvBrowseRailWidget;
  (List<MediaHub>, bool)? _tvBrowseRailWidgetKey;

  Widget _cachedTvBrowseRail(List<MediaHub> browseHubs, {required bool showServerName}) {
    final key = (browseHubs, showServerName);
    if (_tvBrowseRailWidget != null && key == _tvBrowseRailWidgetKey) return _tvBrowseRailWidget!;
    _tvBrowseRailWidgetKey = key;
    return _tvBrowseRailWidget = TvBrowseRail(
      showWatchProgressForHub: (hub) => hub.isContinueWatchingHub,
      showRatingBadges: true,
      key: _tvBrowseRailKey,
      hubs: browseHubs,
      initialHubId: 'continue_watching',
      focusMemory: _hubFocusMemory,
      showServerName: showServerName,
      iconForHub: (hub, _) => hubIconFor(hub),
      onFocusedItemChanged: _setSpotlightItem,
      onRefresh: _discover.updateItem,
      onRemoveFromContinueWatching: _discover.refreshContinueWatching,
      isContinueWatchingHub: (hub) => hub.isContinueWatchingHub,
      usesContinueWatchingAction: (hub) => hub.usesContinueWatchingAction,
      // Every other hub pages from its server in View All, as on phones; handing
      // it the preview items only showed that preview again.
      loadMoreItems: (hub) => hub.id == 'continue_watching' ? _discover.loadAllContinueWatching : null,
      onNavigateUp: _focusTopActions,
      onNavigateToSidebar: _navigateToSidebar,
      tallPosterScale: TvBrowseRailLayout.compactTallPosterScale,
    );
  }

  Widget _buildTvContent(BuildContext context, {required bool isInitialLoading}) {
    final svc = SettingsService.instance;
    final hideSpoilers = svc.read(SettingsService.hideSpoilers);
    final showServerNameOnHubs = svc.read(SettingsService.showServerNameOnHubs);
    final hubsSpanMultipleServers = _hubsSpanMultipleServers();
    final browseHubs = _tvBrowseHubs;

    return TvSpotlightScaffold(
      hubs: browseHubs,
      spotlightListenable: _spotlight,
      resolveSpotlight: () => _spotlight.resolve(browseHubs),
      resolveClient: _getMediaClientForItem,
      hideSpoilers: hideSpoilers,
      foreground: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          if (isInitialLoading) const DiscoverLoadingSkeleton(isTv: true),
          if (!isInitialLoading && _areHubsLoading && _hubs.isEmpty && browseHubs.isEmpty)
            const Positioned.fill(child: TvDiscoverHubLoadingSkeleton()),
          if (_errorMessage != null)
            ErrorStateWidget(
              message: _errorMessage!,
              icon: Symbols.error_outline_rounded,
              onRetry: _discover.load,
              actionAutofocus: true,
              actionUseBackgroundFocus: true,
            ),
          if (!_isLoading && _errorMessage == null && browseHubs.isEmpty && !_areHubsLoading)
            EmptyStateWidget(
              message: t.discover.noContentAvailable,
              subtitle: t.discover.addMediaToLibraries,
              icon: Symbols.movie_rounded,
            ),
          if (browseHubs.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _cachedTvBrowseRail(browseHubs, showServerName: showServerNameOnHubs || hubsSpanMultipleServers),
            ),
          TvToolbarOverlay(child: _buildOverlaidAppBar()),
          if (_switchingProfile) const ProfileSwitchingOverlay(),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    final useSideNav = PlatformDetector.shouldUseSideNavigation(context);
    final isTv = PlatformDetector.isTV();
    final viewportHeight = MediaQuery.sizeOf(context).height;

    final preferredHeroHeight = isTv
        ? viewportHeight * 0.82
        : useSideNav
        ? viewportHeight * 0.75
        : MonoPresentation.touchHeroHeight(context);
    // Keep the artwork/page boundary on a physical pixel; a fractional clip
    // otherwise leaves a thin dark line even when both surfaces match.
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final heroHeight = (preferredHeroHeight * pixelRatio).ceilToDouble() / pixelRatio;
    return SliverToBoxAdapter(
      child: Focus(
        focusNode: _heroFocusNode,
        onKeyEvent: _handleHeroKeyEvent,
        child: SizedBox(
          height: heroHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              NotificationListener<ScrollStartNotification>(
                onNotification: (notification) {
                  if (notification.dragDetails != null) _heroHasNavigated = true;
                  return false;
                },
                child: PageView.builder(
                  controller: _heroController,
                  itemCount: _heroItems.length,
                  onPageChanged: (index) {
                    if (index >= 0 && index < _heroItems.length) {
                      if (index != _heroIndex.value) _heroHasNavigated = true;
                      _heroIndex.value = index;
                      _syncHomeTheme(_heroItems[index]);
                      _resetAutoScrollTimer();
                    }
                  },
                  itemBuilder: (context, index) {
                    return _buildHeroItem(_heroItems[index], heroHeight);
                  },
                ),
              ),
              // Page indicators with animated progress.
              // Hidden on TV only (issue #600: pointer-only control unreachable
              // via d-pad) — never gated on transient input mode, which back-key
              // events, BT keyboards, and gamepads can flip on phones/desktop.
              if (!isTv)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  // The visible pause toggle was dropped to match the prototype;
                  // assistive technologies keep it as a custom action.
                  child: Semantics(
                    customSemanticsActions: {
                      CustomSemanticsAction(
                        label: _isAutoScrollPaused ? t.accessibility.autoScrollPlay : t.accessibility.autoScrollPause,
                      ): () {
                        if (_isAutoScrollPaused) {
                          _resumeAutoScroll();
                        } else {
                          _pauseAutoScroll();
                        }
                      },
                    },
                    child: Row(
                      mainAxisAlignment: .center,
                      children: [
                        ValueListenableBuilder<int>(
                          valueListenable: _heroIndex,
                          builder: (context, heroIndex, _) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(_heroItems.length, (index) {
                                final isActive = heroIndex == index;
                                // One widget type for every state so the selected pill
                                // animates its width instead of swapping in a new box.
                                final dotColor = _cinemaTheme.colorScheme.onSurface;
                                final dot = AnimatedContainer(
                                  key: ValueKey(index),
                                  duration: _reduceMotion ? Duration.zero : tokens(context).slow,
                                  curve: Curves.easeOutCubic,
                                  margin: const EdgeInsets.symmetric(horizontal: 3.5),
                                  width: isActive ? 18 : 6,
                                  height: 6,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    color: dotColor.withValues(alpha: isActive ? .38 : .24),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: isActive
                                      ? ValueListenableBuilder<double>(
                                          valueListenable: _indicatorProgress,
                                          // Ticks arrive every 200ms; tween between them so the
                                          // fill moves smoothly, but snap back on reset.
                                          builder: (context, progress, _) => AnimatedFractionallySizedBox(
                                            duration: progress == 0 ? Duration.zero : _indicatorUpdateInterval,
                                            alignment: Alignment.centerLeft,
                                            widthFactor: _isAutoScrollPaused || _reduceMotion ? 1 : progress,
                                            child: ColoredBox(color: dotColor),
                                          ),
                                        )
                                      : null,
                                );
                                return Semantics(
                                  key: ValueKey('home-hero-dot-$index'),
                                  button: true,
                                  selected: isActive,
                                  label: _heroItems[index].displayTitle,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      _heroHasNavigated = true;
                                      if (_reduceMotion) {
                                        _heroController.jumpToPage(index);
                                      } else {
                                        _heroController.animateToPage(
                                          index,
                                          duration: tokens(context).slow,
                                          curve: Curves.easeInOut,
                                        );
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
                                      child: dot,
                                    ),
                                  ),
                                );
                              }),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              if (!useSideNav)
                Positioned(top: 0, left: 0, right: 0, child: ExcludeFocusTraversal(child: _buildOverlaidAppBar())),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroItem(MediaItem heroItem, double heroHeight) {
    final heroClient = _getMediaClientForItem(heroItem);
    final isEpisode = heroItem.isEpisode;
    final showName = heroItem.grandparentTitle ?? heroItem.displayTitle;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final heroAspectRatio = screenWidth / heroHeight;
    final heroArtPaths = heroItem.heroArtCandidates(containerAspectRatio: heroAspectRatio);
    final isLargeScreen = ScreenBreakpoints.isWideTabletOrLarger(screenWidth);
    final isTv = PlatformDetector.isTV();
    final alignLeft = isTv || isLargeScreen;
    if (!alignLeft || MonoPresentation.isTablet(context)) {
      return FusionHomeHero(
        item: heroItem,
        client: heroClient,
        compact: heroHeight < 450,
        onPlay: () => navigateToMediaItem(context, heroItem),
        backdrop: CyclingMediaBackdrop(
          mediaKey: heroItem.globalKey,
          imagePaths: heroArtPaths.take(1).toList(),
          fallbackImagePaths: heroArtPaths,
          client: heroClient,
          active: false,
          width: screenWidth,
          height: heroHeight,
          alignment: const Alignment(0, -.76),
          fallbackColor: HomeThemeScope.colorOf(context),
          onImageReady: (image) => _onHeroImageReady(heroItem, image),
        ),
      );
    }
    final theme = _cinemaTheme;
    final colorScheme = theme.colorScheme;
    // A landscape phone hands the hero the whole ~400dp viewport; the usual
    // logo and bottom offset would push the content up into the top bar.
    final compact = !isTv && heroHeight < 450;
    final heroLogoWidth = isTv ? TvLayoutConstants.heroLogoWidth : 400.0;
    final heroLogoHeight = isTv
        ? TvLayoutConstants.heroLogoHeight
        : compact
        ? 80.0
        : 120.0;
    final heroTitleStyle = (theme.extension<HomeTypography>()?.heroTitle ?? theme.textTheme.displaySmall)?.copyWith(
      color: colorScheme.onSurface,
      shadows: [Shadow(color: colorScheme.surface.withValues(alpha: 0.8), blurRadius: 8)],
    );

    final hideSpoilers = SettingsService.instance.read(SettingsService.hideSpoilers);
    final shouldHideSpoiler = hideSpoilers && heroItem.shouldHideSpoiler;

    final heroLabel = isEpisode ? "${heroItem.grandparentTitle}, ${heroItem.title}" : heroItem.title;

    return Semantics(
      label: heroLabel,
      button: true,
      hint: t.accessibility.tapToPlay,
      child: ClickableCursor(
        child: GestureDetector(
          onTap: () {
            appLogger.d('Activating hero item: ${heroItem.title}');
            navigateToMediaItem(context, heroItem, playDirectly: true);
          },
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              // Background Image with VidHub ambient glow and glass
              if (heroArtPaths.isNotEmpty)
                ClipRect(
                  child: AnimatedBuilder(
                    animation: _scrollController,
                    builder: (context, child) {
                      final scrollOffset = _scrollController.hasClients ? _scrollController.offset : 0.0;
                      return Transform.translate(offset: Offset(0, scrollOffset * 0.3), child: child);
                    },
                    child: VidHubAmbientBackdrop(
                      preserveArtwork: true,
                      blurSigma: 0,
                      glowIntensity: isTv ? 0.24 : 0.28,
                      accentColor: HomeThemeScope.colorOf(context),
                      backgroundColor: HomeThemeScope.colorOf(context),
                      animateColor: false,
                      backdropChild: CyclingMediaBackdrop(
                        mediaKey: heroItem.globalKey,
                        imagePaths: heroArtPaths.take(1).toList(),
                        fallbackImagePaths: heroArtPaths,
                        client: heroClient,
                        active: false,
                        width: screenWidth,
                        height: heroHeight,
                        fallbackColor: _cinemaTheme.colorScheme.surfaceContainerHighest,
                        onImageReady: (image) => _onHeroImageReady(heroItem, image),
                      ),
                    ),
                  ),
                )
              else
                ColoredBox(color: colorScheme.surfaceContainerHighest),
              if (heroArtPaths.isEmpty)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        theme.scaffoldBackgroundColor.withValues(alpha: .4),
                        theme.scaffoldBackgroundColor.withValues(alpha: .85),
                        theme.scaffoldBackgroundColor,
                      ],
                      stops: const [0, .45, .72, .90, 1],
                    ),
                  ),
                ),

              // Content with responsive alignment
              Positioned(
                bottom: isTv
                    ? 88
                    : compact
                    ? 24
                    : isLargeScreen
                    ? 80
                    : 50,
                left: 0,
                right: isTv
                    ? screenWidth * 0.36
                    : isLargeScreen
                    ? 200
                    : 0,
                // Horizontal-only SafeArea: the PageView artwork behind stays
                // full-bleed; the foreground text/buttons clear the landscape
                // notch. Vertical placement is handled by `bottom` above.
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: Padding(
                    padding: .symmetric(
                      horizontal: isTv
                          ? TvLayoutConstants.horizontalInset
                          : isLargeScreen
                          ? 40
                          : 24,
                    ),
                    child: Align(
                      alignment: alignLeft ? Alignment.centerLeft : Alignment.center,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isTv ? TvLayoutConstants.heroContentMaxWidth : double.infinity,
                        ),
                        child: Column(
                          crossAxisAlignment: alignLeft ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                          mainAxisSize: .min,
                          children: [
                            // Show logo, falling back to the name/title. The
                            // logo keeps its slot; the title gets a wider one.
                            LayoutBuilder(
                              builder: (context, constraints) => ClearLogoImage(
                                client: heroClient,
                                logoPath: heroItem.clearLogoPath,
                                width: math.min(heroLogoWidth, constraints.maxWidth),
                                height: heroLogoHeight,
                                fallbackWidth: ClearLogoImage.fallbackWidthFor(
                                  logoWidth: heroLogoWidth,
                                  available: constraints.maxWidth,
                                ),
                                alignment: alignLeft ? Alignment.bottomLeft : Alignment.bottomCenter,
                                // The hero scrim washes artwork toward the scaffold
                                // background; light themes recolor light-toned logos.
                                logoToneTarget: logoToneTargetFor(
                                  surface: theme.scaffoldBackgroundColor,
                                  foreground: colorScheme.onSurface,
                                ),
                                fallbackBuilder: (context) => FittingTitleText(
                                  showName,
                                  style: heroTitleStyle,
                                  textAlign: alignLeft ? TextAlign.left : TextAlign.center,
                                  alignment: alignLeft ? Alignment.centerLeft : Alignment.center,
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),
                            HeroMetadataBadges(
                              item: heroItem,
                              foreground: colorScheme.onSurface,
                              alignment: alignLeft ? WrapAlignment.start : WrapAlignment.center,
                              fontSize: isTv ? 16 : 12,
                            ),

                            if (!alignLeft) ...[const SizedBox(height: 20), _buildSmartPlayButton(heroItem)],

                            if (heroItem.summary != null && !shouldHideSpoiler) ...[
                              const SizedBox(height: 12),
                              RichText(
                                maxLines: isTv ? 3 : 2,
                                overflow: .ellipsis,
                                textAlign: alignLeft ? TextAlign.left : TextAlign.center,
                                text: TextSpan(
                                  style: TextStyle(
                                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                                    fontSize: isTv ? 18 : 14,
                                    height: isTv ? 1.45 : 1.4,
                                  ),
                                  children: [
                                    if (isEpisode && heroItem.parentIndex != null && heroItem.index != null)
                                      TextSpan(
                                        text: 'S${heroItem.parentIndex}, E${heroItem.index}: ',
                                        style: TextStyle(fontWeight: .bold, color: colorScheme.onSurface),
                                      ),
                                    TextSpan(
                                      text: heroItem.summary?.isNotEmpty == true
                                          ? heroItem.summary!
                                          : t.messages.noDescriptionAvailable,
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (shouldHideSpoiler &&
                                isEpisode &&
                                heroItem.parentIndex != null &&
                                heroItem.index != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                'S${heroItem.parentIndex}, E${heroItem.index}: ${heroItem.title}',
                                maxLines: 2,
                                overflow: .ellipsis,
                                textAlign: alignLeft ? TextAlign.left : TextAlign.center,
                                style: TextStyle(
                                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                                  fontSize: isTv ? 18 : 14,
                                  height: isTv ? 1.45 : 1.4,
                                ),
                              ),
                            ],

                            if (alignLeft) ...[SizedBox(height: isTv ? 28 : 20), _buildSmartPlayButton(heroItem)],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmartPlayButton(MediaItem rawHeroItem) {
    return Builder(
      builder: (context) {
        // The on-deck snapshot refetches shortly after a watch event; the store
        // patch bridges the gap so "minutes left" never lags.
        final heroItem = context.withFreshWatchState(rawHeroItem);
        final hasProgress = heroItem.hasActiveProgress;
        final isTv = PlatformDetector.isTV();

        final minutesLeft = hasProgress ? ((heroItem.durationMs! - heroItem.viewOffsetMs!) / 60_000).round() : 0;

        final progress = hasProgress ? heroItem.viewOffsetMs! / heroItem.durationMs! : 0.0;

        return ListenableBuilder(
          listenable: _heroFocusNode,
          builder: (context, _) {
            final showFocus = isTv && _heroFocusNode.hasFocus && InputModeTracker.isKeyboardMode(context);
            const backgroundColor = Colors.white;
            const foregroundColor = Colors.black;
            return InkWell(
              onTap: () {
                appLogger.d('Playing: ${heroItem.title}');
                navigateToVideoPlayer(context, metadata: heroItem);
              },
              borderRadius: BorderRadius.all(Radius.circular(isTv ? 32 : 24)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutCubic,
                padding: .symmetric(horizontal: isTv ? 34 : 24, vertical: isTv ? 16 : 12),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.all(Radius.circular(isTv ? 32 : 24)),
                  boxShadow: showFocus
                      ? [BoxShadow(color: Colors.white.withValues(alpha: 0.35), blurRadius: 28, spreadRadius: 4)]
                      : null,
                ),
                child: Row(
                  mainAxisSize: .min,
                  children: [
                    AppIcon(Symbols.play_arrow_rounded, fill: 1, size: isTv ? 28 : 20, color: foregroundColor),
                    SizedBox(width: isTv ? 12 : 8),
                    if (hasProgress) ...[
                      // Progress bar
                      Container(
                        width: isTv ? 56 : 40,
                        height: isTv ? 8 : 6,
                        decoration: BoxDecoration(
                          color: foregroundColor.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.all(Radius.circular(isTv ? 4 : 3)),
                        ),
                        child: FractionallySizedBox(
                          alignment: .centerLeft,
                          widthFactor: progress,
                          child: Container(
                            decoration: BoxDecoration(
                              color: foregroundColor,
                              borderRadius: BorderRadius.all(Radius.circular(isTv ? 3 : 2)),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: isTv ? 12 : 8),
                      Text(
                        t.discover.minutesLeft(minutes: minutesLeft),
                        style: TextStyle(
                          color: foregroundColor,
                          fontSize: isTv ? 18 : 14,
                          fontWeight: isTv ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                    ] else
                      Text(
                        t.common.play,
                        style: TextStyle(
                          color: foregroundColor,
                          fontSize: isTv ? 18 : 14,
                          fontWeight: isTv ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
