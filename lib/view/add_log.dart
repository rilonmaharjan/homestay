import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../database/database_helper.dart'; // Ensure correct path
import 'package:intl/intl.dart';
class UpsertLogPage extends StatefulWidget {
  final int? logId;
  final Map<String, dynamic>? initialData;

  const UpsertLogPage({
    super.key,
    this.logId,
    this.initialData,
  });

  @override
  State<UpsertLogPage> createState() => _UpsertLogPageState();
}

class _UpsertLogPageState extends State<UpsertLogPage> {
  static const Color primaryColor = Color(0xFF4A148C);
  static const Color backgroundColor = Color(0xFFF0F4F8);

  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  // Controllers
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _citizenNumber;
  late final TextEditingController _occupation;
  late final TextEditingController _numberOfGuests;
  late final TextEditingController _relationWithPartner;
  late final TextEditingController _reasonOfStay;
  late final TextEditingController _contactNumber;

  // --- ROOM SELECTION (Updated to use ID for stability) ---
  List<Map<String, dynamic>> _roomTypes = [];
  int? _selectedRoomTypeId; // Store the unique ID of the selected room
  bool _isLoadingRooms = true;
  
  // Date/Time variables
  DateTime? _arrivalDate;
  TimeOfDay? _checkInTime;
  DateTime? _checkOutDate;
  TimeOfDay? _checkOutTime;

  Uint8List? _citizenImageBytes;
  bool _saving = false;

  bool get isEditing => widget.logId != null;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;

    // --- Controller Initialization ---
    _name = TextEditingController(text: data?['name'] ?? '');
    _address = TextEditingController(text: data?['address'] ?? '');
    _citizenNumber = TextEditingController(text: data?['citizenNumber'] ?? '');
    _occupation = TextEditingController(text: data?['occupation'] ?? '');
    _numberOfGuests = TextEditingController(text: data?['numberOfGuests']?.toString() ?? '');
    _relationWithPartner = TextEditingController(text: data?['relationWithPartner'] ?? '');
    _reasonOfStay = TextEditingController(text: data?['reasonOfStay'] ?? '');
    _contactNumber = TextEditingController(text: data?['contactNumber'] ?? '');
    
    // Load room types and attempt to pre-select
    _loadRoomTypes(data?['roomNumber']);

