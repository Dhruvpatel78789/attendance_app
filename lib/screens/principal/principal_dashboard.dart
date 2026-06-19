
import 'package:flutter/material.dart';
import 'package:attendance_system/services/mongodb_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'approve_leave_page.dart';
import '/services/auth_service.dart';
import '/login_page.dart';
import 'view_attendance_page.dart';
import '../admin/admin_dashboard.dart'; // shared AppTheme + WarliAppBar + WarliSectionTitle

// ── Chart line colours ──────────────────────────────────────
const _kBoysColor  = Color(0xFF4A7EC7); // blue
const _kGirlsColor = Color(0xFFD67845); // terra
const _kTotalColor = Color(0xFF528751); // green

class PrincipalDashboard extends StatefulWidget {
  const PrincipalDashboard({super.key});
  @override
  State<PrincipalDashboard> createState() => _PrincipalDashboardState();
}

class _PrincipalDashboardState extends State<PrincipalDashboard> {
  DateTime _selectedDay = DateTime.now();

  String _isoDate(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  String _displayDate(DateTime d) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days   = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return "${days[d.weekday]}, ${d.day} ${months[d.month]} ${d.year}";
  }

  String get _todayDisplayDate => _displayDate(DateTime.now());
  String get _selectedIsoDate  => _isoDate(_selectedDay);

  // ── Fetch dashboard data ───────────────────────────────────
  // Reads the FLAT structure: each attendance doc has
  //   boys (int), girls (int), present (int), absent (int),
  //   total (int), classId (string), date (string)
  Future<Map<String, dynamic>> _fetchDashboardData() async {
    final fs = FirebaseFirestore.instance;

    /// ✅ 1. Fetch classes (totals)
    final classSnap = await fs.collection('classes').get();

    final Map<String, Map<String, int>> classMap = {};
    for (final doc in classSnap.docs) {
      final data = doc.data();
      classMap[doc.id] = {
        'boys': (data['boys'] ?? 0) as int,
        'girls': (data['girls'] ?? 0) as int,
      };
    }

    /// ✅ 2. Fetch ALL attendance (for chart + cards)
    final attSnap = await fs.collection('attendance').get();

    final Map<String, Map<String, int>> dateStats = {};
    final Set<String> histDates = {};

    int histBoysPresent  = 0;
    int histGirlsPresent = 0;
    int histBoysAbsent   = 0;
    int histGirlsAbsent  = 0;

    /// 🔥 Selected day counters (SEPARATE — THIS WAS MISSING)
    int selBoysPresent  = 0;
    int selGirlsPresent = 0;
    int selBoysAbsent   = 0;
    int selGirlsAbsent  = 0;

    /// ✅ 3. Process all records
    /// 🔥 Track classes counted per date (CRITICAL FIX)
    final Map<String, Set<String>> seenClassesPerDate = {};

    for (final doc in attSnap.docs) {
      final data = doc.data();

      final date    = (data['date'] ?? '') as String;
      final classId = data['classId'];

      final boysPresent  = (data['boys'] ?? 0) as int;
      final girlsPresent = (data['girls'] ?? 0) as int;

      final classData = classMap[classId];
      if (classData == null) continue;

      /// ✅ Initialize per-date tracker
      seenClassesPerDate.putIfAbsent(date, () => <String>{});

      /// ❌ Prevent counting same class twice for same date
      if (seenClassesPerDate[date]!.contains(classId)) continue;

      seenClassesPerDate[date]!.add(classId);

      final totalBoys  = classData['boys']!;
      final totalGirls = classData['girls']!;

      /// ✅ Correct absent calculation
      final boysAbsent  = (totalBoys - boysPresent).clamp(0, totalBoys);
      final girlsAbsent = (totalGirls - girlsPresent).clamp(0, totalGirls);

      histDates.add(date);

      /// ✅ Aggregate per date (for chart)
      dateStats.putIfAbsent(date, () => {
        'bp': 0,
        'gp': 0,
        'ba': 0,
        'ga': 0,
      });

      dateStats[date]!['bp'] = dateStats[date]!['bp']! + boysPresent;
      dateStats[date]!['gp'] = dateStats[date]!['gp']! + girlsPresent;
      dateStats[date]!['ba'] = dateStats[date]!['ba']! + boysAbsent;
      dateStats[date]!['ga'] = dateStats[date]!['ga']! + girlsAbsent;

      /// ✅ History totals (ALL TIME)
      histBoysPresent  += boysPresent;
      histGirlsPresent += girlsPresent;
      histBoysAbsent   += boysAbsent;
      histGirlsAbsent  += girlsAbsent;

      /// ✅ Selected date (CARDS ONLY)
      if (date == _selectedIsoDate) {
        selBoysPresent  += boysPresent;
        selGirlsPresent += girlsPresent;
        selBoysAbsent   += boysAbsent;
        selGirlsAbsent  += girlsAbsent;
      }
    }

    /// ✅ Chart (last 14 days)
    final chartData = List.generate(14, (i) {
      final d   = DateTime.now().subtract(Duration(days: 13 - i));
      final key = _isoDate(d);

      final s = dateStats[key] ?? {
        'bp': 0,
        'gp': 0,
        'ba': 0,
        'ga': 0
      };

      final b = s['bp']!;
      final g = s['gp']!;

      return {'date': key, 'b': b, 'g': g, 't': b + g};
    });

    /// ✅ Historical totals
    final histPresent    = histBoysPresent + histGirlsPresent;
    final histAbsent     = histBoysAbsent + histGirlsAbsent;
    final histTotal      = histPresent + histAbsent;

    final histBoysTotal  = histBoysPresent + histBoysAbsent;
    final histGirlsTotal = histGirlsPresent + histGirlsAbsent;

    return {
      /// 🔥 Cards (correct now)
      'selBoysPresent':   selBoysPresent,
      'selBoysAbsent':    selBoysAbsent,
      'selGirlsPresent':  selGirlsPresent,
      'selGirlsAbsent':   selGirlsAbsent,

      /// History
      'histPresent':      histPresent,
      'histAbsent':       histAbsent,
      'histTotal':        histTotal,
      'histPct':          histTotal > 0 ? histPresent / histTotal * 100 : 0.0,

      'histBoysPresent':  histBoysPresent,
      'histBoysAbsent':   histBoysAbsent,
      'histBoysPct':      histBoysTotal > 0 ? histBoysPresent / histBoysTotal * 100 : 0.0,

      'histGirlsPresent': histGirlsPresent,
      'histGirlsAbsent':  histGirlsAbsent,
      'histGirlsPct':     histGirlsTotal > 0 ? histGirlsPresent / histGirlsTotal * 100 : 0.0,

      'histDays':         histDates.length,
      'chartData':        chartData,
      'availableDates':   histDates.toList(),
    };
  }

