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
  Map<int, int> _quantities = {}; // Stores {foodItemId: quantity}
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    final menu = await DatabaseHelper.instance.getAllFoodItems();
    
    // Initialize quantities map for tracking
    final initialQuantities = <int, int>{};
    for (var item in menu) {
      // Ensure 'id' is int; use a placeholder if it's null for safety, though unlikely
      final id = item['id'] as int? ?? 0; 
      if (id != 0) {
        initialQuantities[id] = 0;
      }
    }
    
    setState(() {
      _foodMenu = menu.where((item) => item['isAvailable'] == 1).toList();
      _quantities = initialQuantities;
      _isLoading = false;
    });
  }
  
  // --- Quantity Management Logic ---
  void _updateQuantity(int foodItemId, int change) {
    setState(() {
      final currentQuantity = _quantities[foodItemId] ?? 0;
      final newQuantity = currentQuantity + change;
      // Prevent quantity from dropping below zero
      _quantities[foodItemId] = newQuantity.clamp(0, 99); 
    });
  }

  // --- Save Logic ---
  Future<void> _handleSaveConsumption() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    final logsToInsert = <Map<String, dynamic>>[];
    
    // 1. Prepare data for all items with quantity > 0
    for (var item in _foodMenu) {
      final id = item['id'] as int;
      final quantity = _quantities[id] ?? 0;

      if (quantity > 0) {
        logsToInsert.add({
          'logId': widget.logId,
          'foodItemId': id,
          'quantity': quantity,
          'pricePerUnit': item['price'],
        });
      }
    }

    // 2. Insert into database
    try {
      if (logsToInsert.isNotEmpty) {
        await DatabaseHelper.instance.bulkInsertGuestConsumption(logsToInsert);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Successfully logged ${logsToInsert.length} item(s) for Guest ID ${widget.logId}')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No items selected to log.')),
          );
        }
      }
      // 3. Close the dialog
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to log consumption: $e')),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
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
                  // Adjusted height to prevent overflow and provide a scrollable list
                  height: MediaQuery.of(context).size.height * 0.6, 
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _foodMenu.length,
                    itemBuilder: (context, index) {
                      final item = _foodMenu[index];
                      final itemId = item['id'] as int;
                      final quantity = _quantities[itemId] ?? 0;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        elevation: 1,
                        child: ListTile(
                          title: Text(item['name']),
                          subtitle: Text('\$${item['price'].toStringAsFixed(2)}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Minus Button
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => _updateQuantity(itemId, -1),
                                color: quantity > 0 ? Colors.red : Colors.grey,
                              ),
                              
                              // Quantity Display
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text(
                                  '$quantity',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ),

                              // Plus Button
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: primaryColor),
                                onPressed: () => _updateQuantity(itemId, 1),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _handleSaveConsumption,
          icon: _isSaving 
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.save),
          label: Text(_isSaving ? 'Saving...' : 'Save & Log'),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor, 
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}