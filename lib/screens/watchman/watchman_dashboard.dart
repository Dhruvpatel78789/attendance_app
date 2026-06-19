import 'package:flutter/material.dart';
import 'package:attendance_system/services/mongodb_service.dart';
import '/services/auth_service.dart';
import '/login_page.dart';
import '../admin/admin_dashboard.dart'; // ← shared AppTheme + WarliAppBar + WarliSectionTitle

class WatchmanDashboard extends StatefulWidget {
  const WatchmanDashboard({super.key});
  @override
  State<WatchmanDashboard> createState() => _WatchmanDashboardState();
}

class _WatchmanDashboardState extends State<WatchmanDashboard> {
  final Set<String> _seenIds          = {};
  final Set<String> _markingInProgress = {};

  // ── Color helpers ────────────────────────────────────────
  static const _green  = Color(0xFF528751);
  static const _red    = Color(0xFFC75146);
  static const _amber  = Color(0xFFE29A3B);

  String _formatTime(DateTime dt) {
    final h      = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m      = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return "$h:$m $period";
  }

  String _formatTimestamp(Timestamp ts) {
    final dt     = ts.toDate().toLocal();
    final h      = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m      = dt.minute.toString().padLeft(2, '0');
    final s      = dt.second.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return "$h:$m:$s $period";
  }

