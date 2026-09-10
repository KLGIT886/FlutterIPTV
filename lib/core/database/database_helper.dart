import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import '../services/service_locator.dart';

class DatabaseHelper {
  static Database? _database;
  static const String _databaseName = 'flutter_iptv.db';
  static const int _databaseVersion = 9; // Added catchup support to channels

  /// 孤儿行清理一次性标志位（SharedPreferences 键）。见 [initialize] 中的降级逻辑。
  static const String _kOrphanPurgeDone = 'db_orphan_purge_done_v1';

  /// 当前数据库 schema 版本（供备份元数据等引用，避免硬编码漂移）
  static int get databaseVersion => _databaseVersion;

  Future<void> initialize() async {
    ServiceLocator.log.d('DatabaseHelper: 开始初始化数据库');
    final startTime = DateTime.now();

    if (_database != null) {
      ServiceLocator.log.d('DatabaseHelper: 数据库已初始化，跳过');
      return;
    }

    // Note: FFI initialization is handled in main.dart

    final Directory appDir = await getApplicationDocumentsDirectory();
    final String path = join(appDir.path, _databaseName);
    ServiceLocator.log.d('DatabaseHelper: 数据库路径: $path');

    _database = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onDowngrade: _onDowngrade,
      // 显式启用 SQLite 外键，使表定义中的 ON DELETE CASCADE 真正生效。
      // 否则删频道/删播放列表不会级联清理 favorites/watch_history。
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );

    // 检查台标表是否为空，如果为空则导入数据
    await _ensureChannelLogosImported();

    // 清理存量孤儿数据（开启外键前的历史残留）：引用了已不存在频道/播放列表的
    // 收藏与观看记录。P0-1 改为增量 upsert + ON DELETE CASCADE 后，孤儿基本不再产生，
    // 故用一次性标志位降级为只执行一次，避免每次冷启动都跑全表 NOT IN 扫描（P1-13）。
    if (ServiceLocator.prefs.getBool(_kOrphanPurgeDone) != true) {
      await _purgeOrphanedRows();
      await ServiceLocator.prefs.setBool(_kOrphanPurgeDone, true);
    }

