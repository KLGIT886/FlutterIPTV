import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_iptv/core/utils/playlist_refresh_plan.dart';

/// 验证播放列表增量刷新的 upsert 计划。
///
/// 刷新必须复用既有 `channels.id`，否则外键 ON DELETE CASCADE 会连带清空
/// 收藏与观看记录（历史上正是因此每次刷新都丢光观看历史）。
void main() {
  IncomingChannel inc(String name, String url) => (name: name, url: url);
  ExistingChannel ex(int id, String name, String url) =>
      (id: id, name: name, url: url);

  test('同名同 URL 的频道复用原 id', () {
    final plan = buildPlaylistRefreshPlan(
      incoming: [inc('CCTV-1', 'http://a/1')],
      existing: [ex(7, 'CCTV-1', 'http://a/1')],
    );

    expect(plan.reusedIds, [7]);
    expect(plan.staleIds, isEmpty);
    expect(plan.reusedCount, 1);
    expect(plan.insertedCount, 0);
  });

  test('URL 变化的频道视为新频道，旧的进入下线列表', () {
    final plan = buildPlaylistRefreshPlan(
      incoming: [inc('CCTV-1', 'http://a/2')],
      existing: [ex(7, 'CCTV-1', 'http://a/1')],
    );

    expect(plan.reusedIds, [null], reason: 'URL 变化不应复用旧 id');
    expect(plan.staleIds, [7]);
  });

  test('分组改名不影响身份判定（分组不参与身份键）', () {
    // 分组由调用方写入 group_name，plan 只比较 name + url，
    // 因此源站调整分组不会导致收藏/观看历史丢失。
    final plan = buildPlaylistRefreshPlan(
      incoming: [inc('CCTV-1', 'http://a/1')],
      existing: [ex(7, 'CCTV-1', 'http://a/1')],
    );

    expect(plan.reusedIds, [7]);
  });

  test('同一 (name, url) 多条时按游标依次消费', () {
    final plan = buildPlaylistRefreshPlan(
      incoming: [inc('CCTV-1', 'http://a/1'), inc('CCTV-1', 'http://a/1')],
      existing: [ex(7, 'CCTV-1', 'http://a/1'), ex(8, 'CCTV-1', 'http://a/1')],
    );

    expect(plan.reusedIds, [7, 8], reason: '两条既有记录应被分别复用');
    expect(plan.staleIds, isEmpty);
  });

  test('同键条目数增加时，多出来的走新增', () {
    final plan = buildPlaylistRefreshPlan(
      incoming: [
        inc('CCTV-1', 'http://a/1'),
        inc('CCTV-1', 'http://a/1'),
        inc('CCTV-1', 'http://a/1'),
      ],
      existing: [ex(7, 'CCTV-1', 'http://a/1')],
    );

    expect(plan.reusedIds, [7, null, null]);
    expect(plan.staleIds, isEmpty);
    expect(plan.insertedCount, 2);
  });

  test('同键条目数减少时，多余的既有记录被判定为下线', () {
    final plan = buildPlaylistRefreshPlan(
      incoming: [inc('CCTV-1', 'http://a/1')],
      existing: [ex(7, 'CCTV-1', 'http://a/1'), ex(8, 'CCTV-1', 'http://a/1')],
    );

    expect(plan.reusedIds, [7]);
    expect(plan.staleIds, [8]);
  });

  test('首批为全新播放列表时全部新增', () {
    final plan = buildPlaylistRefreshPlan(
      incoming: [inc('A', 'http://a'), inc('B', 'http://b')],
      existing: const <ExistingChannel>[],
    );

    expect(plan.reusedIds, [null, null]);
    expect(plan.staleIds, isEmpty);
  });

  test('源站整体下线时全部既有 id 进入下线列表', () {
    final plan = buildPlaylistRefreshPlan(
      incoming: const <IncomingChannel>[],
      existing: [ex(7, 'A', 'http://a'), ex(8, 'B', 'http://b')],
    );

    expect(plan.reusedIds, isEmpty);
    expect(plan.staleIds, unorderedEquals([7, 8]));
  });

  test('频道顺序变化不影响身份复用', () {
    final plan = buildPlaylistRefreshPlan(
      incoming: [inc('B', 'http://b'), inc('A', 'http://a')],
      existing: [ex(7, 'A', 'http://a'), ex(8, 'B', 'http://b')],
    );

    expect(plan.reusedIds, [8, 7]);
    expect(plan.staleIds, isEmpty);
  });

  test('身份键区分 name 与 url 的组合', () {
    expect(
      channelIdentityKey('A', 'http://x'),
      isNot(channelIdentityKey('B', 'http://x')),
    );
    expect(
      channelIdentityKey('A', 'http://x'),
      isNot(channelIdentityKey('A', 'http://y')),
    );
    expect(
      channelIdentityKey('A', 'http://x'),
      channelIdentityKey('A', 'http://x'),
    );
  });
}
