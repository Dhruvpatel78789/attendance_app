import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:attendance_system/services/mongodb_service.dart';

// ── Warli colour palette (shared) ──────────────────────────
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

class ApproveLeavePage extends StatefulWidget {
  const ApproveLeavePage({super.key});
  @override
  State<ApproveLeavePage> createState() => _ApproveLeavePageState();
}

class _ApproveLeavePageState extends State<ApproveLeavePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(String docId, String status) async {
    await FirebaseFirestore.instance
        .collection('leave_requests')
        .doc(docId)
        .update({'status': status});
  }

  Future<void> _confirmReject(String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: WC.cardBg,
        title: Text("Reject Leave",
            style: TextStyle(color: WC.brown, fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to reject this leave?",
            style: TextStyle(color: WC.brownLight)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text("Cancel", style: TextStyle(color: WC.brownLight))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text("Reject",
                  style: TextStyle(color: WC.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (confirmed == true) await _updateStatus(docId, 'rejected');
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
        Positioned.fill(
          child: Image.asset('assets/images/background.png', fit: BoxFit.cover),
        ),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
              child: Row(children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: WC.brown),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(child: Text("Leave Applications",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                        color: WC.brown))),
              ]),
            ),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('leave_requests').snapshots(),
              builder: (ctx, snap) {
                final all = snap.data?.docs.length ?? 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: WC.brown,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text("All  ($all)",
                          style: const TextStyle(color: Colors.white,
                              fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ]),
                );
              },
            ),

            Expanded(child: _LeaveList(
                filter: 'all',
                onUpdate: _updateStatus,
                onReject: _confirmReject)),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
//  Leave List
// ─────────────────────────────────────────────
class _LeaveList extends StatelessWidget {
  final String filter;
  final Future<void> Function(String, String) onUpdate;
  final Future<void> Function(String) onReject;

  const _LeaveList(
      {required this.filter, required this.onUpdate, required this.onReject});

  @override
  Widget build(BuildContext context) {
    Query q = FirebaseFirestore.instance
        .collection('leave_requests')
        .orderBy('timestamp', descending: true);
    if (filter != 'all') q = q.where('type', isEqualTo: filter);

    return StreamBuilder<QuerySnapshot>(
      stream: q.snapshots(),
      builder: (ctx, snap) {
        if (snap.hasError) return Center(
            child: Text("Error loading", style: TextStyle(color: WC.brown)));
        if (!snap.hasData) return Center(
            child: CircularProgressIndicator(color: WC.terra));

        final docs = snap.data!.docs;
        if (docs.isEmpty) return Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available_rounded, size: 64,
                color: WC.brownLight.withOpacity(0.4)),
            const SizedBox(height: 12),
            Text("No leave requests",
                style: TextStyle(color: WC.brownLight, fontSize: 16)),
          ],
        ));

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final doc  = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            return _LeaveCard(
              docId: doc.id,
              data: data,
              onApprove: () => onUpdate(doc.id, 'approved'),
              onReject: () => onReject(doc.id),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  Leave Card
// ─────────────────────────────────────────────
class _LeaveCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback onApprove, onReject;

  const _LeaveCard(
      {required this.docId, required this.data,
        required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('leave_requests')
          .doc(docId)
          .snapshots(),
      builder: (ctx, snap) {
        final live = snap.hasData && snap.data!.exists
            ? snap.data!.data() as Map<String, dynamic>
            : data;

        return _LeaveCardContent(
          docId: docId,
          data: live,
          onApprove: onApprove,
          onReject: onReject,
        );
      },
    );
  }
}

