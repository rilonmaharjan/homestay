import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart';
import 'dart:io';
// Package needed for GoogleSignIn class (The fix)
import 'package:google_sign_in/google_sign_in.dart'; 
// Use the standard http package for the base client
import 'package:http/http.dart' as http; 
// Package for interacting with Google Drive
import 'package:googleapis/drive/v3.dart' as drive; 
// Your custom client
import 'package:homestay/helper/google_client.dart'; 
// Ensure 'google_client.dart' contains the 'GoogleHttpClient' class.


class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  static DatabaseHelper get instance => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'homestay.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE homestay (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        address TEXT,
        arrivalDate TEXT,
        checkInTime TEXT,
        citizenNumber TEXT,
        occupation TEXT,
        numberOfGuests INTEGER,
        relationWithPartner TEXT,
        reasonOfStay TEXT,
        contactNumber TEXT,
        roomNumber TEXT,
        checkOutDate TEXT,
        checkOutTime TEXT,
        citizenImageLocalPath TEXT,
        citizenImageDriveLink TEXT,
        createdAt TEXT
      )
    ''');
  }

  Future<int> insertLog(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('homestay', row);
  }

  Future<List<Map<String, dynamic>>> getAllLogs() async {
    final db = await database;
    return await db.query('homestay', orderBy: 'id DESC');
  }

  Future<int> deleteLog(int id) async {
    final db = await database;
    return await db.delete('homestay', where: 'id = ?', whereArgs: [id]);
  }

  /// Gets the authenticated HTTP client for Google API calls
  Future<http.Client?> _getAuthenticatedHttpClient() async {
    const scopes = [drive.DriveApi.driveFileScope];
    
    // FIX: Create an instance of GoogleSignIn
    final GoogleSignIn googleSignIn = GoogleSignIn(scopes: scopes);

    try {
      // FIX: Call signIn() on the created instance
      final GoogleSignInAccount? account = await googleSignIn.signIn();

      if (account == null) {
        // User cancelled the sign-in process
        return null;
      }
      
      // Get auth headers from the signed-in account
      final authHeaders = await account.authHeaders;

      if (authHeaders.isNotEmpty) {
        // The GoogleHttpClient (your custom class) takes the headers
        return GoogleHttpClient(authHeaders);
      }
      return null;

    } catch (error) {
      debugPrint('Google Sign-In Error: $error');
      return null;
    }
  }

  /// Uploads the SQLite database file to Google Drive.
  Future<void> uploadDatabaseToDrive() async {
    final httpClient = await _getAuthenticatedHttpClient();

    if (httpClient == null) {
      debugPrint('Authentication failed. Cannot upload to Drive.');
      return;
    }

    // 1. Get the database file path
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'homestay.db');
    final dbFile = File(path);

    if (!await dbFile.exists()) {
      debugPrint('Database file not found at: $path');
      return;
    }

    try {
      final driveApi = drive.DriveApi(httpClient);

      // 2. Prepare the file metadata
      final fileMetadata = drive.File();
      fileMetadata.name = 'homestay_backup_${DateTime.now().toIso8601String().substring(0, 10)}.db';
      fileMetadata.mimeType = 'application/x-sqlite3'; // Standard SQLite MIME type

      // Optional: Search for an existing folder and upload there
      // You can implement folder finding/creation logic here.
      // For simplicity, this uploads to the root of My Drive.

      // 3. Upload the file
      final response = await driveApi.files.create(
        fileMetadata,
        uploadMedia: drive.Media(
          dbFile.openRead(), // Stream the file content
          dbFile.lengthSync(), // File size
        ),
      );

      debugPrint('✅ Database Uploaded Successfully! File ID: ${response.id}');
    } catch (e) {
      debugPrint('❌ Error during Drive upload: $e');
    } finally {
      httpClient.close();
    }
  }
}