    // --- Date/Time Initialization ---
    if (isEditing && data != null) {
      _arrivalDate = DateTime.tryParse(data['arrivalDate'] ?? '') ?? DateTime.now();
      _checkInTime = _stringToTimeOfDay(data['checkInTime'] ?? '12:00 PM');
      _checkOutDate = DateTime.tryParse(data['checkOutDate'] ?? '') ?? DateTime.now().add(const Duration(days: 1));
      _checkOutTime = _stringToTimeOfDay(data['checkOutTime'] ?? '12:00 PM');
      _citizenImageBytes = data['citizenImageBlob'] as Uint8List?;
    } else {
      _arrivalDate = DateTime.now();
      _checkInTime = TimeOfDay.now();
      _checkOutDate = DateTime.now().add(const Duration(days: 1));
      _checkOutTime = const TimeOfDay(hour: 12, minute: 0);
    }
  }

  // --- UPDATED ROOM LOADING LOGIC (Uses Room Name to find ID) ---
  Future<void> _loadRoomTypes(String? currentRoomName) async {
    // Use current selected dates or defaults for availability check
    final checkArrival = _arrivalDate?.toIso8601String() ?? DateTime.now().toIso8601String();
    final checkCheckout = _checkOutDate?.toIso8601String() ?? DateTime.now().add(const Duration(days: 1)).toIso8601String();

    // 1. Fetch all defined room types (Name, Price, Total Quantity)
    final allRooms = await DatabaseHelper.instance.getAllRoomTypes();
    
    // 2. Fetch all booked counts for the current date range (Name, Booked Count)
    final bookedCounts = await DatabaseHelper.instance.getBookedRoomCounts(
      checkArrival, 
      checkCheckout, 
      excludeLogId: widget.logId,
    );

    // Convert bookedCounts list to a map for quick lookup: {roomName: bookedCount}
    final bookedMap = {
      for (var item in bookedCounts) item['roomNumber'] as String: item['bookedCount'] as int
    };
    
    // 3. Calculate Available Rooms and filter the list
    final availableRooms = <Map<String, dynamic>>[];
    int? matchedId;

    for (var room in allRooms) {
      final roomName = room['name'] as String;
      final totalQuantity = room['quantity'] as int? ?? 0;
      final bookedQuantity = bookedMap[roomName] ?? 0;
      
      final availableQuantity = totalQuantity - bookedQuantity;

      // Check if the room is available or if it's the room currently being edited
      if (availableQuantity > 0 || (currentRoomName == roomName)) {
        // Add the room to the available list, including the computed availability
        availableRooms.add({...room, 'availableCount': availableQuantity});

        // If editing, find the ID of the current room
        if (currentRoomName == roomName) {
          matchedId = room['id'] as int;
        }
      }
    }
    
    setState(() {
      _roomTypes = availableRooms;
      _isLoadingRooms = false;
      
      // Set the selected ID based on editing status or default
      if (matchedId != null) {
        _selectedRoomTypeId = matchedId;
      } else if (_selectedRoomTypeId == null && _roomTypes.isNotEmpty && !isEditing) {
        // Default to the first available room if adding a new log
        _selectedRoomTypeId = _roomTypes.first['id'] as int;
      } else if (matchedId == null && currentRoomName != null && isEditing) {
        // If the previously selected room is now unavailable, keep the ID 
        // but ensure it's still available in the dropdown (it should be, due to the '|| currentRoomName == roomName' check)
      }
    });
  }
    
  // --- Image Handling (Unchanged) ---
  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _citizenImageBytes = bytes;
      });
    }
  }

  // --- Date & Time Pickers (Unchanged) ---
  Future<void> _pickArrivalDate() async {
    final now = DateTime.now();
    final r = await showDatePicker(
      context: context,
      initialDate: _arrivalDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(data: ThemeData(colorScheme: const ColorScheme.light(primary: primaryColor)), child: child!),
    );
    if (r != null) {
      setState(() => _arrivalDate = r);
      // CRITICAL: Reload rooms after date changes
      _loadRoomTypes(widget.initialData?['roomNumber']); 
    }
  }

  Future<void> _pickCheckInTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _checkInTime ?? TimeOfDay.now(),
      builder: (context, child) => Theme(data: ThemeData(colorScheme: const ColorScheme.light(primary: primaryColor)), child: child!),
    );
    if (t != null) setState(() => _checkInTime = t);
  }

  Future<void> _pickCheckOutDate() async {
    final now = DateTime.now();
    final r = await showDatePicker(
      context: context,
      initialDate: _checkOutDate ?? now.add(const Duration(days: 1)),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(data: ThemeData(colorScheme: const ColorScheme.light(primary: primaryColor)), child: child!),
    );
    if (r != null) {
      setState(() => _checkOutDate = r);
      // CRITICAL: Reload rooms after date changes
      _loadRoomTypes(widget.initialData?['roomNumber']); 
    }
  }

  Future<void> _pickCheckOutTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _checkOutTime ?? const TimeOfDay(hour: 12, minute: 0),
      builder: (context, child) => Theme(data: ThemeData(colorScheme: const ColorScheme.light(primary: primaryColor)), child: child!),
    );
    if (t != null) setState(() => _checkOutTime = t);
  }

  // --- Save/Update Logic (Revised to find room name based on ID) ---
  Future<void> _handleUpsert() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validate room selection explicitly
    if (_selectedRoomTypeId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Room Type.')));
      }
      return;
    }
    if (_arrivalDate == null || _checkInTime == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select Arrival Date and Check-in Time.')));
      }
      return;
    }

    setState(() => _saving = true);

    // Look up the selected room object using the ID
    final selectedRoom = _roomTypes.firstWhere(
      (room) => room['id'] == _selectedRoomTypeId,
      orElse: () => throw Exception("Selected Room ID not found!"),
    );

    // 1. Prepare data variables
    final String checkOutDateStr = _checkOutDate?.toIso8601String().substring(0, 10) ?? '';
    final String checkOutTimeStr = _checkOutTime != null ? _timeOfDayToString(_checkOutTime!) : '';

    // 2. Construct the data map
    final data = {
      'name': _name.text.trim(),
      'address': _address.text.trim(),
      'arrivalDate': _arrivalDate!.toIso8601String(),
      'checkInTime': _timeOfDayToString(_checkInTime!),
      'citizenNumber': _citizenNumber.text.trim(),
      'occupation': _occupation.text.trim(),
      'numberOfGuests': int.tryParse(_numberOfGuests.text.trim()) ?? 0,
      'relationWithPartner': _relationWithPartner.text.trim(),
      'reasonOfStay': _reasonOfStay.text.trim(),
      'contactNumber': _contactNumber.text.trim(),
      
      // Use the name found via the selected ID
      'roomNumber': selectedRoom['name'], 
      
      'checkOutDate': checkOutDateStr,
      'checkOutTime': checkOutTimeStr,
      'citizenImageBlob': _citizenImageBytes, 
    };

    // 3. Insert or Update
    try {
      if (isEditing) {
        await DatabaseHelper.instance.updateLog(widget.logId!, data);
      } else {
        data['createdAt'] = DateTime.now().toIso8601String();
        await DatabaseHelper.instance.insertLog(data);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Log ${isEditing ? 'updated' : 'saved'} successfully!')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to ${isEditing ? 'update' : 'save'} log: $e')),
        );
      }
    }

    setState(() => _saving = false);
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _citizenNumber.dispose();
    _occupation.dispose();
    _numberOfGuests.dispose();
    _relationWithPartner.dispose();
    _reasonOfStay.dispose();
    _contactNumber.dispose();
    super.dispose();
  }

  // --- Custom Widgets (unchanged) ---
  Widget _buildTextField(TextEditingController c, String label, {TextInputType? keyboardType, String? Function(String?)? validator, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: c,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon, color: primaryColor.withValues(alpha: 0.7)) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildDateTimeButton(
      String label,
      IconData icon,
      String valueText,
      VoidCallback onPressed,
  ) {
    return Expanded(
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primaryColor.withValues(alpha: 0.2), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.05), spreadRadius: 1, blurRadius: 3, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: primaryColor.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(icon, size: 20, color: primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      valueText,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor),
            ),
            const Divider(color: primaryColor, thickness: 1, height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  // --- UPDATED ROOM PICKER WIDGET (Uses ID) ---
  Widget _buildRoomPicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Room Type / Unit',
          prefixIcon: const Icon(Icons.meeting_room, color: primaryColor),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
        isEmpty: _selectedRoomTypeId == null, // Check against ID
        child: DropdownButtonHideUnderline(
          child: DropdownButtonFormField<int>( // Change generic type to int
            value: _selectedRoomTypeId,
            decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
            isDense: true,
            isExpanded: true,
            
            // Display hint based on loading state or availability
            hint: _isLoadingRooms 
                ? const Text('Loading rooms...') 
                : _roomTypes.isEmpty 
                    ? const Text('No rooms available for selected dates') 
                    : const Text('Select Room Type'),
                    
            validator: (value) => value == null ? 'Please select a room type.' : null,
            
            items: _roomTypes.map((room) {
              final availableCount = room['availableCount'] as int;
              final isCurrentLogRoom = room['id'] == _selectedRoomTypeId && widget.logId != null;
              
              String displayText = '${room['name']} (Available: $availableCount)';
              
              // Special display text when the room is currently being edited
              if (isCurrentLogRoom && availableCount == 0) {
                // The room is fully booked, but the current log is using it.
                displayText = '${room['name']} (Currently Booked by this Log)';
              } else if (isCurrentLogRoom) {
                // Show the price for reference if it's the current log's room
                displayText = '${room['name']} (Current) - Rs.${room['price'].toStringAsFixed(2)}/night';
              }

              return DropdownMenuItem<int>(
                value: room['id'] as int, // Use ID as the value
                child: Text(displayText),
              );
            }).toList(),
            
            onChanged: (int? newId) { // Receive the ID
              setState(() {
                _selectedRoomTypeId = newId;
              });
            },
          ),
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
          isEditing ? 'Edit Log (ID: ${widget.logId})' : 'Add New Homestay Log',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // --- Guest Details Section ---
              _buildSectionCard(
                title: 'Guest Identity',
                children: [
                  _buildTextField(_name, 'Full Name', icon: Icons.person, validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null),
                  _buildTextField(_address, 'Permanent Address', icon: Icons.location_on, validator: (v) => (v == null || v.trim().isEmpty) ? 'Address is required' : null),
                  _buildTextField(_citizenNumber, 'ID/Citizen Number', icon: Icons.badge, keyboardType: TextInputType.text),
                  _buildTextField(_contactNumber, 'Contact Number', icon: Icons.phone, keyboardType: TextInputType.phone),
                ],
              ),

              // --- Booking Details Section ---
              _buildSectionCard(
                title: 'Booking Details',
                children: [
                  Row(
                    children: [
                      _buildDateTimeButton('Arrival Date', Icons.calendar_today, _arrivalDate == null ? 'Select Date' : DateFormat.yMd().format(_arrivalDate!), _pickArrivalDate),
                      const SizedBox(width: 10),
                      _buildDateTimeButton('Check-in Time', Icons.access_time, _checkInTime == null ? 'Select Time' : _timeOfDayToString(_checkInTime!), _pickCheckInTime),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildDateTimeButton('Checkout Date', Icons.calendar_today_outlined, _checkOutDate == null ? 'Select Date' : DateFormat.yMd().format(_checkOutDate!), _pickCheckOutDate),
                      const SizedBox(width: 10),
                      _buildDateTimeButton('Checkout Time', Icons.access_time_outlined, _checkOutTime == null ? 'Select Time' : _timeOfDayToString(_checkOutTime!), _pickCheckOutTime),
                    ],
                  ),
                  _buildRoomPicker(), // Uses updated widget
                  _buildTextField(_numberOfGuests, 'Number of Guests', icon: Icons.people, keyboardType: TextInputType.number),
                ],
              ),

              // --- Other Details Section ---
              _buildSectionCard(
                title: 'Other Information',
                children: [
                  _buildTextField(_occupation, 'Occupation', icon: Icons.work),
                  _buildTextField(_reasonOfStay, 'Reason of Stay', icon: Icons.info),
                  _buildTextField(_relationWithPartner, 'Relation with Partner', icon: Icons.people_alt_outlined),
                ],
              ),

              // --- Image Upload Section ---
              _buildSectionCard(
                title: 'Photo Proof',
                children: [
                  if (_citizenImageBytes != null)
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            _citizenImageBytes!,
                            width: 150,
                            height: 150,
                            fit: BoxFit.cover,
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _citizenImageBytes = null),
                          child: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  SizedBox(height: _citizenImageBytes != null ? 8 : 0),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo_camera_front, color: Colors.white),
                      label: Text(_citizenImageBytes == null ? 'Select Citizen Photo' : 'Change Photo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // --- Save/Update Button ---
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _handleUpsert,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 5,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                        )
                      : Text(
                          isEditing ? 'Update Guest Log' : 'Save New Guest Log',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

String _timeOfDayToString(TimeOfDay t) {
  final now = DateTime.now();
  final dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
  return DateFormat.jm().format(dt); 
}

TimeOfDay _stringToTimeOfDay(String timeString) {
  try {
    final format = DateFormat.jm(); 
    final dt = format.parse(timeString);
    return TimeOfDay.fromDateTime(dt);
  } catch (_) {
    final parts = timeString.split(':');
    if (parts.length == 2) {
      return TimeOfDay(hour: int.tryParse(parts[0]) ?? 0, minute: int.tryParse(parts[1]) ?? 0);
    }
    return TimeOfDay.now();
  }
}
