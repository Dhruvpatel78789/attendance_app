import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:attendance_system/services/mongodb_service.dart';

class MarkAttendancePage extends StatefulWidget {
  const MarkAttendancePage({super.key});

  @override
  State<MarkAttendancePage> createState() => _MarkAttendancePageState();
}

class _MarkAttendancePageState extends State<MarkAttendancePage> {
  // ── Class state ────────────────────────────────────────────────────────────
  String?      selectedClass;

  /// The class ID stored on the teacher's own Firestore user doc.
  /// Field name in Firestore: "classId"  (e.g. "10-B")
  String?      _teacherClassId;

  /// Full list of class names fetched from the /classes collection.
  List<String> _allClasses = [];

  bool _loadingAll = true;

  // ── Attendance state ───────────────────────────────────────────────────────
  String? attendanceDocId;
  int totalStudents = 0;
  int maxBoys       = 0;
  int maxGirls      = 0;

  final TextEditingController _boysCtrl  = TextEditingController();
  final TextEditingController _girlsCtrl = TextEditingController();

  bool alreadyMarked      = false;
  bool checkingAttendance = false;

  // ── Colors ─────────────────────────────────────────────────────────────────
  static const Color _warmBrown  = Color(0xFF6B2D0E);
  static const Color _terracotta = Color(0xFF8B3A0F);
  static const Color _cardBg     = Color(0xFFFFF8F0);
  static const Color _goldenBtn  = Color(0xFFA0712A);
  static const Color _submitBtn  = Color(0xFF7B3A1A);
  static const Color _tealChip   = Color(0xFF2E7D5E);

  // ── Helpers ────────────────────────────────────────────────────────────────
  String get todayDate {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  int get boysCount    => int.tryParse(_boysCtrl.text)  ?? 0;
  int get girlsCount   => int.tryParse(_girlsCtrl.text) ?? 0;
  int get totalPresent => boysCount + girlsCount;
  int get totalAbsent  => (totalStudents - totalPresent).clamp(0, totalStudents);

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _boysCtrl.addListener(() => setState(() {}));
    _girlsCtrl.addListener(() => setState(() {}));
    _initPage();
  }

  @override
  void dispose() {
    _boysCtrl.dispose();
    _girlsCtrl.dispose();
    super.dispose();
  }

