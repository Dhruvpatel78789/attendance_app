
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:attendance_system/services/mongodb_service.dart';
import 'attendance_detail_page.dart';

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

// ── Human-readable date formatter ───────────────────────────
String _prettyDate(String iso) {
  final parts = iso.split('-');
  if (parts.length < 3) return iso;
  try {
    final dt = DateTime(
        int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    const days   = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return "${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month]} ${dt.year}";
  } catch (_) {
    return iso;
  }
}

String get _todayIso {
  final n = DateTime.now();
  return "${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}";
}

// ─────────────────────────────────────────────────────────────
//  ClassAttendancePage  –  Single class attendance view
// ─────────────────────────────────────────────────────────────
class ClassAttendancePage extends StatefulWidget {
  final String classId;
  const ClassAttendancePage({super.key, required this.classId});

  @override
  State<ClassAttendancePage> createState() => _ClassAttendancePageState();
}

class _ClassAttendancePageState extends State<ClassAttendancePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
                Expanded(
                  child: Text(
                    "Class ${widget.classId}",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: WC.brown,
                    ),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 8),

            // ── Tab bar ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: WC.cardBg.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: WC.divider),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelPadding: const EdgeInsets.symmetric(vertical: 1, horizontal: 5),

                  // 2. Ensures the brown box expands to fill the padded space
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: WC.brown,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: WC.brownLight,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  tabs: const [
                    Tab(text: "Today's Attendance"),
                    Tab(text: "History"),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Tab content ───────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Today's tab
                  _TodayAttendanceView(classId: widget.classId),

                  // History tab
                  _HistoryAttendanceView(
                    classId: widget.classId,
                    searchQuery: _searchQuery,
                    onSearchChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Today's Attendance View
// ─────────────────────────────────────────────────────────────
class _TodayAttendanceView extends StatelessWidget {
  final String classId;
  const _TodayAttendanceView({required this.classId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('attendance')
          .where('classId', isEqualTo: classId)
          .where('date', isEqualTo: _todayIso)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              "Error loading today's attendance",
              style: TextStyle(color: WC.brown),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: WC.terra),
          );
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_busy_rounded,
                  size: 80,
                  color: WC.brownLight.withOpacity(0.4),
                ),
                const SizedBox(height: 16),
                const Text(
                  "No attendance taken today",
                  style: TextStyle(
                    color: WC.brownLight,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Class $classId",
                  style: const TextStyle(
                    color: WC.brownLight,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [

                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // We have today's attendance
        final data = docs.first.data() as Map<String, dynamic>;

        return _AttendanceRecordCard(
          data: data,
          showDate: false, // Don't show date for today's view
          isToday: true,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  History Attendance View
// ─────────────────────────────────────────────────────────────
class _HistoryAttendanceView extends StatelessWidget {
  final String classId;
  final String searchQuery;
  final Function(String) onSearchChanged;

  const _HistoryAttendanceView({
    required this.classId,
    required this.searchQuery,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
                hintText: "Search by date…",
                hintStyle: TextStyle(color: WC.brownLight),
                prefixIcon: Icon(Icons.search, color: WC.brownLight, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 13),
              ),
              onChanged: onSearchChanged,
            ),
          ),
        ),

        // Debug info
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: WC.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: WC.amber.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: WC.amber),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "Looking for: Class '$classId'",
                    style: const TextStyle(
                      color: WC.brown,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // History list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('attendance')
                .where('classId', isEqualTo: classId)
                .snapshots(),
            builder: (context, snapshot) {
              // Show loading state
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: WC.terra),
                );
              }

              // Show error with details
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: WC.red),
                        const SizedBox(height: 12),
                        const Text(
                          "Error loading attendance",
                          style: TextStyle(
                            color: WC.brown,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: WC.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            snapshot.error.toString(),
                            style: const TextStyle(
                              color: WC.brown,
                              fontSize: 11,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: WC.terra),
                );
              }

              var docs = snapshot.data!.docs;

              // Debug: show total docs found
              print('DEBUG: Found ${docs.length} attendance records for class $classId');

              // Sort by date descending (most recent first)
              docs.sort((a, b) {
                final dateA = (a.data() as Map<String, dynamic>)['date'] ?? '';
                final dateB = (b.data() as Map<String, dynamic>)['date'] ?? '';
                return dateB.toString().compareTo(dateA.toString());
              });

              // Apply search filter
              final originalCount = docs.length;
              if (searchQuery.isNotEmpty) {
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final date = (data['date'] ?? '').toString().toLowerCase();
                  return date.contains(searchQuery.toLowerCase()) ||
                      _prettyDate(date).toLowerCase().contains(searchQuery.toLowerCase());
                }).toList();
              }

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 64,
                        color: WC.brownLight.withOpacity(0.4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        searchQuery.isEmpty
                            ? "No attendance records for Class $classId"
                            : "No records found for '$searchQuery'",
                        style: const TextStyle(
                          color: WC.brownLight,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      if (searchQuery.isEmpty) ...[
                        const Text(
                          "Records will appear here once attendance is taken",
                          style: TextStyle(
                            color: WC.brownLight,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          decoration: BoxDecoration(
                            color: WC.cardBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: WC.divider),
                          ),
                          child: Text(
                            'Query: classId == "$classId"\nTotal records in DB: $originalCount',
                            style: const TextStyle(
                              color: WC.brownLight,
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final date = data['date'] ?? '';
                  final isToday = date == _todayIso;

                  return _AttendanceRecordCard(
                    data: data,
                    showDate: true,
                    isToday: isToday,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Attendance Record Card (reusable)
// ─────────────────────────────────────────────────────────────
class _AttendanceRecordCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool showDate;
  final bool isToday;

  const _AttendanceRecordCard({
    required this.data,
    required this.showDate,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final classId = data['classId'] ?? '';
    final date = data['date'] ?? '';
    final present = (data['present'] ?? 0) as int;
    final absent = (data['absent'] ?? 0) as int;
    final total = (data['total'] ?? (present + absent)) as int;
    final pct = total > 0 ? (present / total * 100) : 0.0;
    final isLow = pct < 75 && total > 0;
    final color = isLow ? WC.red : WC.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: WC.cardBg.withOpacity(0.93),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isToday ? WC.amber : WC.divider, width: isToday ? 2 : 1),
        boxShadow: [
          BoxShadow(
            color: WC.brown.withOpacity(isToday ? 0.12 : 0.07),
            blurRadius: isToday ? 12 : 6,
            offset: Offset(0, isToday ? 4 : 2),
          )
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AttendanceDetailPage(data: data),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Date icon (if showing date)
                  if (showDate) ...[
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.calendar_today_rounded,
                          color: color,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                  ],

                  // Date and info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showDate) ...[
                          Row(
                            children: [
                              Text(
                                _prettyDate(date),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: WC.brown,
                                ),
                              ),
                              if (isToday) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
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
                        ],
                        Text(
                          "$total students recorded",
                          style: TextStyle(
                            color: WC.brownLight,
                            fontSize: showDate ? 12 : 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Percentage badge
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
                            "${pct.toStringAsFixed(0)}%",
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: WC.brownLight,
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Stats row
              Row(
                children: [
                  _MiniChip(label: "$present Present", color: WC.green),
                  const SizedBox(width: 6),
                  _MiniChip(label: "$absent Absent", color: WC.red),
                  const Spacer(),
                  const Text(
                    "View details",
                    style: TextStyle(
                      color: WC.brownLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct / 100,
                  minHeight: 6,
                  backgroundColor: WC.divider,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),

              // Additional info for today's view
              if (!showDate && isToday) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: WC.brown.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: WC.divider),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 14, color: WC.brown),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Tap to view detailed student list",
                          style: TextStyle(
                            color: WC.brown.withOpacity(0.8),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}