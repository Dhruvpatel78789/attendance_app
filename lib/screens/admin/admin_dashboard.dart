import 'package:flutter/material.dart';
import 'package:attendance_system/services/mongodb_service.dart';
import 'create_user_page.dart';
import '/services/auth_service.dart';
import '/login_page.dart';
import 'add_class_page.dart';
import 'add_student_page.dart';
import 'reset_password_page.dart';
import 'view_records_page.dart';
import 'import_students_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  SHARED DESIGN SYSTEM
// ═══════════════════════════════════════════════════════════════
class AppTheme {
  static const Color primary   = Color(0xFFB58463);
  static const Color secondary = Color(0xFFEADBCE);
  static const Color bg        = Color(0xFFF2E9DF);
  static const Color cardBg    = Color(0xFFFAEDE3);
  static const Color textDark  = Color(0xFF2C1C14);

  static BoxDecoration get bgDecoration => const BoxDecoration(
    image: DecorationImage(
      image: AssetImage('assets/images/background.png'),
      fit: BoxFit.cover,
    ),
  );
}

// ═══════════════════════════════════════════════════════════════
//  ADMIN DASHBOARD
// ═══════════════════════════════════════════════════════════════
class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  String get _todayDate {
    final n = DateTime.now();
    return "${n.day.toString().padLeft(2, '0')} / ${n.month.toString().padLeft(2, '0')} / ${n.year}";
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
              // ── AppBar ──────────────────────────────────────────
              WarliAppBar(
                title: "Admin Dashboard",
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
                      // ── Welcome card ───────────────────────────
                      _WelcomeCard(date: _todayDate),
                      const SizedBox(height: 20),

                      // ── Live stats (real-time, clickable) ──────
                      _LiveStatsRow(),
                      const SizedBox(height: 26),

                      // ── User management ────────────────────────
                      WarliSectionTitle(title: "USER MANAGEMENT"),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: _ActionCard(
                          icon: Icons.person_add_rounded,
                          title: "Create User",
                          subtitle: "Add teacher or staff",
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateUserPage())),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _ActionCard(
                          icon: Icons.lock_reset_rounded,
                          title: "Reset Password",
                          subtitle: "Send reset email",
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResetPasswordPage())),
                        )),
                      ]),
                      const SizedBox(height: 22),

                      // ── Student management ─────────────────────
                      WarliSectionTitle(title: "STUDENT MANAGEMENT"),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: _ActionCard(
                          icon: Icons.class_rounded,
                          title: "Add / Edit\nClass",
                          subtitle: "Manage class records",
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddClassPage())),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _ActionCard(
                          icon: Icons.person_add_alt_1_rounded,
                          title: "Add Student",
                          subtitle: "Register manually",
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddStudentPage())),
                        )),
                      ]),
                      const SizedBox(height: 12),
                      _ActionTile(
                        icon: Icons.upload_file_rounded,
                        title: "Upload via CSV",
                        subtitle: "Bulk import students from file",
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ImportStudentsScreen())),
                      ),
                      const SizedBox(height: 22),

                      // ── Records ────────────────────────────────
                      WarliSectionTitle(title: "RECORDS & DATA"),
                      const SizedBox(height: 10),
                      _ActionTile(
                        icon: Icons.manage_search_rounded,
                        title: "View Records",
                        subtitle: "Browse students, teachers, classes",
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ViewRecordsPage())),
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
//  Welcome Card
// ─────────────────────────────────────────────
class _WelcomeCard extends StatelessWidget {
  final String date;
  const _WelcomeCard({required this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Welcome Back 👋", style: TextStyle(color: AppTheme.textDark.withValues(alpha: 0.7), fontSize: 13)),
              const SizedBox(height: 4),
              const Text("Administrator", style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 20)),
              const SizedBox(height: 8),
              Text(date, style: TextStyle(color: AppTheme.textDark.withValues(alpha: 0.6), fontSize: 12)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppTheme.textDark.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.admin_panel_settings_rounded, color: AppTheme.textDark, size: 28),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
//  Live Stats Row — separate StreamBuilders for real-time updates
// ─────────────────────────────────────────────
class _LiveStatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      // Students — live count, navigates to Students list
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('students').snapshots(),
          builder: (_, snap) => _StatCard(
            icon: Icons.people_rounded,
            label: "Students",
            value: snap.hasData ? "${snap.data!.docs.length}" : "…",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const StaffStudentListPage(listType: 'students'),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),

      // Classes — live count, navigates to Classes list
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('classes').snapshots(),
          builder: (_, snap) => _StatCard(
            icon: Icons.school_rounded,
            label: "Classes",
            value: snap.hasData ? "${snap.data!.docs.length}" : "…",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ViewRecordsPage(initialMainType: 'classes'),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),

      // Staff — live count (users collection), navigates to Staff list
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (_, snap) => _StatCard(
            icon: Icons.badge_rounded,
            label: "Staff",
            value: snap.hasData ? "${snap.data!.docs.length}" : "…",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const StaffStudentListPage(listType: 'staff'),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────
//  Stat Card  (tappable)
// ─────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final VoidCallback? onTap;
  const _StatCard({required this.icon, required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.cardBg.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.18)),
        ),
        child: Column(children: [
          Icon(icon, color: AppTheme.primary.withValues(alpha: 0.7), size: 22),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 20)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: AppTheme.textDark.withValues(alpha: 0.5), fontSize: 11)),
          const SizedBox(height: 4),
          Icon(Icons.arrow_forward_ios_rounded, size: 9, color: AppTheme.primary.withValues(alpha: 0.35)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Action Card  (2-column)
// ─────────────────────────────────────────────
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.textDark.withValues(alpha: 0.9), size: 26),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 13, height: 1.3)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: AppTheme.textDark.withValues(alpha: 0.65), fontSize: 11, height: 1.3)),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppTheme.textDark.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text("Open", style: TextStyle(color: AppTheme.textDark, fontSize: 10)),
                  SizedBox(width: 3),
                  Icon(Icons.arrow_forward_rounded, size: 10, color: AppTheme.textDark),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Action Tile  (full-width)