  // ── Date picker ───────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppTheme.primary,
            onPrimary: AppTheme.textDark,
            surface: AppTheme.cardBg,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDay) {
      setState(() => _selectedDay = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return Scaffold(
      body: Container(
        decoration: AppTheme.bgDecoration,
        child: SafeArea(
          child: Column(children: [

            WarliAppBar(
              title: "Principal Dashboard",
              trailing: IconButton(
                icon: const Icon(Icons.logout_rounded, color: AppTheme.textDark, size: 22),
                onPressed: () async {
                  await authService.logout();
                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                          (r) => false);
                },
              ),
            ),

            Expanded(
              child: RefreshIndicator(
                color: AppTheme.primary,
                onRefresh: () async => setState(() {}),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── Welcome card ────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.78),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.secondary.withOpacity(0.3)),
                        ),
                        child: Row(children: [
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Welcome Back 👋",
                                  style: TextStyle(color: AppTheme.textDark.withOpacity(0.7), fontSize: 13)),
                              const SizedBox(height: 4),
                              const Text("Principal",
                                  style: TextStyle(color: AppTheme.textDark,
                                      fontWeight: FontWeight.bold, fontSize: 20)),
                              const SizedBox(height: 8),
                              Text(_todayDisplayDate,
                                  style: TextStyle(color: AppTheme.textDark.withOpacity(0.6), fontSize: 12)),
                            ],
                          )),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: AppTheme.textDark.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.school_rounded, color: AppTheme.textDark, size: 28),
                          ),
                        ]),
                      ),

                      const SizedBox(height: 22),

                      // ── Quick actions ────────────────────────
                      WarliSectionTitle(title: "QUICK ACTIONS"),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: _PrincipalCard(
                          icon: Icons.how_to_reg_rounded,
                          title: "Class\nAttendance",
                          subtitle: "Full day-wise history\nof all classes",
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const ViewAttendancePage())),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _PrincipalCard(
                          icon: Icons.event_note_rounded,
                          title: "Leave\nApplications",
                          subtitle: "Approve or reject\nstudent leave requests",
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const ApproveLeavePage())),
                        )),
                      ]),

                      const SizedBox(height: 26),

                      // ── Combined async section ───────────────
                      FutureBuilder<Map<String, dynamic>>(
                        future: _fetchDashboardData(),
                        builder: (context, snap) {
                          if (!snap.hasData) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 48),
                              child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                            );
                          }
                          if (snap.hasError) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Center(child: Text("Failed to load data",
                                  style: TextStyle(color: AppTheme.textDark.withOpacity(0.5)))),
                            );
                          }

                          final d         = snap.data!;
                          final chartData = d['chartData'] as List<Map<String, dynamic>>;
                          print(d['selBoysAbsent']);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                              // ── DAY-WISE ATTENDANCE ───────────
                              Row(children: [
                                Expanded(
                                  child: _SectionHeader(
                                    title: "DAILY ATTENDANCE",
                                    badge: _displayDate(_selectedDay),
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 8),

                              _DateSelectorRow(
                                selectedDay: _selectedDay,
                                onPickDate: _pickDate,
                                onPrev: () => setState(() =>
                                _selectedDay = _selectedDay.subtract(const Duration(days: 1))),
                                onNext: _selectedDay.isBefore(DateTime.now().subtract(const Duration(days: 1)))
                                    ? () => setState(() =>
                                _selectedDay = _selectedDay.add(const Duration(days: 1)))
                                    : null,
                                onToday: () => setState(() => _selectedDay = DateTime.now()),
                              ),

                              const SizedBox(height: 10),

                              Row(children: [
                                Expanded(child: _GenderAttendancePanel(
                                  label: "Boys",
                                  icon: Icons.male_rounded,
                                  color: _kBoysColor,
                                  present: d['selBoysPresent'] as int,
                                  absent:  d['selBoysAbsent']  as int,
                                )),
                                const SizedBox(width: 12),
                                Expanded(child: _GenderAttendancePanel(
                                  label: "Girls",
                                  icon: Icons.female_rounded,
                                  color: _kGirlsColor,
                                  present: d['selGirlsPresent'] as int,
                                  absent:  d['selGirlsAbsent']  as int,
                                )),
                              ]),

                              const SizedBox(height: 26),

                              // ── HISTORICAL INSIGHTS + CHART ───
                              _SectionHeader(
                                  title: "HISTORICAL INSIGHTS",
                                  badge: "${d['histDays']} Days"),
                              const SizedBox(height: 10),
                              _HistoricalInsightsCard(
                                totalPresent:      d['histPresent']      as int,
                                totalAbsent:       d['histAbsent']       as int,
                                total:             d['histTotal']        as int,
                                pct:               d['histPct']          as double,
                                daysRecorded:      d['histDays']         as int,
                                boysPresent:       d['histBoysPresent']  as int,
                                boysAbsent:        d['histBoysAbsent']   as int,
                                boysPct:           d['histBoysPct']      as double,
                                girlsPresent:      d['histGirlsPresent'] as int,
                                girlsAbsent:       d['histGirlsAbsent']  as int,
                                girlsPct:          d['histGirlsPct']     as double,
                                chartData:         chartData,
                              ),

                              const SizedBox(height: 20),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Date Selector Row
// ─────────────────────────────────────────────────────────────
class _DateSelectorRow extends StatelessWidget {
  final DateTime selectedDay;
  final VoidCallback onPickDate;
  final VoidCallback onPrev;
  final VoidCallback? onNext;
  final VoidCallback onToday;

  const _DateSelectorRow({
    required this.selectedDay,
    required this.onPickDate,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  bool get _isToday {
    final now = DateTime.now();
    return selectedDay.year == now.year &&
        selectedDay.month == now.month &&
        selectedDay.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBg.withOpacity(0.80),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withOpacity(0.18)),
      ),
      child: Row(children: [
        _NavBtn(icon: Icons.chevron_left_rounded, onTap: onPrev),
        Expanded(
          child: GestureDetector(
            onTap: onPickDate,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 14, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(
                  _formatDisplay(selectedDay),
                  style: TextStyle(
                    color: AppTheme.textDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_drop_down_rounded,
                    size: 18, color: AppTheme.primary.withOpacity(0.6)),
              ],
            ),
          ),
        ),
        if (!_isToday)
          GestureDetector(
            onTap: onToday,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text("Today",
                  style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        _NavBtn(
          icon: Icons.chevron_right_rounded,
          onTap: onNext,
          disabled: onNext == null,
        ),
      ]),
    );
  }

  static String _formatDisplay(DateTime d) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return "${days[d.weekday]}, ${d.day} ${months[d.month]} ${d.year}";
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool disabled;
  const _NavBtn({required this.icon, this.onTap, this.disabled = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: disabled ? null : onTap,
    child: Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: disabled
            ? AppTheme.primary.withOpacity(0.04)
            : AppTheme.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon,
          size: 20,
          color: disabled
              ? AppTheme.textDark.withOpacity(0.2)
              : AppTheme.primary),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
//  Section Header with optional badge
// ─────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? badge;
  const _SectionHeader({required this.title, this.badge});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 4, height: 18,
        decoration: BoxDecoration(color: AppTheme.primary,
            borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    WarliSectionTitle(title: title),
    const Spacer(),
    if (badge != null) Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20)),
      child: Text(badge!,
          style: TextStyle(fontSize: 10, color: AppTheme.primary,
              fontWeight: FontWeight.w600)),
    ),
  ]);
}

