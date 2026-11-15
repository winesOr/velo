> 历史研究摘要，来自本地资料快照 `c350c4a`（2026-11-14 整理）。原始证据未公开；文内观察、推断和未验证边界按原文保留，不能当作本次复测结果。公开副本仅脱敏路径并处理未公开证据链接。

# Velo 评分字段与请求对照（2026-11-13）

范围：当前工作树代码的局部静态检查；不是 VidHub 实现证据，也不是网络实测。未修改产品代码，未操作账号或设备。下列路径均相对仓库根目录。

## 三层必须分开

1. **服务器返回字段**：客户端向自己的 Plex / Jellyfin / Emby 服务器请求媒体条目，评分就在条目 JSON 中。客户端得到带品牌的评分，不等于客户端直接访问该品牌 API。
2. **服务器上游提供商**：服务器可能从元数据提供商或 NFO 得到分数。返回数值、ProviderIds 或海报品牌本身不足以完整证明上游；要核对服务器配置、provider 标识或其服务端取数记录。
3. **客户端独立聚合**：必须找到客户端到独立服务的调用以及响应字段到 UI 的映射。Velo 的外部目录源确有此类独立调用，但不能据此推定 VidHub 相同，也不能把目录详情调用等同于媒体库首屏的必经调用。

## 字段与实现

| 场景 | 实际字段 → 模型 | 代码位置与限制 |
|---|---|---|
| Jellyfin/Emby 条目基础分数 | `CommunityRating` → `MediaItem.rating` | `lib/services/jellyfin_mappers.dart:275` |
| Jellyfin/Emby 多评分展示 | `CommunityRating`（0–10）→ `MediaRatingSource(source: 'audience')` | `_ratingSources(Map<String, dynamic> item, MediaKind kind)`，`lib/services/jellyfin_mappers.dart:428`；照片无评分，非有限值/超范围值拒绝；此字段不证明 TMDB 或 IMDb 来源 |
| Jellyfin/Emby 评论家分数 | `CriticRating`（0–100）÷10 → `rottenTomatoesCritic` | 同上；这是 Velo 当前映射约定，不是 VidHub 已证实行为 |
| Plex 标量 | `rating`/`ratingImage`、`audienceRating`/`audienceRatingImage` → 有来源评分 | `plexRatingSources({...})`，`lib/services/plex_mappers.dart:970`；`imdb://`→IMDb，`themoviedb://`/`tmdb://`→TMDB，`rottentomatoes://`结合 type 分 critic/audience；未知来源保留通用标签 |
| Plex 数组 | JSON `Rating` → `List<PlexRatingDto>`，条目 `image`/`type`/`value` | `lib/services/plex_mappers.dart:627` 与 `:298`；数组加入标量评分并按 source+value 去重；并非字段名 `Ratings` |
| Plex 票数与个人评分 | `imdbRatingCount` 仅挂到 IMDb；`userRating` 为独立个人评分 | `lib/services/plex_mappers.dart:630`、`:1113`、`:1123`；不要混同公共评分 |
| 外部 ID | Jellyfin `ProviderIds`，Plex GUID | `fetchExternalIds(String itemId)`，`lib/services/jellyfin_client/parts/playback.dart:1112`、`lib/services/plex_client.dart:4708`；标识用于关联作品，不等于取得评分 |
| Simkl 目录 | `SimklRatings.simkl/imdb/mal` → 三个来源及 votes | `_ratingsFor(SimklRatings? ratings)`，`lib/services/catalog/simkl_catalog_source.dart:216`；0–10过滤；这是 Simkl 返回的多来源数据，不是三次分别直连各评分网站 |
| AniList 目录 | `anime.meanRating` → `anilist`；scalar `anime.rating` 单独存在 | `lib/services/catalog/anilist_catalog_source.dart:142`、`:162`、`:222`；原始模型含 `averageScore` 和 `meanScore`，见 `lib/models/anilist/anilist_media.dart:142`、`:205` |

## 真实请求入口与额外请求