    final initTime = DateTime.now().difference(startTime).inMilliseconds;
    ServiceLocator.log.d('DatabaseHelper: 数据库初始化完成，耗时: ${initTime}ms');
  }

  /// 手动清理存量孤儿数据（引用了已不存在频道/播放列表的收藏与观看记录）。
  /// 供设置页"修复数据库"按钮调用，与启动时的自动一次性清理相互独立。
  Future<void> repairDatabase() async {
    await _purgeOrphanedRows();
  }

  /// 清理存量孤儿数据：删除引用了已不存在频道/播放列表的
  /// 收藏与观看记录。仅由 [initialize] 在一次性标志位未置位时调用，
  /// 此后删除走 ON DELETE CASCADE 自动级联，不再需要周期性扫描。
  Future<void> _purgeOrphanedRows() async {
    try {
      final db = _database;
      if (db == null) return;
      final removedFav = await db.rawDelete(
          'DELETE FROM favorites WHERE channel_id NOT IN (SELECT id FROM channels)');
      final removedHistory = await db.rawDelete(
          'DELETE FROM watch_history WHERE channel_id NOT IN (SELECT id FROM channels)');
      await db.rawDelete(
          'DELETE FROM watch_history WHERE playlist_id NOT IN (SELECT id FROM playlists)');
      if (removedFav > 0 || removedHistory > 0) {
        ServiceLocator.log.d(
            'DatabaseHelper: 清理孤儿数据 favorites=$removedFav, watch_history=$removedHistory',
            tag: 'DatabaseHelper');
      }
    } catch (e) {
      ServiceLocator.log.w('DatabaseHelper: 清理孤儿数据失败: $e', tag: 'DatabaseHelper');
    }
  }

  /// 确保台标数据已导入
  Future<void> _ensureChannelLogosImported() async {
    try {
      final result = await _database!
          .rawQuery('SELECT COUNT(*) as count FROM channel_logos');
      final count = result.first['count'] as int;

      ServiceLocator.log.d('🔍 DatabaseHelper: 台标表当前有 $count 条数据');

      if (count == 0) {
        ServiceLocator.log.d('DatabaseHelper: 台标表为空，开始导入数据');
        await _importChannelLogos(_database!);
      } else {
        ServiceLocator.log.d('DatabaseHelper: 台标表已有 $count 条数据，跳过导入');
      }
    } catch (e) {
      ServiceLocator.log.e('DatabaseHelper: 检查台标数据失败: $e');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Playlists table
    await db.execute('''
      CREATE TABLE playlists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        url TEXT,
        file_path TEXT,
        epg_url TEXT,
        is_active INTEGER DEFAULT 1,
        last_updated INTEGER,
        channel_count INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        backup_path TEXT,
        last_backup_time INTEGER
      )
    ''');

    // Channels table
    await db.execute('''
      CREATE TABLE channels (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        playlist_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        url TEXT NOT NULL,
        sources TEXT,
        logo_url TEXT,
        fallback_logo_url TEXT,
        group_name TEXT,
        epg_id TEXT,
        is_active INTEGER DEFAULT 1,
        created_at INTEGER NOT NULL,
        catchup TEXT,
        catchup_source TEXT,
        catchup_days INTEGER,
        FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE
      )
    ''');

    // Favorites table
    await db.execute('''
      CREATE TABLE favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        channel_id INTEGER NOT NULL,
        position INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (channel_id) REFERENCES channels(id) ON DELETE CASCADE
      )
    ''');

    // Watch history table
    await db.execute('''
      CREATE TABLE watch_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        channel_id INTEGER NOT NULL,
        channel_name TEXT,
        channel_url TEXT,
        playlist_id INTEGER NOT NULL,
        watched_at INTEGER NOT NULL,
        duration_seconds INTEGER DEFAULT 0,
        FOREIGN KEY (channel_id) REFERENCES channels(id) ON DELETE CASCADE,
        FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE
      )
    ''');

    // EPG data table
    await db.execute('''
      CREATE TABLE epg_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        channel_epg_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        start_time INTEGER NOT NULL,
        end_time INTEGER NOT NULL,
        category TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    // Create indexes for better performance
    await db
        .execute('CREATE INDEX idx_channels_playlist ON channels(playlist_id)');
    await db.execute('CREATE INDEX idx_channels_group ON channels(group_name)');
    await db
        .execute('CREATE INDEX idx_favorites_channel ON favorites(channel_id)');
    await db.execute(
        'CREATE INDEX idx_history_channel ON watch_history(channel_id)');
    await db.execute(
        'CREATE INDEX idx_history_playlist ON watch_history(playlist_id)');
    await db
        .execute('CREATE INDEX idx_epg_channel ON epg_data(channel_epg_id)');
    await db
        .execute('CREATE INDEX idx_epg_time ON epg_data(start_time, end_time)');

    // Channel logos table
    await db.execute('''
      CREATE TABLE channel_logos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        channel_name TEXT NOT NULL,
        logo_url TEXT NOT NULL,
        search_keys TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_channel_logos_name ON channel_logos(channel_name)');

    // Import channel logos from SQL script
    await _importChannelLogos(db);
  }

  /// Import channel logos from SQL script
  Future<void> _importChannelLogos(Database db) async {
    try {
      ServiceLocator.log.d('DatabaseHelper: 开始导入台标数据');
      final startTime = DateTime.now();

      // Load SQL script from assets
      final sqlScript =
          await rootBundle.loadString('assets/sql/channel_logos.sql');

      // Split into individual statements
      final statements = sqlScript
          .split('\n')
          .where((line) => line.trim().startsWith('INSERT'))
          .toList();

      ServiceLocator.log
          .d('DatabaseHelper: 准备执行 ${statements.length} 条 SQL 语句');

      // Execute in batches for better performance
      const batchSize = 100;
      for (var i = 0; i < statements.length; i += batchSize) {
        final batch = db.batch();
        final end = (i + batchSize < statements.length)
            ? i + batchSize
            : statements.length;

        for (var j = i; j < end; j++) {
          batch.rawInsert(statements[j]);
        }

        await batch.commit(noResult: true);
      }

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      ServiceLocator.log.d(
          'DatabaseHelper: 台标数据导入完成，共 ${statements.length} 条记录，耗时 ${duration}ms');
    } catch (e) {
      ServiceLocator.log.e('DatabaseHelper: 台标数据导入失败: $e');
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add channel_count column to playlists table
      await _addColumnIfNotExists(
          db, 'playlists', 'channel_count', 'INTEGER DEFAULT 0');
    }
    if (oldVersion < 3) {
      // Add sources column to channels table for multi-source support
      await _addColumnIfNotExists(db, 'channels', 'sources', 'TEXT');
    }
    if (oldVersion < 4) {
      // Add epg_url column to playlists table
      await _addColumnIfNotExists(db, 'playlists', 'epg_url', 'TEXT');
    }
    if (oldVersion < 5) {
      // Create channel_logos table (IF NOT EXISTS 幂等)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS channel_logos (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          channel_name TEXT NOT NULL,
          logo_url TEXT NOT NULL,
          search_keys TEXT,
          created_at INTEGER NOT NULL
        )
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_channel_logos_name ON channel_logos(channel_name)');
      // 导入失败不再静默：以 log.e 暴露，便于排查台标缺失。
      try {
        await _importChannelLogos(db);
      } catch (e, st) {
        ServiceLocator.log.e('数据库迁移: 导入台标数据失败', error: e, stackTrace: st);
      }
    }
    if (oldVersion < 6) {
      // Add playlist_id column to watch_history table
      await _addColumnIfNotExists(
          db, 'watch_history', 'playlist_id', 'INTEGER');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_history_playlist ON watch_history(playlist_id)');
      // 将已有记录的 playlist_id 指向第一个可用播放列表
      try {
        final playlists = await db.query('playlists', limit: 1);
        if (playlists.isNotEmpty) {
          final firstPlaylistId = playlists.first['id'];
          await db.update(
            'watch_history',
            {'playlist_id': firstPlaylistId},
            where: 'playlist_id IS NULL',
          );
        }
      } catch (e, st) {
        ServiceLocator.log.e('数据库迁移: 回填 watch_history.playlist_id 失败',
            error: e, stackTrace: st);
      }
    }
    if (oldVersion < 7) {
      // Add fallback_logo_url column to channels table
      await _addColumnIfNotExists(
          db, 'channels', 'fallback_logo_url', 'TEXT');
      ServiceLocator.log.i('数据库迁移: 添加 fallback_logo_url 字段到 channels 表');
    }
    if (oldVersion < 8) {
      // Add backup_path and last_backup_time columns to playlists table
      await _addColumnIfNotExists(db, 'playlists', 'backup_path', 'TEXT');
      await _addColumnIfNotExists(
          db, 'playlists', 'last_backup_time', 'INTEGER');
      ServiceLocator.log.i('数据库迁移: 添加 backup_path/last_backup_time 字段到 playlists 表');
    }
    if (oldVersion < 9) {
      // Add catchup columns to channels table
      await _addColumnIfNotExists(db, 'channels', 'catchup', 'TEXT');
      await _addColumnIfNotExists(db, 'channels', 'catchup_source', 'TEXT');
      await _addColumnIfNotExists(db, 'channels', 'catchup_days', 'INTEGER');
      ServiceLocator.log.i('数据库迁移: 添加 catchup 相关字段到 channels 表');
    }
  }

  /// 版本回退处理：删除全部用户表后按当前 schema 重建。
  /// 由于没有做数据向下兼容，回退时直接重建可避免旧版本代码读取到
  /// 新版本字段导致的 "no such column" 崩溃。历史数据会丢失，符合降级语义。
  Future<void> _onDowngrade(
      Database db, int oldVersion, int newVersion) async {
    ServiceLocator.log.w(
        '数据库版本回退 ($oldVersion -> $newVersion)，将删除并重建',
        tag: 'DatabaseHelper');
    await _dropAllTables(db);
    await _onCreate(db, newVersion);
  }

  /// 幂等地为表添加列：仅当列不存在才执行 ALTER，避免重复执行迁移时
  /// 抛出 "duplicate column"；真实异常（如列类型冲突、表不存在）会向上冒泡，
  /// 由调用方以 log.e 记录，不再被静默吞掉导致后续查询静默失败。
  Future<void> _addColumnIfNotExists(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final exists = info.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  /// 删除全部非系统表（用于版本回退重建）。
  Future<void> _dropAllTables(Database db) async {
    final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'");
    for (final row in tables) {
      final name = row['name'] as String;
      await db.execute('DROP TABLE IF EXISTS $name');
    }
  }

  Database get db {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }
    return _database!;
  }

  Future<void> close() async {
    ServiceLocator.log.i('关闭数据库连接', tag: 'DatabaseHelper');
    if (_database != null) {
      try {
        // 在关闭前执行 WAL checkpoint，确保所有数据写入主数据库文件
        ServiceLocator.log.d('执行 WAL checkpoint', tag: 'DatabaseHelper');
        await _database!.execute('PRAGMA wal_checkpoint(TRUNCATE)');
        ServiceLocator.log.d('WAL checkpoint 完成', tag: 'DatabaseHelper');
      } catch (e) {
        ServiceLocator.log.w('WAL checkpoint 失败（可能不是 WAL 模式）',
            tag: 'DatabaseHelper', error: e);
      }

      await _database!.close();
      _database = null;
      ServiceLocator.log.i('数据库连接已关闭', tag: 'DatabaseHelper');
    } else {
      ServiceLocator.log.d('数据库连接已经是关闭状态', tag: 'DatabaseHelper');
    }
  }

  // Generic CRUD operations
  Future<int> insert(String table, Map<String, dynamic> data) async {
    return await db.insert(table, data);
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    return await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  Future<int> update(
    String table,
    Map<String, dynamic> data, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    return await db.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<List<Map<String, dynamic>>> rawQuery(String sql,
      [List<Object?>? arguments]) async {
    return await db.rawQuery(sql, arguments);
  }

  Batch batch() => db.batch();

  /// Optimize database by reclaiming unused space
  /// This should be called periodically or after large deletions
  Future<void> vacuum() async {
    try {
      ServiceLocator.log.d('开始执行 VACUUM 优化数据库');
      final startTime = DateTime.now();

      await db.execute('VACUUM');

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      ServiceLocator.log.d('VACUUM 完成，耗时: ${duration}ms');
    } catch (e) {
      ServiceLocator.log.e('VACUUM 执行失败', error: e);
      rethrow;
    }
  }

  /// Get database file size in bytes
  Future<int> getDatabaseSize() async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String path = join(appDir.path, _databaseName);
      final file = File(path);

      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      ServiceLocator.log.e('获取数据库大小失败', error: e);
      return 0;
    }
  }
}
