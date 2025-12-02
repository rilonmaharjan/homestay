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

    // 1. New Table for Food Items (Menu)
    await db.execute('''
      CREATE TABLE food_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price REAL NOT NULL, -- Fixed rate for the item
        isAvailable INTEGER NOT NULL 
      )
    ''');

    // 2. New Table for Guest Food Consumption (Billing)
    await db.execute('''
      CREATE TABLE guest_food_consumption (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        logId INTEGER NOT NULL,
        foodItemId INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        pricePerUnit REAL NOT NULL, 
        FOREIGN KEY (logId) REFERENCES homestay(id) ON DELETE CASCADE,
        FOREIGN KEY (foodItemId) REFERENCES food_items(id)
      )
    ''');

    // 3. New Table for Room Rates (Single global rate)
    await db.execute('''
      CREATE TABLE room_types (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price REAL NOT NULL, -- Price per night for this room type
        description TEXT
      )
    ''');

    await db.insert('room_types', {'name': 'Standard Single', 'price': 40.0, 'description': 'Basic single occupancy room'}); 
    await db.insert('room_types', {'name': 'Double Deluxe', 'price': 75.0, 'description': 'Premium room with double bed'});
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
      // Use a clearer naming convention to easily identify backups
      fileMetadata.name = 'Homestay_Backup_${DateTime.now().toIso8601String().substring(0, 16)}.db'; 
      fileMetadata.mimeType = 'application/x-sqlite3'; 

      // Optional: Search for existing files with the base name and update, 
      // instead of creating new ones, to prevent clutter.
      
      // 3. Upload the file
      final response = await driveApi.files.create(
        fileMetadata,
        uploadMedia: drive.Media(
          dbFile.openRead(),
          dbFile.lengthSync(),
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

      // CRITICAL STEP: Close the existing connection to the old database file
      // before overwriting it with the new one.
      await closeDatabase(); 

      // 1. Get the local path where the file must be saved
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'homestay.db');
      final dbFile = File(path);

      // 2. Download the file content
      final drive.Media downloadedMedia = await driveApi.files.get(
        latestFile.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;
      
      // 3. Write the streamed bytes to the local file
      final sink = dbFile.openWrite();
      await downloadedMedia.stream.pipe(sink);
      await sink.close();

      debugPrint('✅ Database downloaded and saved successfully to: $path');
      
      // IMPORTANT: After returning true, your application (e.g., the home page) 
      // must be instructed to reload to reconnect to the new database file.
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

  // Deletes the latest database backup from Google Drive.
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

  // Food Item Methods
  Future<List<Map<String, dynamic>>> getAllFoodItems() async {
      final db = await database;
      return await db.query('food_items', orderBy: 'name ASC');
  }

  // Guest Food Consumption Methods
  Future<int> insertGuestConsumption(Map<String, dynamic> row) async {
      final db = await database;
      return await db.insert('guest_food_consumption', row);
  }

  Future<List<Map<String, dynamic>>> getGuestConsumptionByLogId(int logId) async {
      final db = await database;
      return await db.rawQuery('''
          SELECT 
              gfc.*, 
              fi.name as foodName
          FROM 
              guest_food_consumption gfc
          JOIN 
              food_items fi ON gfc.foodItemId = fi.id
          WHERE 
              gfc.logId = ?
          ORDER BY gfc.id DESC
      ''', [logId]);
  }

  // Room Rate Methods
  Future<double> getRoomRate() async {
      final db = await database;
      final result = await db.query('room_rates', where: 'id = 1', limit: 1);
      // Use 1500.0 as a hardcoded fallback if rate table is empty
      return result.isNotEmpty ? (result.first['rate'] as double) : 1500.0; 
  }

  // New method required for adding food items
  Future<int> insertFoodItem(Map<String, dynamic> row) async {
      final db = await database;
      return await db.insert('food_items', row);
  }

  // Get all defined room types (for management and selection)
  Future<List<Map<String, dynamic>>> getAllRoomTypes() async {
      final db = await database;
      return await db.query('room_types', orderBy: 'name ASC');
  }

  // Add a new room type
  Future<int> insertRoomType(Map<String, dynamic> row) async {
      final db = await database;
      return await db.insert('room_types', row);
  }

  // Update an existing room type
  Future<int> updateRoomType(Map<String, dynamic> row, int id) async {
      final db = await database;
      return await db.update('room_types', row, where: 'id = ?', whereArgs: [id]);
  }

  // Get room type by ID (used for billing if linked)
  Future<Map<String, dynamic>?> getRoomTypeById(int id) async {
      final db = await database;
      final result = await db.query('room_types', where: 'id = ?', whereArgs: [id], limit: 1);
      return result.isNotEmpty ? result.first : null;
  }
}