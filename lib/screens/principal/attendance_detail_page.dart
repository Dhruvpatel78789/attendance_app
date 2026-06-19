import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:attendance_system/services/mongodb_service.dart';
import '../teacher/mark_attendance_page.dart';
// ── Warli colour palette (shared) ──────────────────────────
class WC {
  static const bg         = Color(0xFFF7EEDC); // lighter warm cream
  static const brown      = Color(0xFF6E432E); // lighter brown
  static const brownLight = Color(0xFF9E7153); // softer medium brown
  static const terra      = Color(0xFFD67845); // lighter terracotta
  static const amber      = Color(0xFFE29A3B); // softer amber
  static const green      = Color(0xFF528751); // lighter earthy green
  static const red        = Color(0xFFC75146); // softer red
  static const cardBg     = Color(0xFFFEF9EB); // lighter parchment card
  static const divider    = Color(0xFFE6D6B8); // lighter divider
  static const Color goldenBtn  = Color(0xFFA0712A);
  static const Color warmBrown  = Color(0xFF6B2D0E);
}

class AttendanceDetailPage extends StatefulWidget {
  final Map<String, dynamic> data;
  const AttendanceDetailPage({super.key, required this.data});
  @override
  State<AttendanceDetailPage> createState() => _AttendanceDetailPageState();
}