class _LeaveCardContent extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback onApprove, onReject;

  const _LeaveCardContent(
      {required this.docId, required this.data,
        required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final type      = data['type'] ?? 'student';
    final status    = data['status'] ?? 'pending';
    final isStudent = type == 'student';
    final isPending = status == 'pending';
    final isToday   = data['isToday'] == true; // ← check isToday flag

    final name    = isStudent
        ? (data['studentName'] ?? 'Unknown')
        : (data['teacherName'] ?? 'Unknown Teacher');
    final subInfo = isStudent
        ? "Class ${data['classId'] ?? '-'}"
        : (data['teacherEmail'] ?? '');
    final reason  = data['reason'] ?? '';

    // ── Date / Time values depending on isToday ───────────
    final from = isToday
        ? (data['fromTime'] ?? data['fromDate'] ?? '')
        : (data['fromDate'] ?? '');
    final to = isToday
        ? (data['toTime'] ?? data['toDate'] ?? '')
        : (data['toDate'] ?? '');
    final todayDate = data['fromDate'];
    // ── Exit tracking ─────────────────────────────────────
    final exitStatus = (data['exitStatus'] ?? 'pending_exit').toString();
    final hasExited  = exitStatus == 'exited';

    String exitTimeStr = '';
    if (hasExited && data['exitTime'] != null) {
      final raw = data['exitTime'];
      if (raw is Timestamp) {
        final dt = raw.toDate().toLocal();
        exitTimeStr =
        "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
      } else {
        exitTimeStr = raw.toString();
      }
    }

    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : '?';

    Color stColor; Color stBg; String stLabel;
    switch (status) {
      case 'approved':
        stColor = WC.green; stBg = WC.green.withOpacity(0.12);
        stLabel = "Approved"; break;
      case 'rejected':
        stColor = WC.red; stBg = WC.red.withOpacity(0.12);
        stLabel = "Rejected"; break;
      default:
        stColor = WC.amber; stBg = WC.amber.withOpacity(0.15);
        stLabel = "Pending";
    }

    final exitColor = hasExited ? WC.green : WC.terra;
    final exitBg    = hasExited
        ? WC.green.withOpacity(0.10) : WC.terra.withOpacity(0.10);
    final exitLabel = hasExited ? "Exited" : "Pending Exit";
    final exitIcon  = hasExited
        ? Icons.exit_to_app_rounded : Icons.hourglass_top_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: WC.cardBg.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WC.divider),
        boxShadow: [BoxShadow(color: WC.brown.withOpacity(0.10),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Header ────────────────────────────────────────
          Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: WC.terra.withOpacity(0.15),
              child: Text(initials, style: const TextStyle(
                  color: WC.terra, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15, color: WC.brown)),
                const SizedBox(height: 3),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: WC.brown.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(isStudent ? "Student" : "Teacher",
                        style: const TextStyle(color: WC.brown,
                            fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 6),
                  Text(subInfo, style: TextStyle(
                      color: WC.brownLight, fontSize: 11)),
                ]),
              ],
            )),
            // Status chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: stBg,
                  borderRadius: BorderRadius.circular(20)),
              child: Text(stLabel, style: TextStyle(
                  color: stColor, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ]),

          const SizedBox(height: 10),
          Divider(color: WC.divider, height: 1),
          const SizedBox(height: 10),

          // ── Reason ────────────────────────────────────────
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline_rounded, size: 14, color: WC.brownLight),
            const SizedBox(width: 6),
            Expanded(child: Text(reason, style: TextStyle(
                color: WC.brown, fontSize: 13, height: 1.4))),
          ]),

          const SizedBox(height: 10),

          // ── Dates OR Times (based on isToday) ─────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: WC.amber.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: WC.amber.withOpacity(0.25)),
            ),
            child: Row(children: [
              Icon(
                // clock icon for same-day time, calendar for date range
                isToday
                    ? Icons.access_time_rounded
                    : Icons.calendar_today_rounded,
                size: 13,
                color: WC.amber,
              ),
              const SizedBox(width: 6),
              // "Today •" prefix when isToday so context is clear
              if (isToday)
                Text("$todayDate •  ",
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: WC.brownLight)),
              Text("$from  →  $to",
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: WC.brown)),
            ]),
          ),

          const SizedBox(height: 10),

          // ── Exit Tracking ─────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: exitBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: exitColor.withOpacity(0.30)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              Row(children: [
                Icon(Icons.door_front_door_rounded, size: 15, color: exitColor),
                const SizedBox(width: 6),
                Text("Exit Tracking",
                    style: TextStyle(color: exitColor,
                        fontWeight: FontWeight.w800, fontSize: 12,
                        letterSpacing: 0.5)),
                const Spacer(),
                Container(width: 7, height: 7,
                    decoration: BoxDecoration(
                        color: hasExited ? WC.green : WC.amber,
                        shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text(hasExited ? "Live" : "Watching",
                    style: TextStyle(fontSize: 10, color: WC.brownLight)),
              ]),

              const SizedBox(height: 10),

              _ExitInfoRow(icon: Icons.person_rounded, label: "Name", value: name),

              if (isStudent) ...[
                const SizedBox(height: 6),
                _ExitInfoRow(
                  icon: Icons.class_rounded,
                  label: "Class",
                  value: data['classId']?.toString() ?? '-',
                ),
              ],

              const SizedBox(height: 8),

              Row(children: [
                Icon(exitIcon, size: 14, color: exitColor),
                const SizedBox(width: 6),
                Text("Exit Status:",
                    style: TextStyle(fontSize: 12, color: WC.brownLight)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: exitColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: exitColor.withOpacity(0.35)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(exitIcon, size: 11, color: exitColor),
                    const SizedBox(width: 5),
                    Text(exitLabel, style: TextStyle(
                        color: exitColor, fontWeight: FontWeight.bold,
                        fontSize: 11)),
                  ]),
                ),
              ]),

              if (hasExited && exitTimeStr.isNotEmpty) ...[
                const SizedBox(height: 6),
                _ExitInfoRow(
                  icon: Icons.access_time_filled_rounded,
                  label: "Exit Time",
                  value: exitTimeStr,
                  valueColor: WC.green,
                ),
              ],
            ]),
          ),

          // ── Action buttons ────────────────────────────────
          if (isPending) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: onReject,
                icon: Icon(Icons.close_rounded, size: 16, color: WC.red),
                label: Text("Reject", style: TextStyle(color: WC.red)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: WC.red),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(
                onPressed: onApprove,
                icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                label: const Text("Approve", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WC.green,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  elevation: 0,
                ),
              )),
            ]),
          ],
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Exit info row helper
// ─────────────────────────────────────────────
class _ExitInfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color? valueColor;
  const _ExitInfoRow(
      {required this.icon, required this.label,
        required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: WC.brownLight),
      const SizedBox(width: 6),
      Text("$label: ", style: TextStyle(fontSize: 12, color: WC.brownLight)),
      Expanded(child: Text(value,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
              color: valueColor ?? WC.brown),
          overflow: TextOverflow.ellipsis)),
    ]);
  }
}