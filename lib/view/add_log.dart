import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../database/database_helper.dart'; // Ensure correct path
import 'package:intl/intl.dart';

// --- Utility Functions (Ensure these are defined somewhere accessible) ---
// Note: This helper is repeated here for completeness, but should ideally be
// in a separate utils file or the DatabaseHelper itself.
String _timeOfDayToString(TimeOfDay t) {
  final now = DateTime.now();
  final dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
  // Using 'HH:mm' for database storage is often better, but keeping 'jm' for display consistency
  return DateFormat.jm().format(dt); 
}

TimeOfDay _stringToTimeOfDay(String timeString) {
  try {
    // Attempt to parse various formats (assuming it might come from DB or input)
    final format = DateFormat.jm(); 
    final dt = format.parse(timeString);
    return TimeOfDay.fromDateTime(dt);
  } catch (_) {
    // Fallback if parsing fails (e.g., if DB stores "HH:mm")
    final parts = timeString.split(':');
    if (parts.length == 2) {
      return TimeOfDay(hour: int.tryParse(parts[0]) ?? 0, minute: int.tryParse(parts[1]) ?? 0);
    }
    return TimeOfDay.now();
  }
}
// ---------------------------------------------------------------------

class UpsertLogPage extends StatefulWidget {
  // Use optional parameters for editing
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

  // Controllers (now late and initialized in initState)
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _citizenNumber;
  late final TextEditingController _occupation;
  late final TextEditingController _numberOfGuests;
  late final TextEditingController _relationWithPartner;
  late final TextEditingController _reasonOfStay;
  late final TextEditingController _contactNumber;
  late final TextEditingController _roomNumber;
  
  // Date/Time variables
  DateTime? _arrivalDate;
  TimeOfDay? _checkInTime;
  DateTime? _checkOutDate;
  TimeOfDay? _checkOutTime; // Now nullable, default value set in initState

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
    _roomNumber = TextEditingController(text: data?['roomNumber'] ?? '');

    // --- Date/Time Initialization ---
    if (isEditing && data != null) {
      // Load existing data for editing
      _arrivalDate = DateTime.tryParse(data['arrivalDate'] ?? '') ?? DateTime.now();
      _checkInTime = _stringToTimeOfDay(data['checkInTime'] ?? '12:00 PM');
      _checkOutDate = DateTime.tryParse(data['checkOutDate'] ?? '') ?? DateTime.now().add(const Duration(days: 1));
      _checkOutTime = _stringToTimeOfDay(data['checkOutTime'] ?? '12:00 PM');
      _citizenImageBytes = data['citizenImageBlob'] as Uint8List?;
    } else {
      // Set sensible defaults for new log
      _arrivalDate = DateTime.now();
      _checkInTime = TimeOfDay.now();
      _checkOutDate = DateTime.now().add(const Duration(days: 1));
      _checkOutTime = const TimeOfDay(hour: 12, minute: 0);
    }
  }

  // --- Image Handling ---
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

  // --- Date & Time Pickers (Logic remains mostly the same) ---
  Future<void> _pickArrivalDate() async {
    final now = DateTime.now();
    final r = await showDatePicker(
      context: context,
      initialDate: _arrivalDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(data: ThemeData(colorScheme: ColorScheme.light(primary: primaryColor)), child: child!),
    );
    if (r != null) setState(() => _arrivalDate = r);
  }

  Future<void> _pickCheckInTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _checkInTime ?? TimeOfDay.now(),
      builder: (context, child) => Theme(data: ThemeData(colorScheme: ColorScheme.light(primary: primaryColor)), child: child!),
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
      builder: (context, child) => Theme(data: ThemeData(colorScheme: ColorScheme.light(primary: primaryColor)), child: child!),
    );
    if (r != null) setState(() => _checkOutDate = r);
  }

  Future<void> _pickCheckOutTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _checkOutTime ?? const TimeOfDay(hour: 12, minute: 0),
      builder: (context, child) => Theme(data: ThemeData(colorScheme: ColorScheme.light(primary: primaryColor)), child: child!),
    );
    if (t != null) setState(() => _checkOutTime = t);
  }

  // --- Save/Update Logic ---
  Future<void> _handleUpsert() async {
    if (!_formKey.currentState!.validate()) return;
    if (_arrivalDate == null || _checkInTime == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select Arrival Date and Check-in Time.')));
      }
      return;
    }

    setState(() => _saving = true);

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
      'roomNumber': _roomNumber.text.trim(),
      'checkOutDate': checkOutDateStr,
      'checkOutTime': checkOutTimeStr,
      'citizenImageBlob': _citizenImageBytes, // Use the BLOB bytes
      'citizenImageDriveLink': widget.initialData?['citizenImageDriveLink'] ?? '', // Preserve existing link or default to empty
    };

    // 3. Insert or Update
    try {
      if (isEditing) {
        await DatabaseHelper.instance.updateLog(widget.logId!, data);
      } else {
        // Only set createdAt for new records
        data['createdAt'] = DateTime.now().toIso8601String();
        await DatabaseHelper.instance.insertLog(data);
      }
      
      // Signal success and pop
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Log ${isEditing ? 'updated' : 'saved'} successfully!')),
        );
        Navigator.of(context).pop(true); // Return true to signal success/refresh needed
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
    _roomNumber.dispose();
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
                  _buildTextField(_roomNumber, 'Room Number / Unit', icon: Icons.meeting_room),
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