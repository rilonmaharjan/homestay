// lib/pages/log_detail_page.dart

import 'package:flutter/material.dart';
import 'dart:typed_data';

// Assuming your DatabaseHelper path is correct
import 'package:homestay/database/database_helper.dart'; 
// Assuming your UpsertLogPage is correctly named and located
import 'package:homestay/view/add_log.dart'; 


class LogDetailPage extends StatefulWidget {
  final int logId;
  final VoidCallback onLogUpdated; // For refreshing the list on the previous page

  const LogDetailPage({
    super.key, 
    required this.logId, 
    required this.onLogUpdated,
  });

  @override
  State<LogDetailPage> createState() => _LogDetailPageState();
}

class _LogDetailPageState extends State<LogDetailPage> {
  // Use the same modern color scheme
  static const Color primaryColor = Color(0xFF4A148C); // Deep Purple 
  static const Color backgroundColor = Color(0xFFF0F4F8); // Off-white/light gray
  static const Color cardColor = Colors.white;

  Map<String, dynamic>? _logData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLogDetails();
  }

  // --- Data and Navigation Logic (Remains unchanged) ---

  Future<void> _fetchLogDetails() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getLogById(widget.logId);
    setState(() {
      _logData = data;
      _isLoading = false;
    });
  }

  void _navigateToEditPage() async {
    if (_logData == null) return;
    
    final bool? result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UpsertLogPage(
          logId: widget.logId,
          initialData: _logData!,
        ),
      ),
    );

    if (result == true) {
      await _fetchLogDetails();
      widget.onLogUpdated();
    }
  }

  // --- New UI Helper Widgets ---

  Widget _buildImage(Uint8List? imageBlob) {
    if (imageBlob != null && imageBlob.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.only(bottom: 20.0),
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.0),
            child: Image.memory(
              imageBlob,
              fit: BoxFit.cover,
              height: 250,
              width: 300,
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildDetailItem(String title, String? value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) Icon(icon, size: 18, color: primaryColor.withValues(alpha: 0.7)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value ?? 'N/A',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const Divider(height: 16),
        ],
      ),
    );
  }

  Widget _buildDetailCard({required String title, required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const Divider(color: primaryColor, thickness: 1, height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          _logData?['name'] ?? 'Guest Details',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: _isLoading ? null : _navigateToEditPage,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : _logData == null
              ? const Center(child: Text('Log entry not found.', style: TextStyle(color: Colors.red)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Photo Section ---
                      _buildImage(_logData!['citizenImageBlob'] as Uint8List?),

                      // --- Identity Card ---
                      _buildDetailCard(
                        title: 'Guest Identity',
                        children: [
                          _buildDetailItem('Guest Name', _logData!['name'], icon: Icons.person),
                          _buildDetailItem('Citizen Number', _logData!['citizenNumber'], icon: Icons.badge),
                          _buildDetailItem('Contact Number', _logData!['contactNumber'], icon: Icons.phone),
                          _buildDetailItem('Address', _logData!['address'], icon: Icons.location_on),
                        ],
                      ),

                      // --- Booking Card ---
                      _buildDetailCard(
                        title: 'Booking & Room Details',
                        children: [
                          _buildDetailItem('Arrival Date', _logData!['arrivalDate']?.toString().substring(0, 10), icon: Icons.calendar_today),
                          _buildDetailItem('Check-in Time', _logData!['checkInTime'], icon: Icons.access_time),
                          _buildDetailItem('Check-Out Date', _logData!['checkOutDate']?.toString().substring(0, 10) ?? 'N/A', icon: Icons.calendar_today_outlined),
                          _buildDetailItem('Check-Out Time', _logData!['checkOutTime'] ?? 'N/A', icon: Icons.access_time_outlined),
                          _buildDetailItem('Room Number', _logData!['roomNumber'], icon: Icons.meeting_room),
                          _buildDetailItem('Guests', _logData!['numberOfGuests']?.toString(), icon: Icons.people),
                        ],
                      ),
                      
                      // --- Other Info Card ---
                      _buildDetailCard(
                        title: 'Other Information',
                        children: [
                          _buildDetailItem('Occupation', _logData!['occupation'] ?? 'N/A', icon: Icons.work),
                          _buildDetailItem('Reason of Stay', _logData!['reasonOfStay'] ?? 'N/A', icon: Icons.info),
                          _buildDetailItem('Relation with Partner', _logData!['relationWithPartner'] ?? 'N/A', icon: Icons.people_alt_outlined),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }
}