// ─────────────────────────────────────────────
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.cardBg.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.18)),
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textDark)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: AppTheme.textDark.withValues(alpha: 0.5), fontSize: 12)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppTheme.primary.withValues(alpha: 0.4), size: 20),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  STAFF & STUDENT LIST PAGE
//  listType: 'staff' → shows teacher/principal/watchman from 'users'
//  listType: 'students' → shows all from 'students'
// ═══════════════════════════════════════════════════════════════
class StaffStudentListPage extends StatefulWidget {
  final String listType; // 'staff' | 'students'
  const StaffStudentListPage({super.key, required this.listType});

  @override
  State<StaffStudentListPage> createState() => _StaffStudentListPageState();
}

class _StaffStudentListPageState extends State<StaffStudentListPage> {
  bool get _isStaff => widget.listType == 'staff';

  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stream = _isStaff
        ? FirebaseFirestore.instance
        .collection('users')
        .where('role', whereIn: ['teacher', 'principal', 'watchman'])
        .snapshots()
        : FirebaseFirestore.instance.collection('students').snapshots();

    return Scaffold(
      body: Container(
        decoration: AppTheme.bgDecoration,
        child: SafeArea(
          child: Column(
            children: [
              WarliAppBar(title: _isStaff ? "Staff Members" : "Students"),

              // ── Search bar ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: Colors.black87, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search by name…',
                      hintStyle: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: Color(0xFF666666), size: 20),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Color(0xFF666666),
                            size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                    ),
                  ),
                ),
              ),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: stream,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: AppTheme.primary));
                    }
                    if (!snap.hasData || snap.data!.docs.isEmpty) {
                      return Center(
                        child: Text(
                          _isStaff ? "No staff found" : "No students found",
                          style: TextStyle(
                              color: AppTheme.textDark.withValues(alpha: 0.5),
                              fontSize: 14),
                        ),
                      );
                    }

                    // ── Case-insensitive name filter ──────────────────────
                    final docs = snap.data!.docs.where((doc) {
                      if (_query.isEmpty) return true;
                      final name = ((doc.data() as Map<String, dynamic>)['name']
                          ?.toString() ??
                          '')
                          .toLowerCase();
                      return name.contains(_query);
                    }).toList();

                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded,
                                size: 52,
                                color: AppTheme.primary.withValues(alpha: 0.2)),
                            const SizedBox(height: 10),
                            Text(
                              'No results for "$_query"',
                              style: TextStyle(
                                  color:
                                  AppTheme.textDark.withValues(alpha: 0.45),
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      itemBuilder: (_, i) {
                        final doc  = docs[i];
                        final data = doc.data() as Map<String, dynamic>;
                        return _PersonCard(
                          docId: doc.id,
                          data: data,
                          isStaff: _isStaff,
                          collection: _isStaff ? 'users' : 'students',
                        );
                      },
                    );
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
//  Person Card with Edit / Delete / Assign Class
// ─────────────────────────────────────────────
class _PersonCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final bool isStaff;
  final String collection;

  const _PersonCard({
    required this.docId,
    required this.data,
    required this.isStaff,
    required this.collection,
  });

  String get _initials {
    final n = (data['name'] ?? '').toString().trim();
    if (n.isEmpty) return '?';
    // Filter out empty strings produced by consecutive spaces in names
    // e.g. "KHARPADIYA  ANISHABEN" → split gives ["KHARPADIYA", "", "ANISHABEN"]
    // Without the filter, parts[1][0] on "" throws RangeError.
    final parts = n.split(' ').where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final name    = data['name']    ?? 'No Name';
    final email   = data['email']   ?? '';
    final phone   = data['phone']   ?? '';
    final role    = data['role']    ?? '';
    final classId = data['classId'] ?? data['class'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──────────────────────────────────────
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                  child: Text(_initials,
                      style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name,
                        style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 14)),
                    if (role.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(role.toUpperCase(),
                            style: TextStyle(color: AppTheme.primary, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                      ),
                  ]),
                ),
                // Action buttons
                _IconBtn(icon: Icons.edit_rounded,  color: AppTheme.primary,           onTap: () => _showEditDialog(context)),
                _IconBtn(icon: Icons.delete_rounded, color: const Color(0xFFB43232),   onTap: () => _confirmDelete(context)),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0x1A6B3010)),
            const SizedBox(height: 10),

            // ── Details ──────────────────────────────────────────
            if (email.isNotEmpty)
              _InfoRow(icon: Icons.email_rounded, text: email),
            if (phone.isNotEmpty)
              _InfoRow(icon: Icons.phone_rounded, text: phone),
            if (classId.toString().isNotEmpty)
              _InfoRow(icon: Icons.class_rounded, text: "Class: $classId"),

            // ── Assign / Change Class (teachers only) ──
            if (isStaff && role == 'teacher') ...[
              const SizedBox(height: 10),
              _AssignClassButton(docId: docId, currentClassId: classId.toString()),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Edit Dialog ──────────────────────────────────────────────────────────
  void _showEditDialog(BuildContext context) {
    final nameCtrl  = TextEditingController(text: data['name']  ?? '');
    final emailCtrl = TextEditingController(text: data['email'] ?? '');
    final phoneCtrl = TextEditingController(text: data['phone'] ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text("Edit Profile",
            style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _DialogField(controller: nameCtrl,  label: "Full Name",     icon: Icons.person_rounded),
            const SizedBox(height: 12),
            _DialogField(controller: phoneCtrl, label: "Phone Number",  icon: Icons.phone_rounded,
                keyboard: TextInputType.phone),
            const SizedBox(height: 12),
            _DialogField(controller: emailCtrl, label: "Email",         icon: Icons.email_rounded,
                keyboard: TextInputType.emailAddress),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection(collection)
                  .doc(docId)
                  .update({
                'name':  nameCtrl.text.trim(),
                'email': emailCtrl.text.trim(),
                'phone': phoneCtrl.text.trim(),
              });
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Profile updated")));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.textDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // ─── Delete Confirmation ──────────────────────────────────────────────────
  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text("Delete User",
            style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(
          "Are you sure you want to delete \"${data['name'] ?? 'this user'}\"? This cannot be undone.",
          style: TextStyle(color: AppTheme.textDark.withValues(alpha: 0.7), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection(collection).doc(docId).delete();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("User deleted")));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB43232),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Assign / Change Class Button
// ─────────────────────────────────────────────
class _AssignClassButton extends StatelessWidget {
  final String docId;
  final String currentClassId;

  const _AssignClassButton({required this.docId, required this.currentClassId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('classes').snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox();
        final classes = snap.data!.docs;

        return GestureDetector(
          onTap: () => _showClassPicker(context, classes),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.class_rounded, color: AppTheme.primary, size: 15),
                const SizedBox(width: 6),
                Text(
                  currentClassId.isNotEmpty ? "Change Class ($currentClassId)" : "Assign Class",
                  style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 4),
                Icon(Icons.edit_rounded, color: AppTheme.primary.withValues(alpha: 0.6), size: 13),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showClassPicker(BuildContext context, List<QueryDocumentSnapshot> classes) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text("Assign Class",
            style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // No class option
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.primary.withValues(alpha: 0.08),
                child: Icon(Icons.not_interested_rounded, color: AppTheme.primary.withValues(alpha: 0.5), size: 18),
              ),
              title: Text("No Class", style: TextStyle(color: AppTheme.textDark.withValues(alpha: 0.6), fontSize: 13)),
              onTap: () async {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(docId)
                    .update({'classId': FieldValue.delete()});
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Class removed")));
                }
              },
            ),
            const Divider(height: 1),
            ...classes.map((c) => ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                child: Icon(Icons.class_rounded, color: AppTheme.primary, size: 18),
              ),
              title: Text(c.id, style: TextStyle(color: AppTheme.textDark, fontSize: 13, fontWeight: FontWeight.w500)),
              trailing: currentClassId == c.id
                  ? Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 18)
                  : null,
              onTap: () async {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(docId)
                    .update({'classId': c.id});
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Class assigned: ${c.id}")));
                }
              },
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Small helpers
// ─────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(children: [
        Icon(icon, size: 14, color: AppTheme.primary.withValues(alpha: 0.55)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(color: AppTheme.textDark.withValues(alpha: 0.7), fontSize: 12),
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}

class _DialogField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType keyboard;

  const _DialogField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboard = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      style: TextStyle(color: AppTheme.textDark, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppTheme.textDark.withValues(alpha: 0.5), fontSize: 13),
        prefixIcon: Icon(icon, color: AppTheme.primary.withValues(alpha: 0.55), size: 18),
        filled: true,
        fillColor: AppTheme.cardBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SHARED REUSABLE WIDGETS  (used by all pages / dashboards)
// ═══════════════════════════════════════════════════════════════

/// Top bar used on every screen.
class WarliAppBar extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const WarliAppBar({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppTheme.primary.withValues(alpha: 0.82),
      child: Row(children: [
        if (Navigator.canPop(context)) ...[
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.textDark, size: 22),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(title, style: const TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 17)),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

/// Labelled text input field.
class WarliField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType keyboard;
  final bool obscure;
  final Widget? suffix;
  final void Function(String)? onChanged;
  final bool required;

  const WarliField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboard = TextInputType.text,
    this.obscure  = false,
    this.suffix,
    this.onChanged,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        obscureText: obscure,
        onChanged: onChanged,
        style: TextStyle(color: AppTheme.textDark, fontSize: 14),
        decoration: InputDecoration(
          labelText: required ? "$label *" : label,
          prefixIcon: Icon(icon, color: AppTheme.primary.withValues(alpha: 0.55), size: 20),
          suffixIcon: suffix,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.transparent,
          labelStyle: TextStyle(color: AppTheme.textDark.withValues(alpha: 0.5), fontSize: 13),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

/// Dropdown wrapper box.
class WarliDropdown extends StatelessWidget {
  final Widget child;
  const WarliDropdown({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.cardBg.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: child,
    );
  }
}

/// Icon + title + subtitle banner strip at top of sub-pages.
class WarliBanner extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const WarliBanner({super.key, required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppTheme.textDark.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AppTheme.textDark, size: 24),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 3),
          Text(subtitle, style: TextStyle(color: AppTheme.textDark.withValues(alpha: 0.65), fontSize: 12)),
        ]),
      ]),
    );
  }
}

/// Full-width primary action button.
class WarliButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  const WarliButton({super.key, required this.label, this.loading = false, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity, height: 50,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: AppTheme.textDark,
          disabledBackgroundColor: AppTheme.primary.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppTheme.textDark, strokeWidth: 2))
            : Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

/// Small all-caps section heading.
class WarliSectionTitle extends StatelessWidget {
  final String title;
  const WarliSectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppTheme.primary.withValues(alpha: 0.6)),
    );
  }
}