  Future<void> _markAsLeft(BuildContext ctx, String docId, String id) async {
    setState(() => _markingInProgress.add(docId));
    try {
      final exitTime = DateTime.now();
      await FirebaseFirestore.instance.collection('leave_requests').doc(docId).update({
        'status'    : 'exited',
        'exitStatus': 'exited',
        'exitTime'  : Timestamp.fromDate(exitTime),
      });
      setState(() { _seenIds.add(id); _markingInProgress.remove(docId); });
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.exit_to_app_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text("Exit recorded at ${_formatTime(exitTime)}", style: const TextStyle(color: Colors.white)),
          ]),
          backgroundColor: AppTheme.textDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ));
      }
    } catch (e) {
      setState(() => _markingInProgress.remove(docId));
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return Scaffold(
      body: Container(
        decoration: AppTheme.bgDecoration,
        child: SafeArea(
          child: Column(
            children: [
              // ── AppBar ────────────────────────────────────────
              WarliAppBar(
                title: "Gatekeeper Dashboard",
                trailing: IconButton(
                  icon: const Icon(Icons.logout_rounded, color: AppTheme.textDark, size: 22),
                  onPressed: () async {
                    await authService.logout();
                    if (!context.mounted) return;
                    Navigator.pushAndRemoveUntil(
                        context, MaterialPageRoute(builder: (_) => const LoginPage()), (r) => false);
                  },
                ),
              ),

              // ── Body ──────────────────────────────────────────
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('leave_requests')
                      .where('status', whereIn: ['approved', 'exited'])
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator(color: AppTheme.primary));
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text("Error: ${snapshot.error}",
                          style: TextStyle(color: AppTheme.textDark)));
                    }

                    final docs = List.from(snapshot.data?.docs ?? []);
                    docs.sort((a, b) {
                      final aD = a.data() as Map<String, dynamic>;
                      final bD = b.data() as Map<String, dynamic>;
                      if (aD['status'] != bD['status']) {
                        if (aD['status'] == 'approved') return -1;
                        if (bD['status'] == 'approved') return  1;
                      }
                      final aTs = aD['timestamp'];
                      final bTs = bD['timestamp'];
                      if (aTs == null && bTs == null) return 0;
                      if (aTs == null) return  1;
                      if (bTs == null) return -1;
                      return (bTs as Timestamp).compareTo(aTs as Timestamp);
                    });

                    final total         = docs.length;
                    final approvedCount = docs.where((d) => (d.data() as Map)['status'] == 'approved').length;
                    final exitedCount   = docs.where((d) => (d.data() as Map)['status'] == 'exited').length;
                    int newAlerts = 0;
                    for (var doc in docs) {
                      final d  = doc.data() as Map<String, dynamic>;
                      final id = d['grNumber'] ?? d['teacherEmail'] ?? doc.id;
                      if (d['status'] == 'approved' && !_seenIds.contains(id)) newAlerts++;
                    }

                    return Column(children: [
                      // ── Stats banner ────────────────────────
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.78),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.secondary.withOpacity(0.3)),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text("Leave Applications Overview",
                              style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text("$approvedCount pending  •  $exitedCount exited today",
                              style: TextStyle(color: AppTheme.textDark.withOpacity(0.65), fontSize: 13)),
                          const SizedBox(height: 12),
                          Row(children: [
                            _Chip(
                              icon: Icons.check_circle_rounded,
                              label: "$approvedCount Approved",
                              color: AppTheme.textDark,
                              bg: AppTheme.textDark.withOpacity(0.15),
                            ),
                            const SizedBox(width: 8),
                            _Chip(
                              icon: Icons.exit_to_app_rounded,
                              label: "$exitedCount Exited",
                              color: _amber,
                              bg: _amber.withOpacity(0.18),
                            ),
                            if (newAlerts > 0) ...[
                              const SizedBox(width: 8),
                              _Chip(
                                icon: Icons.notifications_active_rounded,
                                label: "$newAlerts New",
                                color: _red,
                                bg: _red.withOpacity(0.18),
                                onTap: () => setState(() {
                                  for (var doc in docs) {
                                    final d  = doc.data() as Map<String, dynamic>;
                                    final id = d['grNumber'] ?? d['teacherEmail'] ?? doc.id;
                                    _seenIds.add(id);
                                  }
                                }),
                              ),
                            ],
                          ]),
                        ]),
                      ),

                      const SizedBox(height: 12),

                      if (total == 0)
                        Expanded(child: Center(child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline_rounded,
                                size: 72, color: AppTheme.primary.withOpacity(0.3)),
                            const SizedBox(height: 16),
                            Text("No leave applications",
                                style: TextStyle(color: AppTheme.textDark, fontSize: 16, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Text("All students & teachers are present",
                                style: TextStyle(color: AppTheme.textDark.withOpacity(0.55), fontSize: 13)),
                          ],
                        )))
                      else
                        Expanded(child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                          itemCount: docs.length,
                          itemBuilder: (ctx, i) {
                            final doc  = docs[i];
                            final data = doc.data() as Map<String, dynamic>;
                            final id   = data['grNumber'] ?? data['teacherEmail'] ?? doc.id;
                            final isNew     = !_seenIds.contains(id) && data['status'] == 'approved';
                            final isMarking = _markingInProgress.contains(doc.id);
                            return _LeaveCard(
                              docId: doc.id, data: data,
                              isNew: isNew, isMarking: isMarking,
                              onSeen: () => setState(() => _seenIds.add(id)),
                              onMarkAsLeft: () => _markAsLeft(ctx, doc.id, id),
                              formatTs: _formatTimestamp,
                            );
                          },
                        )),
                    ]);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Small chip badge
