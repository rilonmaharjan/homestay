import 'package:flutter/material.dart';
import '../../database/database_helper.dart'; // Adjust path as needed

class MenuRateManagementPage extends StatefulWidget {
  const MenuRateManagementPage({super.key});

  @override
  State<MenuRateManagementPage> createState() => _MenuRateManagementPageState();
}

class _MenuRateManagementPageState extends State<MenuRateManagementPage> {
  static const Color primaryColor = Color(0xFF4A148C);
  List<Map<String, dynamic>> _foodItems = [];
  List<Map<String, dynamic>> _roomTypes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final items = await DatabaseHelper.instance.getAllFoodItems();
    // Fetch all room types instead of a single rate
    final rooms = await DatabaseHelper.instance.getAllRoomTypes(); 
    
    setState(() {
      _foodItems = items;
      _roomTypes = rooms;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu & Rate Management', style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Room Type Management Section ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Room Types & Pricing', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor)),
                      FloatingActionButton.small(
                        heroTag: 'add_room_tag',
                        onPressed: () => _showRoomTypeDialog(),
                        backgroundColor: primaryColor,
                        child: const Icon(Icons.add, color: Colors.white),
                      ),
                    ],
                  ),
                  const Divider(color: primaryColor),
                  
                  if (_roomTypes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Text('No room types defined. Tap + to add one.'),
                    )
                  else
                    ..._roomTypes.map((type) => Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      elevation: 1,
                      child: ListTile(
                        leading: const Icon(Icons.bed, color: primaryColor),
                        title: Text('${type['name']} (${type['quantity']} Rooms)'), 
                        subtitle: Text('Rate: Rs. ${type['price'].toStringAsFixed(2)} per night'),
                        trailing: const Icon(Icons.edit, color: Colors.blue),
                        onTap: () => _showRoomTypeDialog(type: type), // Tap to edit
                      ),
                    )),
                  
                  const SizedBox(height: 40),

                  // --- Food Item Management Section ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Food & Service Menu', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor)),
                      FloatingActionButton.small(
                        heroTag: 'add_food_tag',
                        onPressed: () => _showFoodItemDialog(),
                        backgroundColor: primaryColor,
                        child: const Icon(Icons.add, color: Colors.white),
                      ),
                    ],
                  ),
                  const Divider(color: primaryColor),

                  // --- Food Items List ---
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _foodItems.length,
                    itemBuilder: (context, index) {
                      final item = _foodItems[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        elevation: 1,
                        child: ListTile(
                          title: Text(item['name']),
                          subtitle: Text('Price: Rs. ${item['price'].toStringAsFixed(2)}'),
                          trailing: const Icon(Icons.edit, color: Colors.blue),
                          onTap: () => _showFoodItemDialog(item: item), // Tap to edit
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  
  // --- Room Type Management Dialog ---
  Future<void> _showRoomTypeDialog({Map<String, dynamic>? type}) async {
    final isEditing = type != null;
    final nameController = TextEditingController(text: type?['name']);
    final priceController = TextEditingController(text: type?['price']?.toStringAsFixed(2));
    final quantityController = TextEditingController(text: type?['quantity']?.toString());
    
    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Edit Room Type' : 'Add New Room Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Type Name (e.g., Deluxe)')),
            TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price per Night (Rs)')),
            TextField(controller: quantityController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity of Rooms of this Type')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(isEditing ? 'Update' : 'Add', style: const TextStyle(color: primaryColor))),
        ],
      ),
    );

    if (shouldSave == true) {
      final price = double.tryParse(priceController.text);
      final quantity = int.tryParse(quantityController.text); 
      final name = nameController.text.trim();

      // Combined, comprehensive validation check
      if (name.isNotEmpty && price != null && price >= 0 && quantity != null && quantity >= 0) {
        // Define 'row' only once with all valid data
        final Map<String, dynamic> row = {
          'name': name, 
          'price': price, 
          'quantity': quantity
        };
        
        try {
          if (isEditing && type['id'] != null) {
            // Update existing
            await DatabaseHelper.instance.updateRoomType(row, type['id']);
          } else {
            // Insert new
            await DatabaseHelper.instance.insertRoomType(row); 
          }

          // Assuming _loadData() is a method in your State class that reloads the room list
          _loadData(); 
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$name ${isEditing ? 'updated' : 'added'}!'))
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error saving room type: $e'))
            );
          }
        }
      } else {
        // Show error for invalid/missing input
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid input. Name, Price (>=0), and Quantity (>=0) are required.'))
          );
        }
      }
    }
  }

  Future<void> _showFoodItemDialog({Map<String, dynamic>? item}) async {
    final isEditing = item != null;
    final nameController = TextEditingController(text: item?['name']);
    final priceController = TextEditingController(text: item?['price']?.toStringAsFixed(2));
    
    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Edit Food Item' : 'Add New Food Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Item Name')),
            TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price (Rs)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(isEditing ? 'Update' : 'Add', style: const TextStyle(color: primaryColor))),
        ],
      ),
    );

    if (shouldSave == true) {
      final price = double.tryParse(priceController.text);
      final name = nameController.text.trim();
      if (name.isNotEmpty && price != null && price >= 0) {
        final Map<String, dynamic> row = {
          'name': name,
          'price': price,
          'isAvailable': 1, // Default to available
        };

        if (isEditing) {
        } else {
          await DatabaseHelper.instance.insertFoodItem(row); 
        }

        _loadData();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name ${isEditing ? 'updated' : 'added'}!')));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid input.')));
      }
    }
  }
}