  // ── Init: load class list + teacher's assigned class atomically ────────────
  //
  // WHY this approach:
  //   Flutter's DropdownButton throws an assertion error if `value` is not
  //   present in `items`.  The old code used a StreamBuilder for the class
  //   list, which meant the items list was empty at the moment we tried to
  //   pre-set `selectedClass` — causing a silent crash / no pre-selection.
  //
  //   By fetching both lists with plain Futures before calling setState(), we
  //   guarantee the dropdown renders with a valid (value ∈ items) state on the
  //   very first frame.
  //
  // FIRESTORE FIELD:
  //   The teacher's assigned class is stored in /users/{uid} as:
  //     classId: "10-B"          ← exact field name visible in the screenshot
  //
  Future<void> _initPage() async {
    final user = FirebaseAuth.instance.currentUser;

    try {
      // 1. Fetch all class names from /classes
      final classSnap = await FirebaseFirestore.instance
          .collection('classes')
          .get();

      final names = classSnap.docs
          .map((d) => d['name'] as String)
          .toList();

      // 2. Fetch the teacher's own doc and read the "classId" field
      String? assignedId;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        final raw = userDoc.data()?['classId']; // ← correct field name
        if (raw is String && raw.isNotEmpty) assignedId = raw;
      }

      if (!mounted) return;

      setState(() {
        _allClasses     = names;
        _teacherClassId = assignedId;

        // Pre-select only when the assigned class actually exists in Firestore
        if (assignedId != null && names.contains(assignedId)) {
          selectedClass = assignedId;
        }
        _loadingAll = false;
      });

      // 3. If we pre-selected, auto-load meta + check today's attendance
      if (selectedClass != null) {
        await _loadClassMeta(selectedClass!);
        await checkAttendanceExists();
      }
    } catch (e) {
      if (mounted) setState(() => _loadingAll = false);
    }
  }

  // ── Firestore helpers ──────────────────────────────────────────────────────

  Future<void> _loadClassMeta(String className) async {
    final snap = await FirebaseFirestore.instance
        .collection('classes')
        .where('name', isEqualTo: className)
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty && mounted) {
      final data = snap.docs.first.data();
      setState(() {
        totalStudents = (data['totalStudents'] as int?) ?? 0;
        maxBoys       = (data['boys']           as int?) ?? 0;
        maxGirls      = (data['girls']          as int?) ?? 0;
      });
    }
  }

  Future<void> checkAttendanceExists() async {
    if (selectedClass == null) return;
    setState(() {
      checkingAttendance = true;
      alreadyMarked      = false;
      attendanceDocId    = null;
    });

    final snapshot = await FirebaseFirestore.instance
        .collection('attendance')
        .where('classId', isEqualTo: selectedClass!.trim())
        .where('date',    isEqualTo: todayDate)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final doc = snapshot.docs.first;
      attendanceDocId = doc.id;
      alreadyMarked   = true;
      final data = doc.data();
      _boysCtrl.text  = (data['boys']  ?? 0).toString();
      _girlsCtrl.text = (data['girls'] ?? 0).toString();
    } else {
      _boysCtrl.clear();
      _girlsCtrl.clear();
    }
    if (mounted) setState(() => checkingAttendance = false);
  }

  Future<void> _submit() async {
    if (selectedClass == null) return;
    if (_boysCtrl.text.isEmpty || _girlsCtrl.text.isEmpty) {
      _snack("Please fill in both fields");
      return;
    }
    if (boysCount > maxBoys || girlsCount > maxGirls) {
      _snack("Enter valid number of students");
    }
    if (totalPresent > totalStudents) {
      _snack(
          "Total present ($totalPresent) cannot exceed class strength ($totalStudents)");
      return;
    }

    final user    = FirebaseAuth.instance.currentUser;
    final payload = {
      'classId'  : selectedClass,
      'date'     : todayDate,
      'boys'     : boysCount,
      'girls'    : girlsCount,
      'present'  : totalPresent,
      'absent'   : totalAbsent,
      'total'    : totalStudents,
      'markedBy' : user?.uid,
      'timestamp': FieldValue.serverTimestamp(),
    };

    if (attendanceDocId != null) {
      await FirebaseFirestore.instance
          .collection('attendance')
          .doc(attendanceDocId)
          .update(payload);
      if (!mounted) return;
      _snack("Attendance updated ✓");
      Navigator.pop(context);
    } else {
      await FirebaseFirestore.instance.collection('attendance').add(payload);
      if (!mounted) return;
      _snack("Attendance saved ✓");
      await checkAttendanceExists();
      Navigator.pop(context);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: _warmBrown,
    ),
  );

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background texture
          Positioned.fill(
            child: Image.asset('assets/images/background.png',
                fit: BoxFit.cover),
          ),

          SafeArea(
            child: _loadingAll
                ? const Center(
                child: CircularProgressIndicator(color: _warmBrown))
                : Column(
              children: [
                // ── Top bar ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(children: [
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
                    Text("Mark Attendance",
                        style: TextStyle(
                            color: _warmBrown,
                            fontWeight: FontWeight.bold,
                            fontSize: 19)),
                  ]),
                ),

                const SizedBox(height: 14),

                // ── Class selector ───────────────────────────────────
                Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // "Your class" badge — visible when teacher's
                      // own assigned class is currently selected
                      if (_teacherClassId != null &&
                          selectedClass == _teacherClassId)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: _tealChip.withOpacity(0.12),
                              borderRadius:
                              BorderRadius.circular(20),
                              border: Border.all(
                                  color:
                                  _tealChip.withOpacity(0.40)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bookmark_rounded,
                                    color: _tealChip, size: 13),
                                const SizedBox(width: 6),
                                Text("Your assigned class",
                                    style: TextStyle(
                                        color: _tealChip,
                                        fontSize: 11,
                                        fontWeight:
                                        FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),

                      // Dropdown — data comes from _allClasses (plain
                      // Future), not a StreamBuilder, so value is always
                      // a valid item on first render.
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: _cardBg.withOpacity(0.90),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (_teacherClassId != null &&
                                selectedClass == _teacherClassId)
                                ? _tealChip.withOpacity(0.50)
                                : _warmBrown.withOpacity(0.22),
                            width: (_teacherClassId != null &&
                                selectedClass == _teacherClassId)
                                ? 1.8
                                : 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                                color: _warmBrown.withOpacity(0.08),
                                blurRadius: 8)
                          ],
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedClass,
                            isExpanded: true,
                            dropdownColor: _cardBg,
                            hint: Text("Select Class",
                                style: TextStyle(
                                    color: _warmBrown
                                        .withOpacity(0.5))),
                            style: TextStyle(
                                color: _warmBrown,
                                fontSize: 15,
                                fontWeight: FontWeight.w600),
                            icon: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: _warmBrown.withOpacity(0.6)),
                            items: _allClasses.map((cn) {
                              final isTeacherClass =
                                  cn == _teacherClassId;
                              return DropdownMenuItem(
                                value: cn,
                                child: Row(children: [
                                  Expanded(
                                    child: Text(
                                      cn,
                                      style: TextStyle(
                                        fontWeight: isTeacherClass
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  if (isTeacherClass) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _tealChip
                                            .withOpacity(0.12),
                                        borderRadius:
                                        BorderRadius.circular(
                                            10),
                                        border: Border.all(
                                            color: _tealChip
                                                .withOpacity(0.35)),
                                      ),
                                      child: Row(
                                        mainAxisSize:
                                        MainAxisSize.min,
                                        children: [
                                          Icon(
                                              Icons.bookmark_rounded,
                                              color: _tealChip,
                                              size: 11),
                                          const SizedBox(width: 3),
                                          Text("My Class",
                                              style: TextStyle(
                                                  color: _tealChip,
                                                  fontSize: 10,
                                                  fontWeight:
                                                  FontWeight
                                                      .w700)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ]),
                              );
                            }).toList(),
                            onChanged: (value) async {
                              setState(() {
                                selectedClass = value;
                                totalStudents = 0;
                                maxBoys       = 0;
                                maxGirls      = 0;
                                _boysCtrl.clear();
                                _girlsCtrl.clear();
                              });
                              await _loadClassMeta(value!);
                              await checkAttendanceExists();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (checkingAttendance)
                  LinearProgressIndicator(
                      minHeight: 3,
                      color: _warmBrown,
                      backgroundColor: _warmBrown.withOpacity(0.1)),

                const SizedBox(height: 10),

                // ── Already marked banner ────────────────────────────
                if (alreadyMarked && selectedClass != null)
                  Container(
                    margin:
                    const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color:
                      const Color(0xFFFFF3E0).withOpacity(0.92),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: _terracotta.withOpacity(0.4)),
                    ),
                    child: Row(children: [
                      Icon(Icons.info_outline_rounded,
                          color: _terracotta, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                            "Already marked today. Submit to update.",
                            style: TextStyle(
                                color: _terracotta, fontSize: 11)),
                      ),
                    ]),
                  ),

                // ── Main form card ───────────────────────────────────
                if (selectedClass != null)
                  Expanded(
                    child: SingleChildScrollView(
                      padding:
                      const EdgeInsets.fromLTRB(16, 4, 16, 32),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(
                            24, 20, 24, 28),
                        decoration: BoxDecoration(
                          color: _cardBg.withOpacity(0.88),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: _warmBrown.withOpacity(0.18)),
                          boxShadow: [
                            BoxShadow(
                                color: _warmBrown.withOpacity(0.10),
                                blurRadius: 16,
                                offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            // Header row: class name | total | present
                            Row(
                              mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                              children: [
                                Text(selectedClass!,
                                    style: TextStyle(
                                        color: _warmBrown,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17,
                                        letterSpacing: 0.5)),
                                RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                        color: _warmBrown,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17),
                                    children: [
                                      const TextSpan(
                                          text: "Total : "),
                                      TextSpan(
                                        text: "$totalStudents",
                                        style: TextStyle(
                                          color:
                                          totalPresent >
                                              totalStudents
                                              ? Colors.red
                                              : _warmBrown,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                        color: _warmBrown,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17),
                                    children: [
                                      const TextSpan(
                                          text: "Present : "),
                                      TextSpan(
                                        text: "$totalPresent",
                                        style: TextStyle(
                                          color:
                                          totalPresent >
                                              totalStudents
                                              ? Colors.red
                                              : _warmBrown,
                                        ),
                                      ),
                                      TextSpan(
                                        text: " / $totalStudents",
                                        style: TextStyle(
                                            color: _warmBrown
                                                .withOpacity(0.5),
                                            fontSize: 13,
                                            fontWeight:
                                            FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            Text("No. of Boys :",
                                style: TextStyle(
                                    color: _warmBrown,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15)),
                            const SizedBox(height: 8),
                            InputField(
                              controller: _boysCtrl,
                              hint: "Enter number of boys present",
                            ),
                            if (boysCount > maxBoys)
                              Padding(
                                padding: const EdgeInsets.only(
                                    top: 6, left: 4),
                                child: Text(
                                  "⚠ Cannot exceed $maxBoys enrolled boys",
                                  style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12),
                                ),
                              ),

                            const SizedBox(height: 20),

                            Text("No. of Girls:",
                                style: TextStyle(
                                    color: _warmBrown,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15)),
                            const SizedBox(height: 8),
                            InputField(
                              controller: _girlsCtrl,
                              hint: "Enter number of girls present",
                            ),
                            if (girlsCount > maxGirls)
                              Padding(
                                padding: const EdgeInsets.only(
                                    top: 6, left: 4),
                                child: Text(
                                  "⚠ Cannot exceed $maxGirls enrolled girls",
                                  style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12),
                                ),
                              ),

                            const SizedBox(height: 28),

                            Text("Total Present in Class:",
                                style: TextStyle(
                                    color: _warmBrown,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15)),
                            const SizedBox(height: 8),
                            ResultBox(
                                value: totalPresent,
                                color: _goldenBtn),

                            const SizedBox(height: 20),

                            Text("Total Absent in Class:",
                                style: TextStyle(
                                    color: _warmBrown,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15)),
                            const SizedBox(height: 8),
                            ResultBox(
                                value: totalAbsent,
                                color: _goldenBtn),

                            const SizedBox(height: 32),

                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _submitBtn,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(14),
                                  ),
                                  elevation: 4,
                                  shadowColor:
                                  _submitBtn.withOpacity(0.4),
                                ),
                                child: const Text(
                                  "SUBMIT",
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ── Empty state ──────────────────────────────────────
                if (selectedClass == null)
                  Expanded(
                    child: Center(
                      child: Column(
                          mainAxisAlignment:
                          MainAxisAlignment.center,
                          children: [
                            Icon(Icons.class_rounded,
                                size: 60,
                                color: _warmBrown.withOpacity(0.2)),
                            const SizedBox(height: 12),
                            Text("Select a class to begin",
                                style: TextStyle(
                                    color:
                                    _warmBrown.withOpacity(0.45),
                                    fontSize: 15)),
                          ]),
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

// ─────────────────────────────────────────────────────────────────────────────
// Private sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool isReadOnly;

  static const Color _warmBrown = Color(0xFF6B2D0E);
  static const Color _cardBg    = Color(0xFFFFF8F0);

  const InputField({
    required this.controller,
    required this.hint,
    this.isReadOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _warmBrown.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
              color: _warmBrown.withOpacity(0.07),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: TextField(
        controller: controller,
        readOnly: isReadOnly,
        enableInteractiveSelection: !isReadOnly,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        style: TextStyle(
            color: _warmBrown, fontWeight: FontWeight.bold, fontSize: 18),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
          TextStyle(color: _warmBrown.withOpacity(0.30), fontSize: 13),
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
    );
  }
}

class ResultBox extends StatelessWidget {
  final int   value;
  final Color color;
  const ResultBox({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.35),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Center(
        child: Text(
          "$value",
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
    );
  }
}