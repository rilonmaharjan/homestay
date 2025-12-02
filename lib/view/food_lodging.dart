// lib/widgets/food_logging_dialog.dart

import 'package:flutter/material.dart';
import '../database/database_helper.dart'; 

class FoodLoggingDialog extends StatefulWidget {
  final int logId;

  const FoodLoggingDialog({super.key, required this.logId});

  @override
  State<FoodLoggingDialog> createState() => _FoodLoggingDialogState();
}

class _FoodLoggingDialogState extends State<FoodLoggingDialog> {
  static const Color primaryColor = Color(0xFF4A148C);
  List<Map<String, dynamic>> _foodMenu = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    final menu = await DatabaseHelper.instance.getAllFoodItems();
    setState(() {
      _foodMenu = menu.where((item) => item['isAvailable'] == 1).toList();
      _isLoading = false;
    });
  }

  Future<void> _logConsumption(Map<String, dynamic> item) async {
    int quantity = 1;

    final bool? shouldLog = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Log ${item['name']}'),
        content: TextField(
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Quantity', hintText: '1'),
          onChanged: (v) {
            quantity = int.tryParse(v) ?? 1;
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add', style: TextStyle(color: primaryColor))),
        ],
      ),
    );

    if (shouldLog == true && quantity > 0) {
      final row = {
        'logId': widget.logId,
        'foodItemId': item['id'],
        'quantity': quantity,
        'pricePerUnit': item['price'],
      };
      await DatabaseHelper.instance.insertGuestConsumption(row);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logged $quantity x ${item['name']} for Guest ID ${widget.logId}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Log Food & Services'),
      content: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : _foodMenu.isEmpty
              ? const Text('No food items available. Please add them in the Management settings.')
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _foodMenu.length,
                    itemBuilder: (context, index) {
                      final item = _foodMenu[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        elevation: 1,
                        child: ListTile(
                          title: Text(item['name']),
                          subtitle: Text('\$${item['price'].toStringAsFixed(2)}'),
                          trailing: const Icon(Icons.add_circle, color: primaryColor),
                          onTap: () {
                            Navigator.pop(context); // Close the main dialog first
                            _logConsumption(item);
                          }
                        ),
                      );
                    },
                  ),
                ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close', style: TextStyle(color: primaryColor)),
        ),
      ],
    );
  }
}