// ─────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color, bg;
  final VoidCallback? onTap;
  const _Chip({required this.icon, required this.label, required this.color, required this.bg, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────
//  Leave card
// ─────────────────────────────────────────────
class _LeaveCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final bool isNew, isMarking;
  final VoidCallback onSeen, onMarkAsLeft;
  final String Function(Timestamp) formatTs;
  const _LeaveCard({
    required this.docId, required this.data,
    required this.isNew, required this.isMarking,
    required this.onSeen, required this.onMarkAsLeft,
    required this.formatTs,
  });

  static const _amber = Color(0xFFE29A3B);

  @override
  Widget build(BuildContext context) {
    final isStudent = (data['type'] ?? 'student') == 'student';
    final isExited  = data['status'] == 'exited';
    final isToday   = data['isToday'] == true;

    final name    = isStudent ? (data['studentName'] ?? 'Unknown') : (data['teacherName'] ?? 'Unknown Teacher');
    final subInfo = isStudent ? "Class ${data['classId'] ?? '-'}" : (data['teacherEmail'] ?? '');
    final gr      = data['grNumber'];
    final reason  = data['reason'] ?? '';
    final exitTs  = data['exitTime'] as Timestamp?;
    final from    = isToday ? (data['fromTime'] ?? data['fromDate'] ?? '') : (data['fromDate'] ?? '');
    final to      = isToday ? (data['toTime']   ?? data['toDate']   ?? '') : (data['toDate']   ?? '');

    final now       = DateTime.now();
    final todayDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final initials    = name.isNotEmpty ? name.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase() : '?';
    final accentColor = isExited ? AppTheme.primary : AppTheme.textDark;

    return GestureDetector(
      onTap: onSeen,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardBg.withOpacity(0.88),
          borderRadius: BorderRadius.circular(14),
          border: isNew
              ? Border.all(color: AppTheme.textDark, width: 2)
              : Border.all(color: AppTheme.primary.withOpacity(0.2)),
          boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Header ──────────────────────────────────────
            Row(children: [
              Container(
                width: 4, height: 44,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(4)),
              ),
              CircleAvatar(
                radius: 22,
                backgroundColor: accentColor.withOpacity(0.12),
                child: Text(initials, style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(name,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textDark))),
                  if (isNew) Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: AppTheme.textDark, borderRadius: BorderRadius.circular(20)),
                    child: Text("NEW", style: TextStyle(color: AppTheme.cardBg, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 3),
                Row(children: [
                  Text(subInfo, style: TextStyle(color: AppTheme.textDark.withOpacity(0.7), fontSize: 12)),
                  if (gr != null) ...[
                    const SizedBox(width: 6),
                    Container(width: 3, height: 3,
                        decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.5), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text("GR: $gr", style: TextStyle(color: AppTheme.textDark.withOpacity(0.6), fontSize: 11)),
                  ],
                ]),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accentColor.withOpacity(0.25))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(isExited ? Icons.exit_to_app_rounded : Icons.check_circle_rounded, size: 12, color: accentColor),
                  const SizedBox(width: 4),
                  Text(isExited ? "Exited" : "Approved",
                      style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.bold)),
                ]),
              ),
            ]),

            const SizedBox(height: 12),
            Divider(height: 1, color: AppTheme.primary.withOpacity(0.15)),
            const SizedBox(height: 10),

            // ── Date / time ──────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _amber.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _amber.withOpacity(0.25)),
              ),
              child: Row(children: [
                Icon(isToday ? Icons.access_time_rounded : Icons.calendar_today_rounded, size: 13, color: _amber),
                const SizedBox(width: 6),
                if (isToday) Text("$todayDate  •  ",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textDark.withOpacity(0.55))),
                Text("$from  →  $to",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
              ]),
            ),

            const SizedBox(height: 10),

            // ── Reason ───────────────────────────────────────
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.comment_rounded, size: 13, color: AppTheme.primary.withOpacity(0.5)),
              const SizedBox(width: 6),
              Expanded(child: Text(reason,
                  style: TextStyle(color: AppTheme.textDark.withOpacity(0.75), fontSize: 13, height: 1.4))),
            ]),

            // ── Exit time ────────────────────────────────────
            if (isExited && exitTs != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.22)),
                ),
                child: Row(children: [
                  Icon(Icons.access_time_filled_rounded, size: 15, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Text("Left campus at  ", style: TextStyle(color: AppTheme.textDark.withOpacity(0.7), fontSize: 12)),
                  Text(formatTs(exitTs),
                      style: TextStyle(color: AppTheme.textDark, fontSize: 13, fontWeight: FontWeight.bold)),
                ]),
              ),
            ],

            // ── Mark as left button ──────────────────────────
            if (!isExited) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isMarking ? null : onMarkAsLeft,
                  icon: isMarking
                      ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.exit_to_app_rounded, size: 16),
                  label: Text(isMarking ? "Recording Exit..." : "Mark as Left",
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isMarking ? AppTheme.primary.withOpacity(0.5) : AppTheme.textDark,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.primary.withOpacity(0.4),
                    disabledForegroundColor: Colors.white70,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}