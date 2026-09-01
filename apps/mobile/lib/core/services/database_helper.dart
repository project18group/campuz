import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('campuz_offline.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE hubs (
        id INTEGER PRIMARY KEY,
        data TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY,
        hub_id INTEGER NOT NULL,
        data TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE offline_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        hub_id INTEGER NOT NULL,
        content TEXT NOT NULL,
        attachments TEXT,
        reply_to_id INTEGER,
        created_at INTEGER NOT NULL,
        send_as_sms INTEGER DEFAULT 0
      )
    ''');
  }

  // --- Hubs ---
  Future<void> saveHubs(List<dynamic> hubs) async {
    final db = await instance.database;
    final batch = db.batch();
    
    // Clear old hubs (simplified sync for now)
    batch.delete('hubs');
    
    for (final hub in hubs) {
      batch.insert('hubs', {
        'id': hub['id'],
        'data': jsonEncode(hub),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getHubs() async {
    final db = await instance.database;
    final result = await db.query('hubs', orderBy: 'updated_at DESC');
    return result.map((e) => jsonDecode(e['data'] as String) as Map<String, dynamic>).toList();
  }

  // --- Messages ---
  Future<void> saveMessages(int hubId, List<dynamic> messages) async {
    final db = await instance.database;
    final batch = db.batch();
    
    // In a real app we'd upsert, but for simplicity we clear and insert the latest page
    batch.delete('messages', where: 'hub_id = ?', whereArgs: [hubId]);
    
    for (final msg in messages) {
      batch.insert('messages', {
        'id': msg['id'],
        'hub_id': hubId,
        'data': jsonEncode(msg),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getMessages(int hubId) async {
    final db = await instance.database;
    final result = await db.query(
      'messages',
      where: 'hub_id = ?',
      whereArgs: [hubId],
      orderBy: 'updated_at DESC',
    );
    return result.map((e) => jsonDecode(e['data'] as String) as Map<String, dynamic>).toList();
  }

  // --- Offline Queue ---
  Future<int> queueMessage({
    required int hubId,
    required String content,
    List<String>? attachments,
    int? replyToId,
    bool sendAsSms = false,
  }) async {
    final db = await instance.database;
    return await db.insert('offline_queue', {
      'hub_id': hubId,
      'content': content,
      'attachments': attachments != null ? jsonEncode(attachments) : null,
      'reply_to_id': replyToId,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'send_as_sms': sendAsSms ? 1 : 0,
    });
  }

  Future<List<Map<String, dynamic>>> getQueuedMessages() async {
    final db = await instance.database;
    return await db.query('offline_queue', orderBy: 'created_at ASC');
  }

  Future<void> deleteQueuedMessage(int id) async {
    final db = await instance.database;
    await db.delete('offline_queue', where: 'id = ?', whereArgs: [id]);
  }
}
