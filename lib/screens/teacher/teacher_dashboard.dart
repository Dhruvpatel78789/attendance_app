import 'package:flutter/material.dart';
import 'package:attendance_system/services/mongodb_service.dart';
import 'mark_attendance_page.dart';
import 'create_leave_page.dart';
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
      setState(() {
        _displayName = (name != null && name.isNotEmpty) ? name : (user.displayName ?? 'Teacher');
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

                      const SizedBox(height: 26),

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