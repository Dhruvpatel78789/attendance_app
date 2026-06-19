import 'package:flutter/material.dart';
import 'package:attendance_system/services/mongodb_service.dart';
import 'admin_dashboard.dart';

class AddClassPage extends StatefulWidget {
  const AddClassPage({super.key});
  @override State<AddClassPage> createState() => _AddClassPageState();
}

class _AddClassPageState extends State<AddClassPage> {
  final _nameController  = TextEditingController();
  final _totalController = TextEditingController();
  final _boysController  = TextEditingController();
  final _girlsController = TextEditingController();
  bool loading = false, isUpdating = false;

  void _updateCounts({required String changedField}) {
    if (isUpdating) return;
    isUpdating = true;
    final total = int.tryParse(_totalController.text) ?? 0;
    final boys  = int.tryParse(_boysController.text);
    final girls = int.tryParse(_girlsController.text);
    if (total == 0) { isUpdating = false; return; }
    if (changedField == 'boys' && boys != null) {
      final g = total - boys; if (g >= 0) _girlsController.text = g.toString();
    } else if (changedField == 'girls' && girls != null) {
      final b = total - girls; if (b >= 0) _boysController.text = b.toString();
    } else if (changedField == 'total') {
      if (boys != null) { final g = total - boys; if (g >= 0) _girlsController.text = g.toString(); }
      else if (girls != null) { final b = total - girls; if (b >= 0) _boysController.text = b.toString(); }
    }
    isUpdating = false;
  }

  Future<void> _saveClass() async {
    final name  = _nameController.text.trim();
    final total = int.tryParse(_totalController.text.trim());
    final boys  = int.tryParse(_boysController.text.trim());
    final girls = int.tryParse(_girlsController.text.trim());
    if (name.isEmpty || total == null || boys == null || girls == null) { _snack("Please fill all fields"); return; }
    if (boys + girls != total) { _snack("Boys + Girls must equal Total"); return; }
    setState(() => loading = true);
    await FirebaseFirestore.instance.collection('classes').doc(name).set({
      'name': name, 'totalStudents': total, 'boys': boys, 'girls': girls,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    setState(() => loading = false);
    if (!mounted) return;
    _snack("Class saved!");
    _nameController.clear(); _totalController.clear(); _boysController.clear(); _girlsController.clear();
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
              WarliAppBar(title: "Add / Edit Class"),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      WarliBanner(icon: Icons.class_rounded, title: "Class Setup", subtitle: "Create or update a class record"),
                      const SizedBox(height: 24),
                      WarliSectionTitle(title: "CLASS DETAILS"),
                      const SizedBox(height: 10),
                      WarliField(controller: _nameController, label: "Class Name (e.g. 10-A)", icon: Icons.school_rounded),
                      const SizedBox(height: 10),
                      WarliField(controller: _totalController, label: "Total Students", icon: Icons.people_rounded,
                          keyboard: TextInputType.number, onChanged: (_) => _updateCounts(changedField: 'total')),
                      const SizedBox(height: 22),
                      WarliSectionTitle(title: "GENDER BREAKDOWN"),
                      const SizedBox(height: 4),
                      Text("Filling one auto-calculates the other", style: TextStyle(fontSize: 11, color: AppTheme.textDark.withOpacity(0.45))),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: WarliField(controller: _boysController, label: "Boys", icon: Icons.male_rounded,
                            keyboard: TextInputType.number, onChanged: (_) => _updateCounts(changedField: 'boys'))),
                        const SizedBox(width: 12),
                        Expanded(child: WarliField(controller: _girlsController, label: "Girls", icon: Icons.female_rounded,
                            keyboard: TextInputType.number, onChanged: (_) => _updateCounts(changedField: 'girls'))),
                      ]),
                      const SizedBox(height: 30),
                      WarliButton(label: "Save Class", loading: loading, onPressed: _saveClass),
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