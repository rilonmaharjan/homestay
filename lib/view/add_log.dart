import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../database/database_helper.dart';
import 'package:intl/intl.dart';

class AddLogPage extends StatefulWidget {
  const AddLogPage({super.key});

  @override
  State<AddLogPage> createState() => _AddLogPageState();
}

class _AddLogPageState extends State<AddLogPage> {
  // Use the same modern color scheme
  static const Color primaryColor = Color(0xFF4A148C); // Deep Purple 
  static const Color backgroundColor = Color(0xFFF0F4F8); // Off-white/light gray

  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  // controllers
  final TextEditingController _name = TextEditingController();
  final TextEditingController _address = TextEditingController();
  DateTime? _arrivalDate;
  TimeOfDay? _checkInTime;
  final TextEditingController _citizenNumber = TextEditingController();
  final TextEditingController _occupation = TextEditingController();
  final TextEditingController _numberOfGuests = TextEditingController();
  final TextEditingController _relationWithPartner = TextEditingController();
  final TextEditingController _reasonOfStay = TextEditingController();
  final TextEditingController _contactNumber = TextEditingController();
  final TextEditingController _roomNumber = TextEditingController();
  DateTime? _checkOutDate;
  TimeOfDay _checkOutTime = const TimeOfDay(hour: 12, minute: 0); // default 12:00 PM

  File? _citizenImageFile;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Pre-populate sensible defaults
    _arrivalDate = DateTime.now();
    _checkInTime = TimeOfDay.now();
    _checkOutDate = DateTime.now().add(const Duration(days: 1));
  }

  // --- Image Handling ---
  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      // Create a unique file name
      final fileName = '${_name.text.trim().isNotEmpty ? _name.text.trim() : 'guest'}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      // Note: In a real Flutter app, you'd use path_provider to get a temp directory for copies.
      // For this environment, we rely on the simulator's file system structure.
      try {
        final saved = await File(picked.path).copy(fileName);
        setState(() => _citizenImageFile = saved);
      } catch (e) {
        // Handle error if copy fails (e.g., in a constrained environment)
        setState(() => _citizenImageFile = File(picked.path));
      }
    }
  }

  // --- Date & Time Pickers ---
  Future<void> _pickArrivalDate() async {
    final now = DateTime.now();
    final r = await showDatePicker(
      context: context,
      initialDate: _arrivalDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: ThemeData(
          colorScheme: ColorScheme.light(primary: primaryColor),
        ),
        child: child!,
      ),
    );
    if (r != null) setState(() => _arrivalDate = r);
  }

  Future<void> _pickCheckInTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _checkInTime ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: ThemeData(
          colorScheme: ColorScheme.light(primary: primaryColor),
        ),
        child: child!,
      ),
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
      builder: (context, child) => Theme(
        data: ThemeData(
          colorScheme: ColorScheme.light(primary: primaryColor),
        ),
        child: child!,
      ),
    );
    if (r != null) setState(() => _checkOutDate = r);
  }

  Future<void> _pickCheckOutTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _checkOutTime,
      builder: (context, child) => Theme(
        data: ThemeData(
          colorScheme: ColorScheme.light(primary: primaryColor),
        ),
        child: child!,
      ),
    );
    if (t != null) setState(() => _checkOutTime = t);
  }

  // --- Utility ---
  String _timeOfDayToString(TimeOfDay t) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    return DateFormat.jm().format(dt);
  }

  // --- Save Logic ---
  Future<void> _save() async {
    // 1. Validation checks remain the same
    if (!_formKey.currentState!.validate()) return;
    if (_arrivalDate == null || _checkInTime == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select both Arrival Date and Check-in Time.')),
        );
      }
      return;
    }

    // 2. Start loading state
    setState(() => _saving = true);

    // 3. Prepare data variables
    final createdAt = DateTime.now().toIso8601String();
    // We keep the local path for local retrieval, but remove the driveLink variable
    String localPath = _citizenImageFile?.path ?? ''; 

    // 4. Construct the data map, excluding the driveLink variable and any related logic
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
      'checkOutDate': _checkOutDate?.toIso8601String().substring(0, 10) ?? '',
      'checkOutTime': _timeOfDayToString(_checkOutTime),
      'citizenImageLocalPath': localPath,
      'citizenImageDriveLink': '', 
      'createdAt': createdAt,
    };

    // 5. Insert into the local database
    try {
      await DatabaseHelper.instance.insertLog(data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save log. Check console for details.')),
        );
      }
    }


    // 6. Stop loading state and navigate back
    setState(() => _saving = false);
    if (mounted) Navigator.of(context).pop();
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

  // --- Custom Widgets for Modern UI ---

  Widget _buildTextField(TextEditingController c, String label, {TextInputType? keyboardType, String? Function(String?)? validator, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: c,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon, color: primaryColor.withValues(alpha:0.7)) : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
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
            border: Border.all(color: primaryColor.withValues(alpha:0.2), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha:0.05),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: primaryColor.withValues(alpha:0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(icon, size: 20, color: primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      valueText,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
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
              style: const TextStyle(
                fontSize: 20,
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
        title: const Text(
          'Add New Homestay Log',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                  _buildTextField(
                    _name,
                    'Full Name',
                    icon: Icons.person,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  ),
                  _buildTextField(
                    _address,
                    'Permanent Address',
                    icon: Icons.location_on,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Address is required' : null,
                  ),
                  _buildTextField(
                    _citizenNumber,
                    'ID/Citizen Number',
                    icon: Icons.badge,
                    keyboardType: TextInputType.text,
                  ),
                  _buildTextField(
                    _contactNumber,
                    'Contact Number',
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),

              // --- Booking Details Section ---
              _buildSectionCard(
                title: 'Booking Details',
                children: [
                  Row(
                    children: [
                      _buildDateTimeButton(
                        'Arrival Date',
                        Icons.calendar_today,
                        _arrivalDate == null ? 'Select Date' : DateFormat.yMd().format(_arrivalDate!),
                        _pickArrivalDate,
                      ),
                      const SizedBox(width: 10),
                      _buildDateTimeButton(
                        'Check-in Time',
                        Icons.access_time,
                        _checkInTime == null ? 'Select Time' : _timeOfDayToString(_checkInTime!),
                        _pickCheckInTime,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildDateTimeButton(
                        'Checkout Date',
                        Icons.calendar_today_outlined,
                        _checkOutDate == null ? 'Select Date' : DateFormat.yMd().format(_checkOutDate!),
                        _pickCheckOutDate,
                      ),
                      const SizedBox(width: 10),
                      _buildDateTimeButton(
                        'Checkout Time',
                        Icons.access_time_outlined,
                        _timeOfDayToString(_checkOutTime),
                        _pickCheckOutTime,
                      ),
                    ],
                  ),
                  _buildTextField(
                    _roomNumber,
                    'Room Number / Unit',
                    icon: Icons.meeting_room,
                  ),
                  _buildTextField(
                    _numberOfGuests,
                    'Number of Guests',
                    icon: Icons.people,
                    keyboardType: TextInputType.number,
                  ),
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
                  if (_citizenImageFile != null)
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_citizenImageFile!, width: 150, height: 150, fit: BoxFit.cover),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _citizenImageFile = null),
                          child: const Text(
                            'Remove Photo',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  SizedBox(height: _citizenImageFile != null ? 8 : 0),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo_camera_front, color: Colors.white),
                      label: Text(_citizenImageFile == null ? 'Select Citizen Photo' : 'Change Photo'),
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

              // --- Save Button ---
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
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
                      : const Text(
                          'Save Guest Log',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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