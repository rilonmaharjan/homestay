import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:homestay/view/add_log.dart';
import '../database/database_helper.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Use a modern, softer color scheme
  static const Color primaryColor = Color(0xFF4A148C); // Deep Purple
  static const Color accentColor = Color(0xFFC7E7FF); // Light Blue/Cyan for accents
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color backgroundColor = Color(0xFFF0F4F8); // Off-white/light gray

  List<Map<String, dynamic>> logs = [];
  List<Map<String, dynamic>> filteredLogs = [];
  bool isLoading = true;
  bool isUpLoading = false;

  String searchQuery = '';
  String filterOption = 'All';

  // Available filter options for the Dropdown
  final List<String> filterOptions = ['All', 'Today'];

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => isLoading = true);
    final data = await DatabaseHelper.instance.getAllLogs();
    setState(() {
      logs = data;
      _applyFilters();
      isLoading = false;
    });
  }

  void _applyFilters() {
    DateTime now = DateTime.now();
    DateTime? fromDate;

    // Simplified date calculation for filtering
    switch (filterOption) {
      case 'Today':
        fromDate = DateTime(now.year, now.month, now.day);
        break;
      case 'All':
      default:
        fromDate = null;
        break;
    }

    setState(() {
      filteredLogs = logs.where((log) {
        final name = log['name']?.toString().toLowerCase() ?? '';
        final matchesSearch = name.contains(searchQuery.toLowerCase());

        bool matchesDate = true;
        
        // 🔑 FIX: Use 'arrivalDate' for filtering instead of 'createdAt'
        final arrivalDateStr = log['arrivalDate']?.toString();

        if (fromDate != null && (arrivalDateStr ?? '').isNotEmpty) {
          try {
            // arrivalDate is stored as 'YYYY-MM-DD'
            DateTime arrivalDate = DateFormat('yyyy-MM-dd').parse(arrivalDateStr!);
            
            // Normalize arrivalDate to start of day for accurate comparison
            DateTime normalizedArrivalDate = DateTime(arrivalDate.year, arrivalDate.month, arrivalDate.day);
            DateTime normalizedFromDate = DateTime(fromDate.year, fromDate.month, fromDate.day);
            
            if (filterOption == 'Today') {
               matchesDate = normalizedArrivalDate.isAtSameMomentAs(normalizedFromDate);
            } else {
               // Include the start date (isAfter or isAtSameMomentAs)
               matchesDate = normalizedArrivalDate.isAfter(normalizedFromDate) || normalizedArrivalDate.isAtSameMomentAs(normalizedFromDate);
            }
          } catch (e) {
            // Default to true if date parsing fails, but log error for debugging
            matchesDate = true; 
            // print('Date Parsing Error in _applyFilters: $e');
          }
        }
        return matchesSearch && matchesDate;
      }).toList();
    });
  }
  
  // ... (omitted _goToAdd and _deleteLog for brevity)

  Future<void> _goToAdd() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddLogPage()),
    );
    _fetchLogs();
  }

  Future<void> _deleteLog(int id) async {
    await DatabaseHelper.instance.deleteLog(id);
    _fetchLogs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Homestay Logs',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: isUpLoading == true ? SizedBox(height: 15.sp, width: 15.sp, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2,)) : const Icon(Icons.upload, color: Colors.white),
            onPressed: _uploadDatabase,
          ),
        ],
        backgroundColor: primaryColor,
        elevation: 0, // Flat app bar for a modern look
      ),
      body: RefreshIndicator(
        onRefresh: ()async {
          return await Future.delayed(const Duration(seconds: 1),(){
            _fetchLogs();
        });
        },
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                child: Column(
                  children: [
                    _buildFilterAndSearchRow(),
                    isLoading
                        ? const Center(child: CircularProgressIndicator(color: primaryColor))
                        : filteredLogs.isEmpty
                            ? const Center(
                                child: Text(
                                  'No logs found.',
                                  style: TextStyle(fontSize: 16, color: Colors.black54),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                itemCount: filteredLogs.length,
                                itemBuilder: (context, index) {
                                  final item = filteredLogs[index];
                                  return _buildLogCard(item);
                                },
                              ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _goToAdd,
        backgroundColor: primaryColor,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  // --- Widgets for Modern UI ---

  Widget _buildFilterAndSearchRow() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha:0.1),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search by name...',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  prefixIcon: const Icon(Icons.search, color: primaryColor),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                ),
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                    _applyFilters();
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha:0.3),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: DropdownButtonHideUnderline( // Hide the underline
              child: DropdownButton<String>(
                value: filterOption,
                // 🔑 FIX: Add the selected text here, making the icon the suffix
                hint: Text(filterOption, style: const TextStyle(color: Colors.white)),
                icon: const Icon(Icons.filter_list, color: Colors.white),
                dropdownColor: cardColor,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500), // Text color of the selected item on the button
                items: filterOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      style: const TextStyle(color: primaryColor), // Text color in the dropdown list
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      filterOption = value;
                      _applyFilters();
                    });
                  }
                },
                selectedItemBuilder: (BuildContext context) {
                  // 🔑 FIX: This builder defines what appears on the button itself
                  return filterOptions.map((String value) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    );
                  }).toList();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> item) {
    // --- Check-in Formatting ---
    String displayCheckin = 'N/A';
    final arrivalDateStr = item['arrivalDate']?.toString(); // YYYY-MM-DD
    final checkInTimeStr = item['checkInTime']?.toString(); // e.g., 10:30 AM

    if (arrivalDateStr != null && arrivalDateStr.isNotEmpty) {
      try {
        final date = DateFormat('yyyy-MM-dd').parse(arrivalDateStr);
        final formattedDate = DateFormat('yyyy-MM-dd').format(date);
        displayCheckin = '$formattedDate at ${checkInTimeStr ?? 'TBD'}';
      } catch (_) {
        displayCheckin = 'Invalid Date at ${checkInTimeStr ?? 'TBD'}';
      }
    }

    // --- Check-out Formatting ---
    String displayCheckout = 'N/A';
    final checkOutDateStr = item['checkOutDate']?.toString(); 
    final checkOutTimeStr = item['checkOutTime']?.toString();

    if (checkOutDateStr != null && checkOutDateStr.isNotEmpty) {
      try {
        final date = DateFormat('yyyy-MM-dd').parse(checkOutDateStr);
        final formattedDate = DateFormat('yyyy-MM-dd').format(date);
        displayCheckout = '$formattedDate at ${checkOutTimeStr ?? 'TBD'}';
      } catch (_) {
        displayCheckout = 'Invalid Date at ${checkOutTimeStr ?? 'TBD'}';
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha:0.15),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 4), // subtle shadow for depth
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: _buildProfileImage(item['citizenImageLocalPath']),
        title: Text(
          item['name'] ?? 'No name',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: primaryColor,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if ((item['address'] ?? '').toString().isNotEmpty)
              Text(
                '📍 ${item['address']}',
                style: const TextStyle(color: Colors.black87),
              ),
            if ((item['contactNumber'] ?? '').toString().isNotEmpty)
              Text(
                '📞 ${item['contactNumber']}',
                style: const TextStyle(color: Colors.black87),
              ),
            const SizedBox(height: 6),
            // Display: Check-in
            _buildInfoChip(Icons.login, '', displayCheckin),
            // Display: Check-out
            _buildInfoChip(Icons.logout, '', displayCheckout),
          ],
        ),
        isThreeLine: true,
        trailing: _buildPopupMenu(item['id'] as int),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 2.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: primaryColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              // Show the label again
              '$label: $value', 
              style: const TextStyle(fontSize: 13, color: Colors.black54),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImage(String? path) {
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            file,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackIcon(),
          ),
        );
      }
    }
    return _buildFallbackIcon();
  }

  Widget _buildFallbackIcon() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: accentColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.person, size: 40, color: primaryColor),
    );
  }


  Widget _buildPopupMenu(int id) {
    return PopupMenuButton<String>(
      onSelected: (v) {
        if (v == 'delete') {
          _deleteLog(id);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
      icon: const Icon(Icons.more_vert, color: Colors.black54),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  //upload to drive
  Future<void> _uploadDatabase() async {
    setState(() => isUpLoading = true); // Assuming you have an isUpLoading boolean
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
        setState(() => isUpLoading = false);
      }
    }
  }

}