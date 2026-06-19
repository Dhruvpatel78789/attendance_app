
import 'package:flutter/material.dart';
import 'package:attendance_system/services/mongodb_service.dart';

class CreateLeavePage extends StatefulWidget {
  const CreateLeavePage({super.key});

  @override
  State<CreateLeavePage> createState() => _CreateLeavePageState();
}

class _CreateLeavePageState extends State<CreateLeavePage> {
  final reasonController   = TextEditingController();
  final fromDateController = TextEditingController();
  final toDateController   = TextEditingController();

  String leaveType = "student";

  String? selectedStudentName;
  String? selectedGR;
  String? selectedTeacherName;
  String? selectedTeacherEmail;
  String? selectedClass;

  bool isToday = false; // ← Today checkbox state

  // ── Warli-inspired warm palette ──────────────────────────
  static const Color _warmBrown  = Color(0xFF6B2D0E);
  static const Color _terracotta = Color(0xFF8B3A0F);
  static const Color _cardBg     = Color(0xFFFFF8F0);

  Stream<QuerySnapshot> getStudents() =>
      FirebaseFirestore.instance.collection('students').snapshots();

  Stream<QuerySnapshot> getTeachers() =>
      FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'teacher')
          .snapshots();

  Future<void> pickDate(TextEditingController controller) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: _warmBrown,
            onPrimary: Colors.white,
            surface: _cardBg,
          ),
        ),
        child: child!,
      ),
    );
    if (date != null) controller.text = date.toString().split(' ')[0];
  }

  Future<void> pickToDate() async {
    if (fromDateController.text.isEmpty) {
      _snack("Select From Date first");
      return;
    }
    final from = DateTime.parse(fromDateController.text);
    final date = await showDatePicker(
      context: context,
      initialDate: from,
      firstDate: from,
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: _warmBrown,
            onPrimary: Colors.white,
            surface: _cardBg,
          ),
        ),
        child: child!,
      ),
    );
    if (date != null) toDateController.text = date.toString().split(' ')[0];
  }

  Future<void> pickTime(TextEditingController controller) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: _warmBrown,
            onPrimary: Colors.white,
            surface: _cardBg,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      controller.text = picked.format(context);
    }
  }

  Future<void> submitLeave() async {
    if (reasonController.text.isEmpty ||
        fromDateController.text.isEmpty ||
        toDateController.text.isEmpty) {
      _snack("Fill all fields");
      return;
    }

    // Date validation only when not today (time mode skips this)
    if (!isToday) {
      final fromDate = DateTime.parse(fromDateController.text);
      final toDate   = DateTime.parse(toDateController.text);
      if (fromDate.isAfter(toDate)) {
        _snack("From date must be before To date");
        return;
      }
    }

    final today = DateTime.now().toString().split(' ')[0];

    if (leaveType == "student") {
      if (selectedStudentName == null ||
          selectedGR == null ||
          selectedClass == null) {
        _snack("Select student & class");
        return;
      }
      await FirebaseFirestore.instance.collection('leave_requests').add({
        'type'        : 'student',
        'studentName' : selectedStudentName,
        'grNumber'    : selectedGR,
        'classId'     : selectedClass,
        'reason'      : reasonController.text.trim(),
        'isToday'     : isToday,
        'fromDate'    : isToday ? today : fromDateController.text,
        'toDate'      : isToday ? today : toDateController.text,
        'fromTime'    : isToday ? fromDateController.text : null,
        'toTime'      : isToday ? toDateController.text   : null,
        'status'      : 'pending',
        'timestamp'   : FieldValue.serverTimestamp(),
      });
    } else {
      if (selectedTeacherName == null || selectedTeacherEmail == null) {
        _snack("Select teacher");
        return;
      }
      await FirebaseFirestore.instance.collection('leave_requests').add({
        'type'         : 'teacher',
        'teacherName'  : selectedTeacherName,
        'teacherEmail' : selectedTeacherEmail,
        'reason'       : reasonController.text.trim(),
        'isToday'      : isToday,
        'fromDate'     : isToday ? today : fromDateController.text,
        'toDate'       : isToday ? today : toDateController.text,
        'fromTime'     : isToday ? fromDateController.text : null,
        'toTime'       : isToday ? toDateController.text   : null,
        'status'       : 'pending',
        'timestamp'    : FieldValue.serverTimestamp(),
      });
    }

    _snack("Leave submitted successfully");
    if (mounted) Navigator.pop(context);
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: _warmBrown),
  );

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(text,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.3,
            color: _warmBrown.withOpacity(0.55))),
  );

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    decoration: BoxDecoration(
      color: _cardBg.withOpacity(0.92),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _warmBrown.withOpacity(0.12)),
      boxShadow: [
        BoxShadow(
            color: _warmBrown.withOpacity(0.07),
            blurRadius: 6,
            offset: const Offset(0, 2))
      ],
    ),
    child: child,
  );

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool readOnly = false,
    VoidCallback? onTap,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg.withOpacity(0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _warmBrown.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
              color: _warmBrown.withOpacity(0.07),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        maxLines: maxLines,
        style: TextStyle(color: _warmBrown.withOpacity(0.9), fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon:
          Icon(icon, color: _warmBrown.withOpacity(0.4), size: 20),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.transparent,
          labelStyle:
          TextStyle(color: _warmBrown.withOpacity(0.5), fontSize: 13),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Background image ──────────────────────────────
          Positioned.fill(
            child: Image.asset(
              'assets/images/background.png',
              fit: BoxFit.cover,
            ),
          ),

          // ── Content ───────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Custom AppBar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _warmBrown.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: _warmBrown.withOpacity(0.2)),
                          ),
                          child: Icon(Icons.arrow_back_ios_new_rounded,
                              color: _warmBrown, size: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Create Leave",
                        style: TextStyle(
                          color: _warmBrown,
                          fontWeight: FontWeight.bold,
                          fontSize: 19,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Banner ────────────────────────────
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: _warmBrown.withOpacity(0.88),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: _terracotta.withOpacity(0.4)),
                            boxShadow: [
                              BoxShadow(
                                  color: _warmBrown.withOpacity(0.25),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6))
                            ],
                          ),
                          child: Row(children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.event_note_rounded,
                                  color: Colors.white, size: 26),
                            ),
                            const SizedBox(width: 14),
                            const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Leave Application",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 17)),
                                  SizedBox(height: 3),
                                  Text(
                                      "Submit a leave for student or teacher",
                                      style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12)),
                                ]),
                          ]),
                        ),

                        const SizedBox(height: 28),
                        _sectionLabel("LEAVE FOR"),

                        // ── Leave type toggle ─────────────────
                        Row(children: [
                          Expanded(
                            child: _TypeChip(
                              label: "Student",
                              icon: Icons.school_rounded,
                              selected: leaveType == 'student',
                              color: _warmBrown,
                              onTap: () => setState(() {
                                leaveType = 'student';
                                selectedStudentName = null;
                                selectedTeacherName = null;
                              }),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _TypeChip(
                              label: "Teacher",
                              icon: Icons.person_rounded,
                              selected: leaveType == 'teacher',
                              color: _terracotta,
                              onTap: () => setState(() {
                                leaveType = 'teacher';
                                selectedStudentName = null;
                                selectedTeacherName = null;
                              }),
                            ),
                          ),
                        ]),

                        const SizedBox(height: 24),
                        _sectionLabel(leaveType == 'student'
                            ? "SELECT STUDENT"
                            : "SELECT TEACHER"),

                        // ── Student autocomplete ──────────────
                        if (leaveType == "student")
                          StreamBuilder<QuerySnapshot>(
                            stream: getStudents(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) return const SizedBox();
                              final students = snapshot.data!.docs;
                              return _card(
                                child: Autocomplete<String>(
                                  optionsBuilder: (text) {
                                    if (text.text.isEmpty)
                                      return const Iterable<String>.empty();
                                    return students.map((doc) {
                                      final data = doc.data()
                                      as Map<String, dynamic>;
                                      return "${data['name'] ?? 'Unknown'} (GR: ${data['grNumber']?.toString() ?? 'NA'})";
                                    }).where((item) => item
                                        .toLowerCase()
                                        .contains(
                                        text.text.toLowerCase()));
                                  },
                                  onSelected: (value) {
                                    final match = students.firstWhere((doc) {
                                      final data = doc.data()
                                      as Map<String, dynamic>;
                                      return value
                                          .contains(data['name'] ?? '');
                                    });
                                    final data = match.data()
                                    as Map<String, dynamic>;
                                    setState(() {
                                      selectedStudentName =
                                          data['name'] ?? '';
                                      selectedGR =
                                          data['grNumber']?.toString() ??
                                              '';
                                      selectedClass =
                                          data['classId'] ?? '';
                                    });
                                  },
                                  fieldViewBuilder:
                                      (context, controller, focusNode, _) {
                                    return TextField(
                                      controller: controller,
                                      focusNode: focusNode,
                                      style: TextStyle(
                                          color: _warmBrown.withOpacity(0.9),
                                          fontSize: 14),
                                      decoration: InputDecoration(
                                        labelText: "Search by name or GR...",
                                        prefixIcon: Icon(Icons.search_rounded,
                                            color:
                                            _warmBrown.withOpacity(0.4),
                                            size: 20),
                                        border: InputBorder.none,
                                        labelStyle: TextStyle(
                                            color:
                                            _warmBrown.withOpacity(0.5),
                                            fontSize: 13),
                                        contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 0, vertical: 14),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),

                        // ── Teacher autocomplete ──────────────
                        if (leaveType == "teacher")
                          StreamBuilder<QuerySnapshot>(
                            stream: getTeachers(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) return const SizedBox();
                              final teachers = snapshot.data!.docs;
                              return _card(
                                child: Autocomplete<String>(
                                  optionsBuilder: (text) {
                                    if (text.text.isEmpty)
                                      return const Iterable<String>.empty();
                                    return teachers.map((doc) {
                                      final data = doc.data()
                                      as Map<String, dynamic>;
                                      return "${data['name'] ?? 'Unknown'} (${data['email'] ?? 'NA'})";
                                    }).where((item) => item
                                        .toLowerCase()
                                        .contains(
                                        text.text.toLowerCase()));
                                  },
                                  onSelected: (value) {
                                    final match = teachers.firstWhere((doc) {
                                      final data = doc.data()
                                      as Map<String, dynamic>;
                                      return value
                                          .contains(data['email'] ?? '');
                                    });
                                    final data = match.data()
                                    as Map<String, dynamic>;
                                    setState(() {
                                      selectedTeacherName =
                                          data['name'] ?? '';
                                      selectedTeacherEmail =
                                          data['email'] ?? '';
                                    });
                                  },
                                  fieldViewBuilder:
                                      (context, controller, focusNode, _) {
                                    return TextField(
                                      controller: controller,
                                      focusNode: focusNode,
                                      style: TextStyle(
                                          color: _warmBrown.withOpacity(0.9),
                                          fontSize: 14),
                                      decoration: InputDecoration(
                                        labelText:
                                        "Search by name or email...",
                                        prefixIcon: Icon(Icons.search_rounded,
                                            color:
                                            _warmBrown.withOpacity(0.4),
                                            size: 20),
                                        border: InputBorder.none,
                                        labelStyle: TextStyle(
                                            color:
                                            _warmBrown.withOpacity(0.5),
                                            fontSize: 13),
                                        contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 0, vertical: 14),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),

                        // ── Class auto-fill chip ──────────────
                        if (leaveType == "student" &&
                            selectedClass != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: _warmBrown.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: _warmBrown.withOpacity(0.18)),
                            ),
                            child: Row(children: [
                              Icon(Icons.school_rounded,
                                  color: _warmBrown.withOpacity(0.5),
                                  size: 18),
                              const SizedBox(width: 10),
                              Text("Class: $selectedClass",
                                  style: TextStyle(
                                      color: _warmBrown.withOpacity(0.8),
                                      fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ],

                        const SizedBox(height: 24),
                        _sectionLabel("LEAVE DETAILS"),

                        // ── Reason field ──────────────────────
                        _textField(
                            controller: reasonController,
                            label: "Reason for Leave",
                            icon: Icons.info_outline_rounded,
                            maxLines: 2),

                        const SizedBox(height: 12),

                        // ── Today checkbox ────────────────────
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: isToday
                                ? _warmBrown.withOpacity(0.08)
                                : _cardBg.withOpacity(0.92),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isToday
                                  ? _warmBrown.withOpacity(0.35)
                                  : _warmBrown.withOpacity(0.12),
                            ),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: isToday,
                                activeColor: _warmBrown,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4)),
                                onChanged: (val) {
                                  setState(() {
                                    isToday = val ?? false;
                                    // Clear fields when switching modes
                                    fromDateController.clear();
                                    toDateController.clear();
                                  });
                                },
                              ),
                              Text(
                                "Today",
                                style: TextStyle(
                                  color: isToday
                                      ? _warmBrown
                                      : _warmBrown.withOpacity(0.6),
                                  fontWeight: isToday
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isToday
                                    ? "Enter start & end time"
                                    : "Check for same-day leave",
                                style: TextStyle(
                                  color: _warmBrown.withOpacity(0.4),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ── Date OR Time pickers ──────────────
                        Row(children: [
                          Expanded(
                            child: _textField(
                              controller: fromDateController,
                              label: isToday ? "From Time" : "From Date",
                              icon: isToday
                                  ? Icons.access_time_rounded
                                  : Icons.calendar_today_rounded,
                              readOnly: true,
                              onTap: isToday
                                  ? () => pickTime(fromDateController)
                                  : () => pickDate(fromDateController),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _textField(
                              controller: toDateController,
                              label: isToday ? "To Time" : "To Date",
                              icon: isToday
                                  ? Icons.access_time_rounded
                                  : Icons.calendar_today_rounded,
                              readOnly: true,
                              onTap: isToday
                                  ? () => pickTime(toDateController)
                                  : pickToDate,
                            ),
                          ),
                        ]),

                        const SizedBox(height: 32),

                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: submitLeave,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _warmBrown,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: const Text("Submit Leave",
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Type Chip  (warm style)
// ─────────────────────────────────────────────
class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? color : const Color(0xFFFFF8F0).withOpacity(0.92),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? color : color.withOpacity(0.2),
              width: 1.5),
          boxShadow: selected
              ? [
            BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ]
              : [
            BoxShadow(
                color: Colors.black.withOpacity(0.04), blurRadius: 4)
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon,
              color: selected ? Colors.white : color.withOpacity(0.5),
              size: 18),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: selected ? Colors.white : color.withOpacity(0.65),
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ]),
      ),
    );
  }
}