- Jellyfin `Future<MediaItem?> fetchItem(String id)`（`lib/services/jellyfin_client/parts/browse.dart:772`）按 id 合并进行中的请求；`_fetchItemOnce(String id)`（`:811`）执行 `GET <local-path>`，映射完整条目并缓存。评分随这份条目进入 mapper；本次已读调用段没有“另向 IMDb/TMDB 请求评分”的操作。
- `Future<({MediaItem? item, MediaItem? onDeckEpisode})> fetchItemWithOnDeck(String id, {void Function(MediaItem item)? onItemReady})`（同文件`:737`）先回调 item，再补媒体库归属；剧集再调用 `/Shows/NextUp`。不要把 NextUp 或归属请求记成评分请求。
- `Future<MediaItem?> fetchItemFreshCacheFirst(String id)`（同文件`:797`）可复用新鲜的完整详情缓存，否则走 fetchItem；不能从此断言所有首页条目都命中该路径。
- Jellyfin 的 `fetchExternalIds` 本身调用 `fetchItem`；同时进行的同 id 请求可被上述 single-flight 合并。Plex 的同名函数另请求 `GET /library/metadata/{itemId}?includeGuids=1`（`lib/services/plex_client.dart:4711`），这次请求用于身份关联。
- Plex `Future<({PlexMetadataDto? metadata, PlexMetadataDto? onDeckEpisode})> _getMetadataWithImages(String ratingKey, {bool includeOnDeck = false, bool Function(Object error)? shouldFallback})`（`lib/services/plex_client.dart:1245`）：`GET /library/metadata/{ratingKey}`，参数 includeChapters=1、includeMarkers=1、checkFiles=1、includeStreams=1、按需 includeOnDeck=1；缓存键为不含 query 的基础 endpoint。该代码块未指定独立评分供应商 URL。
- 详情页 `_scheduleTargetProbe` / `_probeTarget`（`lib/screens/media_detail/playback_tracks_status.dart:46`、`:65`）350 ms 防抖后取得目标条目详情；`:77` 调 `client.fetchItem(target.id)`，`:85` 记录 `item.ratings`，`:165` `_recordProbedRatings` 更新剧集评分。这是已有详情探测附带取得评分，不是已证明的专用第三方评分请求。
- Simkl 目录 `Future<CatalogDetail> fetchDetail(CatalogItem item, {int castLimit = 20, int relatedLimit = 20})`（`lib/services/catalog/simkl_catalog_source.dart:553`）调用 `getDetail(type, simklId)`；`lib/services/trackers/simkl/simkl_client.dart:189` 实现 `GET /{urlType.detailPath}/{simklId}`。目录返回体可携带多个评分来源。
- AniList 目录同签名 `fetchDetail`（`lib/services/catalog/anilist_catalog_source.dart:181`）调用 `_client.getAnimeDetail(anilistId, castLimit, relatedLimit, includeCharacters)`，客户端入口 `lib/services/trackers/anilist/anilist_client.dart:531`。这里只确认调用与映射；未抓取其运行时网络，也不将其作为 VidHub 的请求。

## 显示层不是取数层

`preferredMediaRatingsFor(MediaItem item, {MediaItem? fallbackItem, int? limit})`（`lib/widgets/media_rating_badge.dart:30`）读取来源顺序和隐藏来源设置后筛选已有数据；`mediaCardRatingFor`（`:33`）取海报一个评分。`_ratingsFor`（`:46`）优先已有 attributed ratings，只有缺失时才用无来源 scalar rating。`lib/utils/rating_display_policy.dart:19`、`:21` 声明海报上限1、详情上限4；这解释 Velo 展示规则，不证明请求次数。

## 截图与 VidHub 待验证项

- 原电影截图黄色星号7.5、紫色圆形标记8.5；剧集截图黄色星号8.0、紫色标记9.4。只能确认有两个评分显示位置。
- 紫色来源尚未确认；不能直接写豆瓣、IMDb、TMDB、服务器评分或 VidHub 聚合分。
- 核验最小闭环：同一作品 ID → 捕获服务器详情响应字段（仅脱敏必要字段）→ 若出现独立域名再核对其响应 → 关联 UI 每个分数与更新时刻。若服务器 JSON 已含两个对应值，只能支持“可由服务器提供”，仍需调用/绑定证据确认 VidHub 实际使用。
- 本文件无需外部公开文档，因为结论局限于当前代码行为；没有用 GitHub README 或历史笔记替代实际实现证据。评分之外的启动优化由独立分析任务负责。
