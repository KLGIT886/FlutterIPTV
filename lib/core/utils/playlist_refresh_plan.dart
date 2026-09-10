/// 播放列表增量刷新计划。
///
/// 刷新播放列表时，如果沿用「先 DELETE 全部频道、再 INSERT 新频道」的做法，
/// 数据库的外键 `ON DELETE CASCADE` 会把该播放列表下的收藏与观看记录一并删除
/// （`channels.id` 变化后，任何「保存—恢复」流程都救不回来）。
///
/// 因此刷新改为增量 upsert：按身份键复用既有 `channels.id`，
/// 只有真正下线的频道才删除——此时级联清理其收藏/观看记录是符合预期的。
library;

/// 频道身份：名称 + 主 URL。
///
/// 分组名不参与，因为 M3U 源经常调整分组，把分组计入会导致「改名」被误判成
/// 「下线 + 新增」，从而丢失收藏与观看历史。
String channelIdentityKey(String name, String url) => '$name\u0000$url';

/// 一条待写入的频道（只需要身份信息）
typedef IncomingChannel = ({String name, String url});

/// 一条数据库中已存在的频道
typedef ExistingChannel = ({int id, String name, String url});

class PlaylistRefreshPlan {
  /// 与传入的 incoming 列表等长：
  /// 每个位置上是该频道应复用的既有 id，`null` 表示需要新增。
  final List<int?> reusedIds;

  /// 本次未再出现、需要删除的既有频道 id（频道已下线）。
  final List<int> staleIds;

  const PlaylistRefreshPlan({
    required this.reusedIds,
    required this.staleIds,
  });

  /// 复用的频道数量
  int get reusedCount => reusedIds.where((id) => id != null).length;

  /// 新增的频道数量
  int get insertedCount => reusedIds.length - reusedCount;
}

/// 计算增量刷新计划。
///
/// 同一身份键可能存在多条既有记录（例如同一频道分属不同分组），
/// 因此用游标依次消费：新列表里第 n 个同键频道复用第 n 个既有 id。
/// 这样既能应对条数变化（1 条变 2 条时第二个走新增），
/// 也能保证重复的 (name, url) 不会互相顶掉。
PlaylistRefreshPlan buildPlaylistRefreshPlan({
  required List<IncomingChannel> incoming,
  required List<ExistingChannel> existing,
}) {
  final existingIdsByKey = <String, List<int>>{};
  for (final item in existing) {
    final key = channelIdentityKey(item.name, item.url);
    existingIdsByKey.putIfAbsent(key, () => <int>[]).add(item.id);
  }

  final cursorByKey = <String, int>{};
  final reusedIds = List<int?>.filled(incoming.length, null);

  for (int i = 0; i < incoming.length; i++) {
    final key = channelIdentityKey(incoming[i].name, incoming[i].url);
    final candidates = existingIdsByKey[key];
    if (candidates == null) continue;

    final cursor = cursorByKey[key] ?? 0;
    if (cursor < candidates.length) {
      reusedIds[i] = candidates[cursor];
      cursorByKey[key] = cursor + 1;
    }
  }

  final staleIds = <int>[];
  for (final entry in existingIdsByKey.entries) {
    final cursor = cursorByKey[entry.key] ?? 0;
    if (cursor < entry.value.length) {
      staleIds.addAll(entry.value.sublist(cursor));
    }
  }

  return PlaylistRefreshPlan(reusedIds: reusedIds, staleIds: staleIds);
}