// ─────────────────────────────────────────────────────────────
//  Gender Attendance Panel (Boys / Girls)
// ─────────────────────────────────────────────────────────────
class _GenderAttendancePanel extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final int present, absent;
  const _GenderAttendancePanel({
    required this.label, required this.icon, required this.color,
    required this.present, required this.absent,
  });

  @override
  Widget build(BuildContext context) {
    final total = present + absent;
    final pct   = total > 0 ? present / total * 100 : 0.0;
    final isLow = pct < 75 && total > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg.withOpacity(0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.10),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                color: color.withOpacity(0.13),
                borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color,
              fontWeight: FontWeight.bold, fontSize: 15)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.25))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.people_rounded, size: 10, color: color.withOpacity(0.8)),
              const SizedBox(width: 3),
              Text("$total", style: TextStyle(fontSize: 11,
                  color: color, fontWeight: FontWeight.w700)),
            ]),
          ),

        ]),

        const SizedBox(height: 14),

        Text(
          total > 0 ? "${pct.toStringAsFixed(1)}%" : "—",
          style: TextStyle(
            color: isLow ? const Color(0xFFC75146) : color,
            fontWeight: FontWeight.bold,
            fontSize: 26,
          ),
        ),
        Text("attendance rate",
            style: TextStyle(color: AppTheme.textDark.withOpacity(0.45),
                fontSize: 10)),

        const SizedBox(height: 10),

        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: total > 0 ? pct / 100 : 0,
            minHeight: 5,
            backgroundColor: color.withOpacity(0.10),
            valueColor: AlwaysStoppedAnimation<Color>(
              isLow ? const Color(0xFFC75146) : color,
            ),
          ),
        ),

        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.04),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Expanded(child: _StatMini(
              label: "Present",
              value: "$present",
              color: const Color(0xFF528751),
              icon: Icons.check_circle_rounded,
            )),
            Container(width: 1, height: 32,
                color: AppTheme.primary.withOpacity(0.15)),
            Expanded(child: _StatMini(
              label: "Absent",
              value: "$absent",
              color: const Color(0xFFC75146),
              icon: Icons.cancel_rounded,
            )),
          ]),
        ),
      ]),
    );
  }
}

