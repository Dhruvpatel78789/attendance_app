
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:attendance_system/services/mongodb_service.dart';
import 'class_attendance_page.dart';

// ── Warli / Earthy colour palette ──────────────────────────
class WC {
  static const bg         = Color(0xFFF7EEDC);
  static const brown      = Color(0xFF6E432E);
  static const brownLight = Color(0xFF9E7153);
  static const terra      = Color(0xFFD67845);
  static const amber      = Color(0xFFE29A3B);
  static const green      = Color(0xFF528751);
  static const red        = Color(0xFFC75146);
  static const cardBg     = Color(0xFFFEF9EB);
  static const divider    = Color(0xFFE6D6B8);
}

String get _todayIso {
  final n = DateTime.now();
  return "${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}";
}

// ─────────────────────────────────────────────────────────────
//  ViewAttendancePage  –  class-wise attendance overview
// ─────────────────────────────────────────────────────────────
class ViewAttendancePage extends StatefulWidget {
  const ViewAttendancePage({super.key});

  @override
  State<ViewAttendancePage> createState() => _ViewAttendancePageState();
}

class _ViewAttendancePageState extends State<ViewAttendancePage> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Stack(children: [
        // ── Full-screen background ──────────────────────
        Positioned.fill(
          child: Image.asset('assets/images/background.png', fit: BoxFit.cover),
        ),

        SafeArea(
          child: Column(children: [
            // ── AppBar ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: WC.brown),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Text("Class Attendance",
                      style: TextStyle(fontSize: 20,
                          fontWeight: FontWeight.bold, color: WC.brown)),
                ),
              ]),
            ),

            // ── Search bar ─────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: WC.cardBg.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: WC.divider),
                ),
                child: TextField(
                  style: const TextStyle(color: WC.brown),
                  decoration: const InputDecoration(
                    hintText: "Search class…",
                    hintStyle: TextStyle(color: WC.brownLight),
                    prefixIcon: Icon(Icons.search, color: WC.brownLight, size: 20),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 13),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                ),
              ),
            ),

            // ── Class list ───────────────────────────
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('attendance')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                        child: Text("Error loading attendance",
                            style: TextStyle(color: WC.brown)));
                  }
                  if (!snapshot.hasData) {
                    return const Center(
                        child: CircularProgressIndicator(color: WC.terra));
                  }

                  var docs = snapshot.data!.docs;

                  // ── Group by classId ──────────────────────
                  final Map<String, List<Map<String, dynamic>>> byClass = {};
                  for (var doc in docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final classId = (data['classId'] ?? 'Unknown') as String;
                    byClass.putIfAbsent(classId, () => []).add(data);
                  }

                  // Apply search filter
                  var classList = byClass.keys.toList()..sort();
                  if (_searchQuery.isNotEmpty) {
                    classList = classList
                        .where((c) => c.toLowerCase().contains(_searchQuery))
                        .toList();
                  }

                  if (classList.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.class_rounded, size: 64, color: WC.brownLight),
                          SizedBox(height: 12),
                          Text("No classes found",
                              style: TextStyle(color: WC.brownLight, fontSize: 16)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: classList.length,
                    itemBuilder: (context, index) {
                      final classId = classList[index];
                      final classRecords = byClass[classId]!;

                      // Get today's record if exists
                      final todayRecord = classRecords.firstWhere(
                            (r) => r['date'] == _todayIso,
                        orElse: () => <String, dynamic>{},
                      );

                      // Calculate overall stats for this class
                      int totalSessions = classRecords.length;
                      int totalPresent = 0, totalAbsent = 0;

                      for (var record in classRecords) {
                        totalPresent += (record['present'] ?? 0) as int;
                        totalAbsent += (record['absent'] ?? 0) as int;
                      }

                      final total = totalPresent + totalAbsent;
                      final avgPct = total > 0 ? totalPresent / total * 100 : 0.0;
                      final isLow = avgPct < 75 && total > 0;

                      // Today's stats
                      final todayPresent = (todayRecord['present'] ?? 0) as int;
                      final todayTotal = (todayRecord['total'] ?? 0) as int;
                      final hasTodayData = todayRecord.isNotEmpty;

                      return _ClassCard(
                        classId: classId,
                        totalSessions: totalSessions,
                        avgPct: avgPct,
                        isLow: isLow,
                        hasTodayData: hasTodayData,
                        todayPresent: todayPresent,
                        todayTotal: todayTotal,
                        totalPresent: totalPresent,
                        totalAbsent: totalAbsent,
                      );
                    },
                  );
                },
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Class card
// ─────────────────────────────────────────────────────────────
class _ClassCard extends StatelessWidget {
  final String classId;
  final int totalSessions;
  final double avgPct;
  final bool isLow;
  final bool hasTodayData;
  final int todayPresent, todayTotal;
  final int totalPresent, totalAbsent;

  const _ClassCard({
    required this.classId,
    required this.totalSessions,
    required this.avgPct,
    required this.isLow,
    required this.hasTodayData,
    required this.todayPresent,
    required this.todayTotal,
    required this.totalPresent,
    required this.totalAbsent,
  });

  @override
  Widget build(BuildContext context) {
    final color = isLow ? WC.red : WC.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: WC.cardBg.withOpacity(0.93),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WC.divider),
        boxShadow: [
          BoxShadow(
            color: WC.brown.withOpacity(0.09),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClassAttendancePage(classId: classId),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Class icon
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: Center(
                      child: Icon(Icons.class_rounded, color: color, size: 26),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Class info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "Class $classId",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: WC.brown,
                              ),
                            ),
                            if (hasTodayData) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: WC.amber.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  "Today",
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: WC.amber,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "$totalSessions session${totalSessions == 1 ? '' : 's'} recorded",
                          style: const TextStyle(
                            color: WC.brownLight,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Average percentage
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          if (isLow)
                            Container(
                              width: 7,
                              height: 7,
                              margin: const EdgeInsets.only(right: 4),
                              decoration: const BoxDecoration(
                                color: WC.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          Text(
                            "${avgPct.toStringAsFixed(0)}%",
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        "avg",
                        style: TextStyle(
                          color: WC.brownLight,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: WC.brownLight,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Today's quick stats
              Row(
                children: [
                  if (hasTodayData) ...[
                    const Icon(Icons.today_rounded, size: 14, color: WC.amber),
                    const SizedBox(width: 4),
                    Text(
                      "Today: $todayPresent/$todayTotal present",
                      style: const TextStyle(
                        color: WC.brown,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else ...[
                    const Icon(Icons.info_outline_rounded, size: 14, color: WC.brownLight),
                    const SizedBox(width: 4),
                    const Text(
                      "No attendance taken today",
                      style: TextStyle(
                        color: WC.brownLight,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],

                  const Spacer(),

                  const Text(
                    "View details →",
                    style: TextStyle(
                      color: WC.brownLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 15),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: avgPct / 100,
                  minHeight: 5,
                  backgroundColor: WC.divider,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Mini chip helper
// ─────────────────────────────────────────────────────────────
class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}