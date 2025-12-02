// lib/widgets/billing_calculation_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart'; 

class BillingCalculationDialog extends StatefulWidget {
  final int logId;
  final Map<String, dynamic> logData;

  const BillingCalculationDialog({
    super.key,
    required this.logId,
    required this.logData,
  });

  @override
  State<BillingCalculationDialog> createState() => _BillingCalculationDialogState();
}

class _BillingCalculationDialogState extends State<BillingCalculationDialog> {
  static const Color primaryColor = Color(0xFF4A148C);
  List<Map<String, dynamic>> _consumption = [];
  double _roomRate = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBillingData();
  }

  // --- CORRECTED DATA LOADING LOGIC ---
  Future<void> _loadBillingData() async {
    // 1. Fetch Guest Consumption
    final consumption = await DatabaseHelper.instance.getGuestConsumptionByLogId(widget.logId);
    
    // 2. Fetch all Room Types
    final roomTypes = await DatabaseHelper.instance.getAllRoomTypes();

    // 3. Find the specific rate for the room assigned to this log
    double rate = 1500.0; // Default fallback rate (in case of missing data)

    final String assignedRoomName = widget.logData['roomNumber'];
    
    try {
      // Search the list of all rooms for the one matching the name stored in the log
      final assignedRoom = roomTypes.firstWhere(
        (room) => room['name'] == assignedRoomName,
        // Using null as Map<String, dynamic> to safely return null if not found
        // ignore: cast_from_null_always_fails
        orElse: () => null as Map<String, dynamic>,
      );

      // If the room was found and it has a price, use it
      if (assignedRoom['price'] is double) {
        rate = assignedRoom['price'] as double;
      }
      
    } catch (e) {
      debugPrint('Error finding room rate for $assignedRoomName: $e');
      // 'rate' remains the default of 1500.0 if an error occurs
    }

    // 4. Update state with the correct rate
    setState(() {
      _consumption = consumption;
      _roomRate = rate; // Uses the rate of the assigned room
      _isLoading = false;
    });
  }
  // ----------------------------------------

  // --- Calculation Logic (Unchanged) ---
  int _calculateNights(Map<String, dynamic> data) {
    try {
      final DateTime arrival = DateTime.parse(data['arrivalDate']);
      // Use today's date/time for calculation if not explicitly checked out
      final String checkoutDateString = data['checkOutDate']?.toString().substring(0, 10) ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
      final DateTime checkout = DateTime.parse(checkoutDateString);

      final Duration stayDuration = checkout.difference(arrival);
      // If checkout is after arrival, duration is correct.
      // Add 1 to include the arrival day/first night.
      final int nights = stayDuration.inDays; 
      
      // Minimum 1 night
      return nights >= 0 ? nights + 1 : 1; 

    } catch (e) {
      return 1;
    }
  }

  double _calculateTotalRoomCost() {
    final nights = _calculateNights(widget.logData);
    return nights * _roomRate;
  }

  double _calculateTotalFoodCost() {
    return _consumption.fold(0.0, (sum, item) {
      final price = (item['pricePerUnit'] as double? ?? 0.0);
      final quantity = (item['quantity'] as int? ?? 0);
      return sum + (price * quantity);
    });
  }

  double _calculateGrandTotal() {
    final roomCost = _calculateTotalRoomCost();
    final foodCost = _calculateTotalFoodCost();
    return roomCost + foodCost;
  }

  // --- UI Helpers (Unchanged) ---

  Widget _buildSummaryRow(String title, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              fontSize: isTotal ? 18 : 16,
              color: isTotal ? primaryColor : Colors.black87,
            ),
          ),
          Text(
            'Rs. ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              fontSize: isTotal ? 18 : 16,
              color: isTotal ? primaryColor : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nights = _calculateNights(widget.logData);
    final roomCost = _calculateTotalRoomCost();
    final foodCost = _calculateTotalFoodCost();
    final grandTotal = _calculateGrandTotal();

    return AlertDialog(
      title: Text('Bill for ${widget.logData['name']}', style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
      content: _isLoading
          ? const SizedBox(height: 150, child: Center(child: CircularProgressIndicator(color: primaryColor)))
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Room Summary ---
                  Text('Room: ${widget.logData['roomNumber']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Divider(),
                  _buildSummaryRow('Rate per Night', _roomRate),
                  _buildSummaryRow('Total Nights', nights.toDouble()),
                  _buildSummaryRow('Room Total', roomCost),
                  
                  const Divider(height: 20),
                  
                  // --- Food Consumption ---
                  const Text('Food Consumption:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  if (_consumption.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('No food/service consumption logged.'),
                    )
                  else
                    ..._consumption.map((item) {
                      final total = (item['pricePerUnit'] * item['quantity']);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${item['foodName']} x ${item['quantity']}', style: const TextStyle(fontSize: 14)),
                            Text('Rs. ${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      );
                    }), // Add .toList() here to map the iterable to a List<Widget>
                  _buildSummaryRow('Food Total', foodCost),
                  
                  const Divider(height: 30, thickness: 2, color: primaryColor),
                  _buildSummaryRow('GRAND TOTAL', grandTotal, isTotal: true),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () {
            // Logic to mark as paid/checked out goes here
            Navigator.pop(context, true); 
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          child: const Text('Finalize Payment'),
        ),
      ],
    );
  }
}