class _StatMini extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _StatMini({required this.label, required this.value,
    required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Column(children: [
    Icon(icon, color: color, size: 14),
    const SizedBox(height: 3),
    Text(value, style: TextStyle(color: color,
        fontWeight: FontWeight.bold, fontSize: 16)),
    Text(label, style: TextStyle(color: AppTheme.textDark.withOpacity(0.45),
        fontSize: 10)),
  ]);
}

// ─────────────────────────────────────────────────────────────
//  Chart Legend
// ─────────────────────────────────────────────────────────────
class _ChartLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: const [
      _LegendItem(color: _kBoysColor,  label: "Boys"),
      SizedBox(width: 16),
      _LegendItem(color: _kGirlsColor, label: "Girls"),
      SizedBox(width: 16),
      _LegendItem(color: _kTotalColor, label: "Total"),
    ],
  );
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 20, height: 3,
            decoration: BoxDecoration(color: color,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(
            color: AppTheme.textDark.withOpacity(0.65),
            fontSize: 11, fontWeight: FontWeight.w500)),
      ]);
}

// ─────────────────────────────────────────────────────────────
//  Attendance Line Chart  (fl_chart)
// ─────────────────────────────────────────────────────────────
class _AttendanceLineChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _AttendanceLineChart({required this.data});

  List<FlSpot> _spots(String key) => data.asMap().entries
      .map((e) => FlSpot(e.key.toDouble(),
      ((e.value[key] ?? 0) as int).toDouble()))
      .toList();

  static String _formatDate(String iso) {
    final parts = iso.split('-');
    if (parts.length < 3) return '';
    const m = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = int.tryParse(parts[1]) ?? 0;
    final day   = int.tryParse(parts[2]) ?? 0;
    return "${m[month]} $day";
  }

  double get _maxY {
    double mx = 4;
    for (final d in data) {
      final t = ((d['t'] ?? 0) as int).toDouble();
      if (t > mx) mx = t;
    }
    return (mx * 1.2).ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        minX: 0, maxX: 13, minY: 0, maxY: _maxY,
        clipData: FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
              color: AppTheme.primary.withOpacity(0.08), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: TextStyle(fontSize: 8,
                    color: AppTheme.textDark.withOpacity(0.45)),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 1,
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                if (idx % 2 != 0) return const SizedBox.shrink();
                if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _formatDate(data[idx]['date'] as String),
                    style: TextStyle(fontSize: 7.5,
                        color: AppTheme.textDark.withOpacity(0.5)),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppTheme.cardBg,
            getTooltipItems: (spots) {
              if (spots.isEmpty) return [];

              final first = spots.first;
              final index = first.x.toInt();

              final dataPoint = data[index];

              final date  = dataPoint['date'];
              final boys  = dataPoint['b'];
              final girls = dataPoint['g'];
              final total = dataPoint['t'];

              return spots.map((s) {
                if (s != first) return null;

                return LineTooltipItem(
                  '', // 🔥 empty base, we use children
                  const TextStyle(), // base style (kept minimal)
                  children: [
                    /// 🔴 DATE (reddish brown)
                    TextSpan(
                      text: "$date\n",
                      style: TextStyle(
                        color: const Color(0xFF6B2D0E), // 👈 reddish-brown
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),

                    /// 👦 Boys (original style)
                    TextSpan(
                      text: "Boys: $boys\n",
                      style: TextStyle(
                        color: _kBoysColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),

                    /// 👧 Girls
                    TextSpan(
                      text: "Girls: $girls\n",
                      style: TextStyle(
                        color: _kGirlsColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),

                    /// 🔢 Total
                    TextSpan(
                      text: "Total: $total",
                      style: TextStyle(
                        color: _kTotalColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          _bar('b', _kBoysColor),
          _bar('g', _kGirlsColor),
          _bar('t', _kTotalColor, width: 2.5),
        ],
      ),
    );
  }

  LineChartBarData _bar(String key, Color color, {double width = 2.2}) =>
      LineChartBarData(
        spots: _spots(key),
        isCurved: true,
        preventCurveOverShooting: true,
        color: color,
        barWidth: width,
        dotData: FlDotData(
          show: true,
          getDotPainter: (s, _, __, ___) => FlDotCirclePainter(
              radius: 2.5, color: color,
              strokeWidth: 1.5, strokeColor: Colors.white),
        ),
        belowBarData: BarAreaData(show: true,
            color: color.withOpacity(key == 't' ? 0.07 : 0.05)),
      );
}

// ─────────────────────────────────────────────────────────────
//  Historical Insights Card
// ─────────────────────────────────────────────────────────────
class _HistoricalInsightsCard extends StatelessWidget {
  final int totalPresent, totalAbsent, total, daysRecorded;
  final double pct;
  final int boysPresent, boysAbsent, girlsPresent, girlsAbsent;
  final double boysPct, girlsPct;
  final List<Map<String, dynamic>> chartData;

  const _HistoricalInsightsCard({
    required this.totalPresent, required this.totalAbsent,
    required this.total, required this.pct, required this.daysRecorded,
    required this.boysPresent, required this.boysAbsent, required this.boysPct,
    required this.girlsPresent, required this.girlsAbsent, required this.girlsPct,
    required this.chartData,
  });

  @override
  Widget build(BuildContext context) {
    final isLow    = pct < 75 && total > 0;
    final barColor = isLow ? const Color(0xFFC75146) : AppTheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg.withOpacity(0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withOpacity(0.18)),
        boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.08),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(total > 0 ? "${pct.toStringAsFixed(1)}%" : "—",
                style: TextStyle(
                    color: isLow ? const Color(0xFFC75146) : AppTheme.primary,
                    fontWeight: FontWeight.bold, fontSize: 32)),
            Text("overall attendance", style: TextStyle(
                color: AppTheme.textDark.withOpacity(0.45), fontSize: 11)),
          ]),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text("$daysRecorded",
                style: TextStyle(color: AppTheme.textDark,
                    fontWeight: FontWeight.bold, fontSize: 22)),
            Text("days recorded", style: TextStyle(
                color: AppTheme.textDark.withOpacity(0.45), fontSize: 11)),
          ]),
        ]),

        const SizedBox(height: 14),

        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: total > 0 ? pct / 100 : 0,
            minHeight: 7,
            backgroundColor: AppTheme.primary.withOpacity(0.08),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),

        const SizedBox(height: 14),

        Row(children: [
          _HistStat(label: "Total Students", value: "$total",
              color: AppTheme.primary, icon: Icons.people_rounded),
          _HistStat(label: "Present", value: "$totalPresent",
              color: const Color(0xFF528751), icon: Icons.check_circle_rounded),
          _HistStat(label: "Absent", value: "$totalAbsent",
              color: const Color(0xFFC75146), icon: Icons.cancel_rounded),
        ]),

        const SizedBox(height: 14),
        Divider(color: AppTheme.primary.withOpacity(0.12), height: 1),
        const SizedBox(height: 14),

        Row(children: [
          Text("Last 14 Days", style: TextStyle(
              color: AppTheme.textDark, fontWeight: FontWeight.w600, fontSize: 13)),
          const Spacer(),
          _ChartLegend(),
        ]),
        const SizedBox(height: 10),

        SizedBox(height: 200, child: _AttendanceLineChart(data: chartData)),

        const SizedBox(height: 16),
        Divider(color: AppTheme.primary.withOpacity(0.12), height: 1),
        const SizedBox(height: 14),

        _GenderHistRow(
          label: "Boys",
          icon: Icons.male_rounded,
          color: _kBoysColor,
          present: boysPresent,
          absent: boysAbsent,
          pct: boysPct,
        ),
        const SizedBox(height: 10),
        _GenderHistRow(
          label: "Girls",
          icon: Icons.female_rounded,
          color: _kGirlsColor,
          present: girlsPresent,
          absent: girlsAbsent,
          pct: girlsPct,
        ),
      ]),
    );
  }
}

