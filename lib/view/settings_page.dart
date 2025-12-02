import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:homestay/database/database_helper.dart';

class SettingsPage extends StatefulWidget {
  final VoidCallback onLogsRefreshed;
  const SettingsPage({super.key, required this.onLogsRefreshed});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  
  // Use a modern, softer color scheme
  static const Color primaryColor = Color(0xFF4A148C);
  static const Color backgroundColor = Color(0xFFF0F4F8);

  //bool
  bool isUploading = false;
  bool isDownloading = false;
  bool isDeleting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0, // Flat app bar for a modern look
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          ListTile(
            leading: isUploading == true ? SizedBox(height: 15.sp, width: 15.sp, child: CircularProgressIndicator(color: primaryColor, strokeWidth: 2,)) : const Icon(Icons.upload, color: primaryColor),
            title: const Text('Upload', style: TextStyle(fontSize: 18)),
            onTap: () {
              _uploadDatabase();
            },
          ),
          const Divider(),
          ListTile(
            leading: isDownloading == true ? SizedBox(height: 15.sp, width: 15.sp, child: CircularProgressIndicator(color: primaryColor, strokeWidth: 2,)) :  const Icon(Icons.download, color: primaryColor),
            title: const Text('Restore', style: TextStyle(fontSize: 18)),
            onTap: () {
              _downloadAndRestoreDatabase();
            },
          ),
          const Divider(),
          ListTile(
            leading: isDeleting == true ? SizedBox(height: 15.sp, width: 15.sp, child: CircularProgressIndicator(color: primaryColor, strokeWidth: 2,)) : const Icon(Icons.delete, color: primaryColor),
            title: const Text('Delete', style: TextStyle(fontSize: 18)),
            onTap: () {
              _deleteLatestBackup();
            },
          ),
          const Divider(),
        ],
      ),
    );
  }

    //upload to drive
  Future<void> _uploadDatabase() async {
    setState(() => isUploading = true); // Assuming you have an isUploading boolean
    try {
      await DatabaseHelper.instance.uploadDatabaseToDrive();
      // Show a success message (e.g., using a SnackBar)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Database backup successful!')),
        );
      }
    } catch (e) {
      // Show an error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isUploading = false);
      }
    }
  }

  //download
  Future<void> _downloadAndRestoreDatabase() async {
    setState(() => isDownloading = true);

    final success = await DatabaseHelper.instance.downloadDatabaseFromDrive();

    if (success) {
      await DatabaseHelper.instance.closeDatabase(); 

      // 🚨 CRITICAL FIX: Call the callback function from the widget property
      widget.onLogsRefreshed(); 

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Database restored successfully!')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restoration failed or no backup found.')),
        );
      }
    }
    
    setState(() => isDownloading = false);
  }

  //delete
  Future<void> _deleteLatestBackup() async {
    setState(() => isDeleting = true);
    
    final success = await DatabaseHelper.instance.deleteDatabaseFromDrive();

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Latest backup deleted from Drive.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deletion failed or no backup found.')),
        );
      }
      setState(() => isDeleting = false);
    }
  }

}