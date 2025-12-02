import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:homestay/view/add_rates.dart';
import 'package:homestay/view/billing_dialog.dart';
import 'package:homestay/view/food_lodging.dart';
import 'package:homestay/view/log_detail_page.dart';
import 'package:homestay/view/settings_page.dart';
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
      MaterialPageRoute(builder: (_) => const UpsertLogPage()),
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
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: (){
              // Navigate to settings page
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => SettingsPage(onLogsRefreshed: _fetchLogs)),
              );
            },
          ),
        ],
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: Stack(
        children: [
          RefreshIndicator(
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
                            ? SizedBox(
                              height: 600.0.h,
                              child: const Center(child: CircularProgressIndicator(color: primaryColor))
                            )
                            : filteredLogs.isEmpty
                                ? SizedBox(
                                  height: 600.0.h,
                                  child: const Center(
                                      child: Text(
                                        'No logs found.',
                                        style: TextStyle(fontSize: 16, color: Colors.black54),
                                      ),
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
          // --- Button Widget to be placed in the Home Page body ---
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Menu/Rate Management Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const MenuRateManagementPage()),
                        ).then((_) => _fetchLogs()); // Refresh list after managing rates
                      },
                      icon: const Icon(Icons.restaurant_menu, color: Colors.white),
                      label: const Text('Menu & Rates'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey, // Distinct color for settings
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12), // Space between buttons
            
                  // Add New Guest Log Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _goToAdd, // Assuming _goToAdd is your existing navigation function
                      icon: const Icon(Icons.person_add, color: Colors.white),
                      label: const Text('New Guest Log'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor, // Your main app color
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: filterOption,
                hint: Text(filterOption, style: const TextStyle(color: Colors.white)),
                icon: const Icon(Icons.filter_list, color: Colors.white),
                dropdownColor: cardColor,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                items: filterOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      style: const TextStyle(color: primaryColor), 
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
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LogDetailPage(logId: item['id'] as int, onLogUpdated: _fetchLogs),
          ),
        ),
        contentPadding: const EdgeInsets.all(12),
        leading: _buildProfileImage(item['citizenImageBlob']),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['name'] ?? 'No name',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: primaryColor,
              ),
            ),
            Text(
              'Room ${item['roomNumber'] ?? ""}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: primaryColor,
              ),
            ),
          ],
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
        trailing: _buildPopupMenu(item['id'] as int, item),
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

  Widget _buildProfileImage(Uint8List? bytes) {
    if (bytes != null && bytes.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          bytes,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackIcon(),
        ),
      );
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

  // The signature of your method must change to accept the full log map:
  Widget _buildPopupMenu(int id, Map<String, dynamic> log) { 
    return PopupMenuButton<String>(
      onSelected: (v) {
        if (v == 'delete') {
          _deleteLog(id);
        } else if (v == 'log_food') {
          // Call function to log food
          _showFoodLoggingDialog(id);
        } else if (v == 'calculate_bill') {
          // Call function to calculate bill, passing the full log data
          _showBillingDialog(id, log);
        } else if (v == 'checkout') {
          // If checkout is handled separately, keep this (but billing usually implies checkout)
          _showCheckOutDialog(id); 
        }
      },
      itemBuilder: (_) => [
        // Log Food/Service Option (New)
        const PopupMenuItem(
          value: 'log_food',
          child: Row(
            children: [
              Icon(Icons.restaurant, color: Colors.orange),
              SizedBox(width: 8),
              Text('Log Food/Service'),
            ],
          ),
        ),
        
        // Calculate Bill Option (New)
        const PopupMenuItem(
          value: 'calculate_bill',
          child: Row(
            children: [
              Icon(Icons.receipt_long, color: Colors.green),
              SizedBox(width: 8),
              Text('Calculate Bill', style: TextStyle(color: Colors.green)),
            ],
          ),
        ),
        
        // CHECK OUT Option (Moved lower, as billing often precedes/includes checkout)
        const PopupMenuItem(
          value: 'checkout',
          child: Row(
            children: [
              Icon(Icons.logout, color: Colors.blue),
              SizedBox(width: 8),
              Text('Update Check Out', style: TextStyle(color: Colors.blue)),
            ],
          ),
        ),
        
        // Divider
        const PopupMenuDivider(), 

        // DELETE Option
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

  void _showFoodLoggingDialog(int logId) {
    showDialog(
      context: context,
      builder: (context) => FoodLoggingDialog(logId: logId),
    );
  }

  void _showBillingDialog(int logId, Map<String, dynamic> logData) {
    showDialog(
      context: context,
      builder: (context) => BillingCalculationDialog(logId: logId, logData: logData),
    );
  }

  String _timeOfDayToString(TimeOfDay t) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    return DateFormat.jm().format(dt);
  }

  TimeOfDay _stringToTimeOfDay(String timeString) {
    try {
      final parts = timeString.split(':');
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return TimeOfDay.now(); 
    }
  }

  Future<void> _showCheckOutDialog(int id) async {
    // Fetch the existing log data
    final log = await DatabaseHelper.instance.getLogById(id);
    if (log == null) {
      // Handle case where log isn't found
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Log not found.')),
        );
      }
      return;
    }

    // Get current check-out values from the database
    final String? dbCheckOutDate = log['checkOutDate'] as String?;
    final String? dbCheckOutTime = log['checkOutTime'] as String?;

    // Set initial date/time: Use DB value if valid, otherwise use DateTime.now()
    DateTime initialDate = DateTime.now();
    if (dbCheckOutDate != null && dbCheckOutDate.isNotEmpty) {
      try {
        initialDate = DateTime.parse(dbCheckOutDate); 
      } catch (_) {
      }
    }

    TimeOfDay initialTime = TimeOfDay.now();
    if (dbCheckOutTime != null && dbCheckOutTime.isNotEmpty) {
      initialTime = _stringToTimeOfDay(dbCheckOutTime); 
    }


    // Prompt for Date
    final DateTime? selectedDate = await showDatePicker(
      // ignore: use_build_context_synchronously
      context: context,
      // Use the fetched initialDate
      initialDate: initialDate, 
      firstDate: initialDate.subtract(const Duration(days: 30)),
      lastDate: initialDate.add(const Duration(days: 30)),
      helpText: 'Select Check-Out Date',
    );

    if (selectedDate == null) return; // User cancelled date selection

    // Prompt for Time
    final TimeOfDay? selectedTime = await showTimePicker(
      // ignore: use_build_context_synchronously
      context: context,
      // Use the fetched initialTime
      initialTime: initialTime, 
      helpText: 'Select Check-Out Time',
    );

    if (selectedTime == null) return; // User cancelled time selection

    // Perform the update
    _performCheckOut(id, selectedDate, selectedTime);
  }

  Future<void> _performCheckOut(
    int id,
    DateTime date,
    TimeOfDay time,
  ) async {
    // Format the date and time as required by your database schema
    final checkOutDateString = date.toIso8601String().substring(0, 10);
    final checkOutTimeString = _timeOfDayToString(time);

    try {
      // Data to update
      final updateData = {
        'checkOutDate': checkOutDateString,
        'checkOutTime': checkOutTimeString,
      };

      // Call the new update method in your DatabaseHelper
      await DatabaseHelper.instance.updateLog(id, updateData);

      // Refresh the log list in the UI
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Log successfully checked out.')),
        );
        _fetchLogs();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to check out log: $e')),
        );
      }
    }
  }

}