class _AttendanceDetailPageState extends State<AttendanceDetailPage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic> records = {};
  Map<String, Map<String, dynamic>> studentsMap = {};
  int presentCount = 0, absentCount = 0;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    presentCount = (widget.data['present'] ?? 0) as int;
    absentCount  = (widget.data['absent'] ?? 0) as int;
    _loadStudents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    final snap = await FirebaseFirestore.instance.collection('students').get();
    for (var doc in snap.docs) studentsMap[doc.id] = doc.data();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    final TextEditingController _boysCtrl  = TextEditingController();
    final TextEditingController _girlsCtrl = TextEditingController();
    final boys = (widget.data['boys'] ?? 0) as int;
    final girls = (widget.data['girls'] ?? 0) as int;
    final totalStudents = (widget.data['total'] ?? 0) as int;
    _boysCtrl.text  = (boys).toString();
    _girlsCtrl.text = (girls).toString();

    final totalPresent = boys + girls;
    final totalAbsent = (totalStudents - totalPresent).clamp(0, totalStudents);

    final classId = widget.data['classId'] ?? '';
    final date    = widget.data['date'] ?? '';
    final total   = presentCount + absentCount;
    final pct     = total > 0 ? (presentCount / total * 100) : 0.0;
    final isLow   = pct < 75;
    final barColor= isLow ? WC.red : WC.green;

    final presentEntries = records.entries.where((e) => e.value == true).toList();
    final absentEntries  = records.entries.where((e) => e.value == false).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Stack(children: [
        // ── Full background ─────────────────────────────────
        Positioned.fill(
          child: Image.asset('assets/images/background.png', fit: BoxFit.cover),
        ),

        SafeArea(
          child: Column(children: [
            // ── Custom AppBar ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
              child: Row(children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: WC.brown),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Class $classId",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                            color: WC.brown)),
                    Text(date, style: TextStyle(fontSize: 12, color: WC.brownLight)),
                  ],
                )),
              ]),
            ),

            const SizedBox(height: 10),

            // ── Summary card ───────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: WC.brown.withOpacity(0.88),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: WC.brown.withOpacity(0.25),
                      blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(children: [
                  Row(children: [
                    _SummaryTile(label: "Total", value: "$total",
                        icon: Icons.people_rounded, color: Colors.white70),
                    _SummaryTile(label: "Present", value: "$presentCount",
                        icon: Icons.check_circle_rounded, color: const Color(0xFF81C784)),
                    _SummaryTile(label: "Absent", value: "$absentCount",
                        icon: Icons.cancel_rounded, color: const Color(0xFFEF9A9A)),
                    _SummaryTile(
                        label: "Rate",
                        value: "${pct.toStringAsFixed(1)}%",
                        icon: Icons.bar_chart_rounded,
                        color: isLow ? const Color(0xFFFFCC80) : const Color(0xFF80DEEA)),
                  ]),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: total > 0 ? pct / 100 : 0,
                      minHeight: 7,
                      backgroundColor: Colors.white24,
                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    ),
                  ),
                ]),
              ),
            ),

            const SizedBox(height: 12),
            // form
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                decoration: BoxDecoration(
                  color: WC.cardBg.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: WC.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    /// 🔹 HEADER
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Class $classId",
                            style: TextStyle(
                                color: WC.brown,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),

                        Text("Date: $date",
                            style: TextStyle(
                                color: WC.brown,
                                fontWeight: FontWeight.bold)),

                        Text("Present: $totalPresent / $totalStudents",
                            style: TextStyle(
                                color: WC.brown,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),

                    const SizedBox(height: 20),

                    /// 🔹 BOYS
                    Text("No. of Boys:",
                        style: TextStyle(
                            color: WC.brown,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),

                    InputField(
                      controller: _boysCtrl,
                      hint: "",
                      isReadOnly: true,
                    ),

                    const SizedBox(height: 16),

                    /// 🔹 GIRLS
                    Text("No. of Girls:",
                        style: TextStyle(
                            color: WC.brown,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),

                    InputField(controller: _girlsCtrl,
                      hint: "",
                      isReadOnly: true,
                    ),

                    const SizedBox(height: 20),

                    /// 🔹 TOTAL PRESENT
                    Text("Total Present:",
                        style: TextStyle(
                            color: WC.brown,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),

                    ResultBox(value: totalPresent, color: WC.goldenBtn),

                    const SizedBox(height: 16),

                    /// 🔹 TOTAL ABSENT
                    Text("Total Absent:",
                        style: TextStyle(
                            color: WC.brown,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),

                    ResultBox(value: totalAbsent, color: WC.goldenBtn),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
//  Summary Tile
// ─────────────────────────────────────────────
class _SummaryTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _SummaryTile(
      {required this.label, required this.value,
        required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(color: color,
          fontWeight: FontWeight.bold, fontSize: 18)),
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
    ]),
  );
}

// ─────────────────────────────────────────────
//  Student List
// ─────────────────────────────────────────────
class _StudentList extends StatelessWidget {
  final List<MapEntry<String, dynamic>> entries;
  final Map<String, Map<String, dynamic>> studentsMap;
  final bool isPresent;
  const _StudentList(
      {required this.entries, required this.studentsMap,
        required this.isPresent});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isPresent ? Icons.how_to_reg_rounded : Icons.person_off_rounded,
              size: 64, color: WC.brownLight.withOpacity(0.35)),
          const SizedBox(height: 12),
          Text(isPresent ? "No present students" : "No absent students",
              style: TextStyle(color: WC.brownLight, fontSize: 16)),
        ],
      ));
    }

    final color = isPresent ? WC.green : WC.red;
    final bgColor = isPresent
        ? WC.green.withOpacity(0.10) : WC.red.withOpacity(0.10);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: entries.length,
      itemBuilder: (ctx, i) {
        final studentId = entries[i].key;
        final student   = studentsMap[studentId];
        final name      = student?['name'] ?? 'Unknown';
        final gr        = student?['grNumber'] ?? studentId;
        final classId   = student?['classId'] ?? '';

        final initials = name.isNotEmpty
            ? name.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
            : '?';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: WC.cardBg.withOpacity(0.93),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: WC.divider),
            boxShadow: [BoxShadow(color: WC.brown.withOpacity(0.07),
                blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: ListTile(
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: bgColor,
              child: Text(initials, style: TextStyle(color: color,
                  fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            title: Text(name, style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14, color: WC.brown)),
            subtitle: Text("GR: $gr · Class: $classId",
                style: TextStyle(color: WC.brownLight, fontSize: 11)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: bgColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.25))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(isPresent
                    ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    size: 13, color: color),
                const SizedBox(width: 4),
                Text(isPresent ? "Present" : "Absent",
                    style: TextStyle(color: color,
                        fontWeight: FontWeight.bold, fontSize: 11)),
              ]),
            ),
          ),
        );
      },
    );
  }
}