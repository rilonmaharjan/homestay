// lib/pages/log_detail_page.dart

import 'package:flutter/material.dart';
import 'dart:typed_data';

import 'package:homestay/database/database_helper.dart';
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
  Map<String, dynamic>? _logData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLogDetails();
  }

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
    
    // Navigate and wait for the result (true if data was updated)
    final bool? result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UpsertLogPage(
          logId: widget.logId,
          initialData: _logData!,
        ),
      ),
    );

    // If data was updated, refresh this detail page and trigger the home page refresh
    if (result == true) {
      await _fetchLogDetails(); // Refresh details on this page
      widget.onLogUpdated();    // Trigger home page list refresh
    }
  }

  Widget _buildImage(Uint8List? imageBlob) {
    if (imageBlob != null && imageBlob.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: Image.memory(
            imageBlob,
            fit: BoxFit.cover,
            height: 200,
            width: double.infinity,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildDetailItem(String title, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey[700]),
          ),
          const SizedBox(height: 4),
          Text(value ?? 'N/A', style: const TextStyle(fontSize: 15)),
          const Divider(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_logData?['name'] ?? 'Guest Details'),
        actions: [
          // The EDIT Button
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _isLoading ? null : _navigateToEditPage,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logData == null
              ? const Center(child: Text('Log entry not found.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildImage(_logData!['citizenImageBlob'] as Uint8List?),

                      _buildDetailItem('Guest Name', _logData!['name']),
                      _buildDetailItem('Address', _logData!['address']),
                      _buildDetailItem('Arrival Date', _logData!['arrivalDate']?.toString().substring(0, 10)),
                      _buildDetailItem('Check-in Time', _logData!['checkInTime']),
                      _buildDetailItem('Check-Out Date', _logData!['checkOutDate']?.toString().substring(0, 10)),
                      _buildDetailItem('Check-Out Time', _logData!['checkOutTime']),
                      _buildDetailItem('Citizen Number', _logData!['citizenNumber']),
                      _buildDetailItem('Contact Number', _logData!['contactNumber']),
                      _buildDetailItem('Guests', _logData!['numberOfGuests']?.toString()),
                      _buildDetailItem('Room Number', _logData!['roomNumber']),
                      _buildDetailItem('Drive Link', _logData!['citizenImageDriveLink'] ?? 'Not Uploaded'),
                    ],
                  ),
                ),
    );
  }
}