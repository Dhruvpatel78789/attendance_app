import 'package:flutter/material.dart';
import 'package:attendance_system/services/mongodb_service.dart';
import 'admin_dashboard.dart';

class AddStudentPage extends StatefulWidget {
  const AddStudentPage({super.key});
  @override State<AddStudentPage> createState() => _AddStudentPageState();
}

class _AddStudentPageState extends State<AddStudentPage> {
  final _grController      = TextEditingController();
  final _nameController    = TextEditingController();
  final _rollController    = TextEditingController();
  final _phoneController   = TextEditingController();
  final _addressController = TextEditingController();
  DateTime? dob;
  String? selectedClass, gender;
  bool loading = false;

  bool _validate() =>
      _grController.text.trim().isNotEmpty && _nameController.text.trim().isNotEmpty &&
          _phoneController.text.trim().isNotEmpty && _addressController.text.trim().isNotEmpty &&
          selectedClass != null && dob != null && gender != null;

  Future<void> _saveStudent() async {
    if (!_validate()) { _snack("Fill all required fields"); return; }
    final gr = _grController.text.trim();
    final doc = await FirebaseFirestore.instance.collection('students').doc(gr).get();
    if (doc.exists) { _showDuplicateDialog(gr); return; }
    await _createStudent(gr);
  }

  Future<void> _createStudent(String gr) async {
    setState(() => loading = true);
    await FirebaseFirestore.instance.collection('students').doc(gr).set({
      'name': _nameController.text.trim(), 'phone': _phoneController.text.trim(),
      'address': _addressController.text.trim(),
      'rollNo': _rollController.text.trim().isEmpty ? null : int.parse(_rollController.text.trim()),
      'classId': selectedClass, 'dob': dob!.toIso8601String(),
      'gender': gender, 'grNumber': gr, 'createdAt': FieldValue.serverTimestamp(),
    });
    setState(() => loading = false);
    _snack("Student saved");
    _clearFields();
  }

