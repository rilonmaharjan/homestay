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
        citizenImageBlob TEXT,
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

  Future<int> updateLog(int id, Map<String, dynamic> row) async {
    final db = await database;
    return await db.update(
      'homestay',
      row,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // In DatabaseHelper.dart

  Future<Map<String, dynamic>?> getLogById(int id) async {
    final db = await database;
    final result = await db.query(
      'homestay',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
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

  // Helper function to search for the database file
  Future<drive.File?> _getLatestDatabaseFile(drive.DriveApi driveApi) async {
    // Search for files named 'homestay_backup...' with the correct MIME type
    final String query = 
        "name contains 'homestay_backup_' and mimeType = 'application/x-sqlite3'";
    
    // List files, ordered by creation date descending, only get the top 1
    final fileList = await driveApi.files.list(
      q: query,
      $fields: 'files(id, name)',
      orderBy: 'createdTime desc',
      pageSize: 1,
    );

    return fileList.files?.isNotEmpty == true ? fileList.files!.first : null;
  }

  /// Downloads the latest database backup from Google Drive and saves it locally.
  Future<bool> downloadDatabaseFromDrive() async {
    final httpClient = await _getAuthenticatedHttpClient();
    if (httpClient == null) return false;

    try {
      final driveApi = drive.DriveApi(httpClient);
      final latestFile = await _getLatestDatabaseFile(driveApi);

      if (latestFile == null || latestFile.id == null) {
        debugPrint('No database backup found in Google Drive.');
        return false;
      }

      // 1. Get the local path where the file must be saved
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'homestay.db');
      final dbFile = File(path);

      // 2. Download the file content
      // Use the download request and cast the response to Media (Stream<List<int>>)
      final drive.Media downloadedMedia = await driveApi.files.get(
        latestFile.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;
      
      // 3. Write the streamed bytes to the local file
      final sink = dbFile.openWrite();
      await downloadedMedia.stream.pipe(sink);
      await sink.close();

      debugPrint('✅ Database downloaded and saved successfully to: $path');
      return true;

    } catch (e) {
      debugPrint('❌ Error during Drive download: $e');
      return false;
    } finally {
      httpClient.close();
    }
  }

  // so the file can be overwritten and reloaded.
  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null; // Set to null so get database reinitializes it
    }
  }

  /// Deletes the latest database backup from Google Drive.
  Future<bool> deleteDatabaseFromDrive() async {
    final httpClient = await _getAuthenticatedHttpClient();
    if (httpClient == null) return false;

    try {
      final driveApi = drive.DriveApi(httpClient);
      // Use the same helper to find the latest file
      final fileToDelete = await _getLatestDatabaseFile(driveApi);

      if (fileToDelete == null || fileToDelete.id == null) {
        debugPrint('No database backup found to delete.');
        return false;
      }

      // Call the delete API endpoint
      await driveApi.files.delete(fileToDelete.id!);

      debugPrint('✅ Database file deleted successfully from Drive.');
      return true;

    } catch (e) {
      debugPrint('❌ Error during Drive deletion: $e');
      return false;
    } finally {
      httpClient.close();
    }
  }
}