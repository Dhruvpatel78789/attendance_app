import 'package:flutter/material.dart';
import 'package:attendance_system/services/mongodb_service.dart';
import '../admin/admin_dashboard.dart'; // import AppTheme

class AssignStandingPrincipalPage extends StatefulWidget {
  const AssignStandingPrincipalPage({super.key});

  @override
  State<AssignStandingPrincipalPage> createState() => _AssignStandingPrincipalPageState();
}

class _AssignStandingPrincipalPageState extends State<AssignStandingPrincipalPage> {
  String? selectedTeacherEmail; // Stores UID
  String? selectedTeacherName;
  String? selectedTeacherActualEmail;
  DateTimeRange? selectedRange;
  bool loading = false;

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppTheme.primary,
            onPrimary: Colors.white,
            surface: AppTheme.cardBg,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => selectedRange = picked);
    }
  }

  Future<void> _assignStanding() async {
    if (selectedTeacherEmail == null || selectedRange == null) {
      _snack("Please select a teacher and date range");
      return;
    }

    setState(() => loading = true);

    final startStr = selectedRange!.start.toString().split(' ')[0];
    final endStr = selectedRange!.end.toString().split(' ')[0];

    try {
      await FirebaseFirestore.instance.collection('standing_principals').add({
        'teacherEmail': selectedTeacherActualEmail ?? selectedTeacherEmail,
        'teacherUid': selectedTeacherEmail,
        'teacherName': selectedTeacherName,
        'startDate': startStr,
        'endDate': endStr,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _snack("Standing Principal assigned successfully");
      setState(() {
        selectedTeacherEmail = null;
        selectedTeacherName = null;
        selectedTeacherActualEmail = null;
        selectedRange = null;
      });
    } catch (e) {
      _snack("Failed to assign: $e");
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _deleteAssignment(String docId) async {
    await FirebaseFirestore.instance.collection('standing_principals').doc(docId).delete();
    _snack("Assignment removed");
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.bgDecoration,
        child: SafeArea(
          child: Column(
            children: [
              WarliAppBar(title: "Standing Principal"),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      WarliBanner(
                        icon: Icons.assignment_ind_rounded,
                        title: "Delegate Approvals",
                        subtitle: "Assign a standing principal while you are away",
                      ),
                      const SizedBox(height: 24),

                      WarliSectionTitle(title: "CREATE ASSIGNMENT"),
                      const SizedBox(height: 10),

                      // Select Teacher Stream
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .where('role', isEqualTo: 'teacher')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                          }
                          final teachers = snapshot.data!.docs;

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.cardBg.withOpacity(0.92),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.primary.withOpacity(0.12)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedTeacherEmail,
                                isExpanded: true,
                                dropdownColor: AppTheme.cardBg,
                                hint: const Text("Select Teacher", style: TextStyle(fontSize: 13)),
                                icon: const Icon(Icons.arrow_drop_down_rounded, color: AppTheme.primary),
                                style: const TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.w600, fontSize: 14),
                                onChanged: (String? email) {
                                  if (email != null) {
                                    final teacherDoc = teachers.firstWhere((doc) => doc.id == email);
                                    final data = teacherDoc.data() as Map<String, dynamic>;
                                    setState(() {
                                      selectedTeacherEmail = email;
                                      selectedTeacherName = data['name'] ?? 'Teacher';
                                      selectedTeacherActualEmail = data['email'] ?? '';
                                    });
                                  }
                                },
                                items: teachers.map<DropdownMenuItem<String>>((doc) {
                                  final data = doc.data() as Map<String, dynamic>;
                                  return DropdownMenuItem<String>(
                                    value: doc.id,
                                    child: Text(data['name'] ?? 'Unknown Teacher'),
                                  );
                                }).toList(),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      // Date Range picker button
                      InkWell(
                        onTap: _pickDateRange,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg.withOpacity(0.92),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.primary.withOpacity(0.12)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 18, color: AppTheme.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  selectedRange == null
                                      ? "Select Date Range"
                                      : "${selectedRange!.start.toString().split(' ')[0]}  to  ${selectedRange!.end.toString().split(' ')[0]}",
                                  style: TextStyle(
                                    color: selectedRange == null ? AppTheme.textDark.withOpacity(0.5) : AppTheme.textDark,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded, color: AppTheme.primary.withOpacity(0.4), size: 18),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: loading ? null : _assignStanding,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: loading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text("Assign Role", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),

                      const SizedBox(height: 32),
                      WarliSectionTitle(title: "CURRENT DELEGATIONS"),
                      const SizedBox(height: 10),

                      // List current assignments
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('standing_principals')
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                          }
                          final list = snapshot.data!.docs;

                          if (list.isEmpty) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              decoration: BoxDecoration(
                                color: AppTheme.cardBg.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.primary.withOpacity(0.1)),
                              ),
                              child: Center(
                                child: Text("No delegations set",
                                    style: TextStyle(color: AppTheme.textDark.withOpacity(0.5), fontSize: 13)),
                              ),
                            );
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: list.length,
                            itemBuilder: (context, index) {
                              final doc = list[index];
                              final data = doc.data() as Map<String, dynamic>;
                              final name = data['teacherName'] ?? '';
                              final start = data['startDate'] ?? '';
                              final end = data['endDate'] ?? '';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppTheme.cardBg.withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.primary.withOpacity(0.12)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark)),
                                          const SizedBox(height: 2),
                                          Text("$start  to  $end", style: TextStyle(color: AppTheme.textDark.withOpacity(0.6), fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                      onPressed: () => _deleteAssignment(doc.id),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
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
