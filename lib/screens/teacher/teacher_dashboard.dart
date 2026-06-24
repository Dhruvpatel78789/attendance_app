import 'package:flutter/material.dart';
import 'package:attendance_system/services/mongodb_service.dart';
import 'mark_attendance_page.dart';
import 'create_leave_page.dart';
import '../principal/approve_leave_page.dart';
import '/login_page.dart';
import '/services/auth_service.dart';
import '../admin/admin_dashboard.dart'; // ← shared AppTheme + WarliAppBar + WarliButton + WarliField

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});
  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  String? _displayName;
  String? _classId;
  bool _loadingName = true;

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { setState(() => _loadingName = false); return; }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final name = doc.data()?['name'] as String?;
      final classId = doc.data()?['classId'] as String?;
      setState(() {
        _displayName = (name != null && name.isNotEmpty) ? name : (user.displayName ?? 'Teacher');
        _classId = classId;
        _loadingName = false;
      });
    } catch (_) {
      setState(() { _displayName = user.displayName ?? 'Teacher'; _loadingName = false; });
    }
  }

  String get _todayDate {
    final n = DateTime.now();
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days   = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return "${days[n.weekday]}, ${n.day} ${months[n.month]} ${n.year}";
  }

  // ── Bottom sheet to edit display name ───────────────────────
  void _showEditNameSheet() {
    final controller = TextEditingController(text: _displayName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppTheme.primary.withOpacity(0.18)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // drag handle
              Center(
                child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.25), borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 20),
              Text("Edit Your Name",
                  style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 6),
              Text("This name appears on your dashboard.",
                  style: TextStyle(color: AppTheme.textDark.withOpacity(0.5), fontSize: 13)),
              const SizedBox(height: 20),
              WarliField(controller: controller, label: "Your Name", icon: Icons.person_outline_rounded),
              const SizedBox(height: 20),
              WarliButton(
                label: "Save Name",
                onPressed: () async {
                  final newName = controller.text.trim();
                  if (newName.isEmpty) return;
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;
                  await user.updateDisplayName(newName);
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .set({'name': newName}, SetOptions(merge: true));
                  setState(() => _displayName = newName);
                  if (mounted) Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
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
                title: "Teacher Dashboard",
                trailing: IconButton(
                  icon: const Icon(Icons.logout_rounded, color: AppTheme.textDark, size: 22),
                  onPressed: () async {
                    await authService.logout();
                    if (!context.mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                          (r) => false,
                    );
                  },
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Welcome card ──────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.78),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.secondary.withOpacity(0.3)),
                        ),
                        child: Row(children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Welcome Back 👋",
                                    style: TextStyle(color: AppTheme.textDark.withOpacity(0.7), fontSize: 13)),
                                const SizedBox(height: 4),
                                _loadingName
                                    ? Container(height: 24, width: 140,
                                    decoration: BoxDecoration(
                                        color: AppTheme.textDark.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6)))
                                    : Text(_displayName ?? 'Teacher',
                                    style: const TextStyle(
                                        color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 20)),
                                const SizedBox(height: 8),
                                Text(_todayDate,
                                    style: TextStyle(color: AppTheme.textDark.withOpacity(0.6), fontSize: 12)),
                              ],
                            ),
                          ),
                          // Edit name button
                          GestureDetector(
                            onTap: _showEditNameSheet,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.textDark.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.textDark.withOpacity(0.2)),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.edit_rounded, color: AppTheme.textDark, size: 14),
                                const SizedBox(width: 5),
                                Text("Edit Name",
                                    style: TextStyle(color: AppTheme.textDark, fontSize: 11, fontWeight: FontWeight.w600)),
                              ]),
                            ),
                          ),
                        ]),
                      ),

                      const SizedBox(height: 20),

                      // ── Standing Principal Status Banner ──
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('standing_principals')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox();
                          
                          final now = DateTime.now();
                          final today = DateTime(now.year, now.month, now.day);
                          bool isStanding = false;
                          final currentUser = FirebaseAuth.instance.currentUser;
                          final userEmail = currentUser?.email ?? '';
                          final userUid = currentUser?.uid ?? '';
                          
                          debugPrint("Standing Principal Check: userEmail=$userEmail, userUid=$userUid, delegationsTotal=${snapshot.data!.docs.length}");
                          
                          for (var doc in snapshot.data!.docs) {
                            final data = doc.data() as Map<String, dynamic>;
                            final email = data['teacherEmail'] ?? '';
                            final uid = data['teacherUid'] ?? '';
                            final startStr = data['startDate'] ?? '';
                            final endStr = data['endDate'] ?? '';
                            
                            debugPrint("  - Checking delegation: name=${data['teacherName']}, dbEmail=$email, dbUid=$uid, start=$startStr, end=$endStr");
                            
                            final matchesEmail = (email.isNotEmpty && email.toLowerCase() == userEmail.toLowerCase());
                            final matchesUid = (email.isNotEmpty && email == userUid) || (uid.isNotEmpty && uid == userUid);
                            
                            if (matchesEmail || matchesUid) {
                              final startParts = startStr.split('-');
                              final endParts = endStr.split('-');
                              if (startParts.length == 3 && endParts.length == 3) {
                                final start = DateTime(
                                  int.parse(startParts[0]),
                                  int.parse(startParts[1]),
                                  int.parse(startParts[2]),
                                );
                                final end = DateTime(
                                  int.parse(endParts[0]),
                                  int.parse(endParts[1]),
                                  int.parse(endParts[2]),
                                );
                                if ((today.isAfter(start) || today.isAtSameMomentAs(start)) &&
                                    (today.isBefore(end) || today.isAtSameMomentAs(end))) {
                                  isStanding = true;
                                  debugPrint("    -> ACTIVE DELEGATION MATCH FOUND!");
                                  break;
                                }
                              }
                            }
                          }
                          
                          if (!isStanding) return const SizedBox();
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDF2E9), // Light warm peach/terra
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFD67845), width: 1.5), // Terra border
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD67845).withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.gavel_rounded,
                                      color: Color(0xFFD67845),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Standing Principal Active",
                                          style: TextStyle(
                                            fontFamily: 'Georgia',
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF6E432E), // WC.brown
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          "You have been delegated principal authorities for today. You can now view and manage all student/teacher leave applications.",
                                          style: TextStyle(
                                            color: const Color(0xFF9E7153), // WC.brownLight
                                            fontSize: 12,
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      // ── Quick actions ─────────────────────────
                      WarliSectionTitle(title: "QUICK ACTIONS"),
                      const SizedBox(height: 10),

                      _DashTile(
                        icon: Icons.how_to_reg_rounded,
                        title: "Mark Attendance",
                        subtitle: "Record attendance for your class today",
                        onTap: () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => const MarkAttendancePage())),
                      ),
                      const SizedBox(height: 12),
                      _DashTile(
                        icon: Icons.event_note_rounded,
                        title: "Create Leave Application",
                        subtitle: "Submit a leave request for student or teacher",
                        onTap: () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => const CreateLeavePage())),
                      ),
                      const SizedBox(height: 12),

                      // ── Standing Principal dynamic option ──
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('standing_principals')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox();
                          
                          final now = DateTime.now();
                          final today = DateTime(now.year, now.month, now.day);
                          bool isStanding = false;
                          final currentUser = FirebaseAuth.instance.currentUser;
                          final userEmail = currentUser?.email ?? '';
                          final userUid = currentUser?.uid ?? '';
                          
                          for (var doc in snapshot.data!.docs) {
                            final data = doc.data() as Map<String, dynamic>;
                            final email = data['teacherEmail'] ?? '';
                            final uid = data['teacherUid'] ?? '';
                            final startStr = data['startDate'] ?? '';
                            final endStr = data['endDate'] ?? '';
                            
                            final matchesEmail = (email.isNotEmpty && email.toLowerCase() == userEmail.toLowerCase());
                            final matchesUid = (email.isNotEmpty && email == userUid) || (uid.isNotEmpty && uid == userUid);
                            
                            if (matchesEmail || matchesUid) {
                              final startParts = startStr.split('-');
                              final endParts = endStr.split('-');
                              if (startParts.length == 3 && endParts.length == 3) {
                                final start = DateTime(
                                  int.parse(startParts[0]),
                                  int.parse(startParts[1]),
                                  int.parse(startParts[2]),
                                );
                                final end = DateTime(
                                  int.parse(endParts[0]),
                                  int.parse(endParts[1]),
                                  int.parse(endParts[2]),
                                );
                                if ((today.isAfter(start) || today.isAtSameMomentAs(start)) &&
                                    (today.isBefore(end) || today.isAtSameMomentAs(end))) {
                                  isStanding = true;
                                  break;
                                }
                              }
                            }
                          }
                          
                          if (!isStanding) return const SizedBox();
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _DashTile(
                              icon: Icons.assignment_ind_rounded,
                              title: "Manage Leaves (Standing Principal)",
                              subtitle: "Approve or reject leave requests as delegated principal",
                              onTap: () => Navigator.push(
                                  context, MaterialPageRoute(builder: (_) => const ApproveLeavePage())),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // ── Leave History ─────────────────────────
                      WarliSectionTitle(title: "LEAVE HISTORY (LAST 30 DAYS)"),
                      const SizedBox(height: 10),
                      _buildLeaveHistory(),

                      const SizedBox(height: 28),
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

  Widget _buildLeaveHistory() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('leave_requests').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
        }

        final email = user.email;
        final oneMonthAgo = DateTime.now().subtract(const Duration(days: 30));

        final leaves = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          
          // Filter by time: last 30 days
          final timestamp = data['timestamp'];
          DateTime? dt;
          if (timestamp is Timestamp) {
            dt = timestamp.toDate();
          } else if (timestamp is String) {
            dt = DateTime.tryParse(timestamp);
          }
          if (dt == null) return false;
          if (dt.isBefore(oneMonthAgo)) return false;

          // Filter by relation: teacher email OR classId matches
          final isMyTeacherLeave = data['type'] == 'teacher' && data['teacherEmail'] == email;
          final isMyStudentLeave = data['type'] == 'student' && _classId != null && data['classId'] == _classId;

          return isMyTeacherLeave || isMyStudentLeave;
        }).toList();

        // Sort by timestamp descending
        leaves.sort((a, b) {
          final aTime = (a.data() as Map<String, dynamic>)['timestamp'];
          final bTime = (b.data() as Map<String, dynamic>)['timestamp'];
          DateTime? aDt = aTime is Timestamp ? aTime.toDate() : (aTime is String ? DateTime.tryParse(aTime) : null);
          DateTime? bDt = bTime is Timestamp ? bTime.toDate() : (bTime is String ? DateTime.tryParse(bTime) : null);
          if (aDt == null) return 1;
          if (bDt == null) return -1;
          return bDt.compareTo(aDt);
        });

        if (leaves.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: AppTheme.cardBg.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primary.withOpacity(0.1)),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.event_busy_rounded, color: AppTheme.primary.withOpacity(0.3), size: 36),
                  const SizedBox(height: 8),
                  Text("No leave history for the past 30 days",
                      style: TextStyle(color: AppTheme.textDark.withOpacity(0.5), fontSize: 13)),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: leaves.length,
          itemBuilder: (context, index) {
            final data = leaves[index].data() as Map<String, dynamic>;
            final type = data['type'] ?? 'student';
            final status = data['status'] ?? 'pending';
            final reason = data['reason'] ?? '';
            final fromDate = data['fromDate'] ?? '';
            final toDate = data['toDate'] ?? '';
            final name = type == 'student' ? (data['studentName'] ?? 'Student') : (data['teacherName'] ?? 'Teacher');

            Color statusColor = Colors.orange;
            if (status == 'approved') statusColor = Colors.green;
            if (status == 'rejected') statusColor = Colors.red;

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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      type == 'student' ? Icons.face_rounded : Icons.person_rounded,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark)),
                        const SizedBox(height: 2),
                        Text(
                          "Reason: $reason",
                          style: TextStyle(color: AppTheme.textDark.withOpacity(0.6), fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "$fromDate to $toDate",
                          style: TextStyle(color: AppTheme.textDark.withOpacity(0.4), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  Full-width action tile (local to teacher)
// ─────────────────────────────────────────────
class _DashTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _DashTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.cardBg.withOpacity(0.75),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppTheme.primary.withOpacity(0.18)),
        ),
        child: Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: AppTheme.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textDark)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: AppTheme.textDark.withOpacity(0.5), fontSize: 12)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: AppTheme.primary.withOpacity(0.4), size: 20),
        ]),
      ),
    );
  }
}