  void _showDuplicateDialog(String existingGr) {
    final newGrController = TextEditingController();
    showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
      backgroundColor: AppTheme.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text("GR Already Exists", style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text("Overwrite → Replace\nReassign → Move old to new GR", style: TextStyle(color: AppTheme.textDark.withOpacity(0.7), fontSize: 13)),
        const SizedBox(height: 12),
        TextField(controller: newGrController, decoration: const InputDecoration(labelText: "New GR (for Reassign)")),
      ]),
      actions: [
        TextButton(child: Text("Overwrite", style: TextStyle(color: AppTheme.primary)), onPressed: () async {
          await FirebaseFirestore.instance.collection('students').doc(existingGr).set({
            'name': _nameController.text.trim(), 'phone': _phoneController.text.trim(),
            'address': _addressController.text.trim(),
            'rollNo': _rollController.text.trim().isEmpty ? null : int.parse(_rollController.text.trim()),
            'classId': selectedClass, 'dob': dob!.toIso8601String(),
            'gender': gender, 'grNumber': existingGr, 'createdAt': FieldValue.serverTimestamp(),
          });
          Navigator.pop(context); _clearFields();
        }),
        TextButton(child: Text("Reassign", style: TextStyle(color: AppTheme.primary)), onPressed: () async {
          final newGr = newGrController.text.trim();
          if (newGr.isEmpty || newGr == existingGr) { _snack("Invalid GR"); return; }
          final check = await FirebaseFirestore.instance.collection('students').doc(newGr).get();
          if (check.exists) { _snack("New GR exists"); return; }
          final oldDoc = await FirebaseFirestore.instance.collection('students').doc(existingGr).get();
          final oldData = oldDoc.data();
          if (oldData != null) await FirebaseFirestore.instance.collection('students').doc(newGr).set({...oldData, 'grNumber': newGr});
          await FirebaseFirestore.instance.collection('students').doc(existingGr).set({
            'name': _nameController.text.trim(), 'phone': _phoneController.text.trim(),
            'address': _addressController.text.trim(),
            'rollNo': _rollController.text.trim().isEmpty ? null : int.parse(_rollController.text.trim()),
            'classId': selectedClass, 'dob': dob!.toIso8601String(),
            'gender': gender, 'grNumber': existingGr, 'createdAt': FieldValue.serverTimestamp(),
          });
          Navigator.pop(context); _clearFields();
        }),
        TextButton(child: const Text("Cancel"), onPressed: () => Navigator.pop(context)),
      ],
    ));
  }

  void _clearFields() {
    _grController.clear(); _nameController.clear(); _rollController.clear();
    _phoneController.clear(); _addressController.clear();
    setState(() { selectedClass = null; dob = null; gender = null; });
  }

  Future<void> _pickDOB() async {
    final picked = await showDatePicker(context: context, firstDate: DateTime(1990), lastDate: DateTime.now(), initialDate: DateTime(2010));
    if (picked != null) setState(() => dob = picked);
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.bgDecoration,
        child: SafeArea(
          child: Column(
            children: [
              WarliAppBar(title: "Add Student"),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      WarliBanner(icon: Icons.person_add_alt_1_rounded, title: "New Student", subtitle: "Register a student manually"),
                      const SizedBox(height: 24),

                      WarliSectionTitle(title: "IDENTIFICATION"),
                      const SizedBox(height: 10),
                      WarliField(controller: _grController, label: "GR Number", icon: Icons.badge_rounded, required: true),
                      const SizedBox(height: 10),
                      WarliField(controller: _nameController, label: "Student Name", icon: Icons.person_rounded, required: true),

                      const SizedBox(height: 20),
                      WarliSectionTitle(title: "CONTACT & ADDRESS"),
                      const SizedBox(height: 10),
                      WarliField(controller: _phoneController, label: "Phone", icon: Icons.phone_rounded, keyboard: TextInputType.phone, required: true),
                      const SizedBox(height: 10),
                      WarliField(controller: _addressController, label: "Address", icon: Icons.home_rounded, required: true),

                      const SizedBox(height: 20),
                      WarliSectionTitle(title: "CLASS & DETAILS"),
                      const SizedBox(height: 10),
                      WarliField(controller: _rollController, label: "Roll Number (optional)", icon: Icons.format_list_numbered_rounded, keyboard: TextInputType.number),
                      const SizedBox(height: 10),

                      // Gender
                      WarliDropdown(child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: gender, isExpanded: true,
                          dropdownColor: AppTheme.cardBg,
                          hint: Row(children: [
                            Icon(Icons.wc_rounded, color: AppTheme.primary.withOpacity(0.55), size: 20),
                            const SizedBox(width: 12),
                            Text("Gender *", style: TextStyle(color: AppTheme.textDark.withOpacity(0.5), fontSize: 13)),
                          ]),
                          items: [
                            DropdownMenuItem(value: 'male',   child: Text("Male",   style: TextStyle(color: AppTheme.textDark))),
                            DropdownMenuItem(value: 'female', child: Text("Female", style: TextStyle(color: AppTheme.textDark))),
                          ],
                          onChanged: (v) => setState(() => gender = v),
                        ),
                      )),
                      const SizedBox(height: 10),

                      // DOB picker
                      GestureDetector(
                        onTap: _pickDOB,
                        child: WarliDropdown(child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(children: [
                            Icon(Icons.cake_rounded, color: AppTheme.primary.withOpacity(0.55), size: 20),
                            const SizedBox(width: 12),
                            Text(
                              dob == null ? "Date of Birth *" : dob.toString().split(' ')[0],
                              style: TextStyle(color: dob == null ? AppTheme.textDark.withOpacity(0.5) : AppTheme.textDark, fontSize: 14),
                            ),
                            const Spacer(),
                            Icon(Icons.edit_calendar_rounded, color: AppTheme.primary.withOpacity(0.4), size: 17),
                          ]),
                        )),
                      ),
                      const SizedBox(height: 10),

                      // Class
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('classes').snapshots(),
                        builder: (_, snap) {
                          if (!snap.hasData) return const SizedBox();
                          return WarliDropdown(child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedClass, isExpanded: true,
                              dropdownColor: AppTheme.cardBg,
                              hint: Row(children: [
                                Icon(Icons.school_rounded, color: AppTheme.primary.withOpacity(0.55), size: 20),
                                const SizedBox(width: 12),
                                Text("Select Class *", style: TextStyle(color: AppTheme.textDark.withOpacity(0.5), fontSize: 13)),
                              ]),
                              items: snap.data!.docs.map((e) => DropdownMenuItem(
                                value: e.id,
                                child: Text(e.id, style: TextStyle(color: AppTheme.textDark)),
                              )).toList(),
                              onChanged: (v) => setState(() => selectedClass = v),
                            ),
                          ));
                        },
                      ),

                      const SizedBox(height: 30),
                      WarliButton(label: "Save Student", loading: loading, onPressed: _saveStudent),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}