class _GenderHistRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final int present, absent;
  final double pct;
  const _GenderHistRow({
    required this.label, required this.icon, required this.color,
    required this.present, required this.absent, required this.pct,
  });

  @override
  Widget build(BuildContext context) {
    final total = present + absent;
    final isLow = pct < 75 && total > 0;
    final barC  = isLow ? const Color(0xFFC75146) : color;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: color,
            fontWeight: FontWeight.w600, fontSize: 12)),
        const Spacer(),
        Text(total > 0 ? "${pct.toStringAsFixed(1)}%" : "—",
            style: TextStyle(color: barC,
                fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(width: 8),
        Text("P: $present  A: $absent",
            style: TextStyle(color: AppTheme.textDark.withOpacity(0.45),
                fontSize: 10)),
      ]),
      const SizedBox(height: 5),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: total > 0 ? pct / 100 : 0,
          minHeight: 4,
          backgroundColor: color.withOpacity(0.08),
          valueColor: AlwaysStoppedAnimation<Color>(barC),
        ),
      ),
    ]);
  }
}

class _HistStat extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _HistStat({required this.label, required this.value,
    required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color,
            fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 2),
        Text(label, textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textDark.withOpacity(0.45),
                fontSize: 9, height: 1.3)),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
//  Quick-action card
// ─────────────────────────────────────────────────────────────
class _PrincipalCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _PrincipalCard({required this.icon, required this.title,
    required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.75),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.secondary.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: AppTheme.textDark.withOpacity(0.9), size: 28),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(color: AppTheme.textDark,
            fontWeight: FontWeight.bold, fontSize: 14, height: 1.3)),
        const SizedBox(height: 5),
        Text(subtitle, style: TextStyle(color: AppTheme.textDark.withOpacity(0.65),
            fontSize: 11, height: 1.4)),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: AppTheme.textDark.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Text("View", style: TextStyle(color: AppTheme.textDark, fontSize: 10)),
              SizedBox(width: 3),
              Icon(Icons.arrow_forward_rounded, size: 10, color: AppTheme.textDark),
            ]),
          ),
        ),
      ]),
    ),
  );
}