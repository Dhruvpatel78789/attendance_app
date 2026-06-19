// ══════════════════════════════════════════════════════
// reset_password_page.dart
// ══════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:attendance_system/services/mongodb_service.dart';
import 'admin_dashboard.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});
  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  // ── Search mode ──────────────────────────────────────────────────────────────
  String _searchMode = 'name'; // 'name' | 'phone'

  // ── Controllers ──────────────────────────────────────────────────────────────
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController(); // ← auto-filled on selection

  // ── State ────────────────────────────────────────────────────────────────────
  bool _searching = false;
  bool _loading   = false;

  Map<String, dynamic>? _selectedUser; // set when user picks from list
  List<QueryDocumentSnapshot> _suggestions = [];
  bool _showSuggestions = false;

  // ── Debounce ─────────────────────────────────────────────────────────────────
  DateTime _lastSearch = DateTime.now();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  // ── Live search ──────────────────────────────────────────────────────────────
  // Firestore range queries are case-sensitive, so instead we fetch all users
  // and filter client-side with a case-insensitive contains check.
  // For a school-sized dataset (< 500 records) this is fast and reliable.
  Future<void> _onSearchChanged(String value) async {
    final query = value.trim().toLowerCase(); // ← normalise to lowercase

    setState(() {
      _selectedUser    = null;
      _showSuggestions = false;
      _suggestions     = [];
      // Clear the auto-filled fields whenever the user edits the search field
      if (_searchMode == 'name') {
        _phoneCtrl.clear();
      } else {
        _nameCtrl.clear();
      }
      _emailCtrl.clear();
    });

    // Show suggestions after just 1 character
    if (query.isEmpty) return;

    // Debounce — wait 300 ms after last keystroke
    final now = DateTime.now();
    _lastSearch = now;
    await Future.delayed(const Duration(milliseconds: 300));
    if (_lastSearch != now) return;

    if (mounted) setState(() => _searching = true);
    try {
      final field = _searchMode; // 'name' or 'phone'

      // Staff only (teacher / principal / watchman) — students excluded
      final usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', whereIn: ['teacher', 'principal', 'watchman'])
          .limit(300)
          .get();

      final List<QueryDocumentSnapshot> results = usersSnap.docs.where((doc) {
        final data       = doc.data() as Map<String, dynamic>;
        final fieldValue = (data[field] as String? ?? '').toLowerCase();
        return fieldValue.contains(query);
      }).take(8).toList();

      if (!mounted) return;
      setState(() {
        _suggestions     = results;
        _showSuggestions = results.isNotEmpty;
      });
    } catch (_) {}
    if (mounted) setState(() => _searching = false);
  }

  // ── User selected from list ───────────────────────────────────────────────────
  void _selectUser(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    setState(() {
      _selectedUser    = data;
      _showSuggestions = false;
      _suggestions     = [];

      // Fill all three fields regardless of which mode was used to search
      _nameCtrl.text  = data['name']  as String? ?? '';
      _phoneCtrl.text = data['phone'] as String? ?? '';
      _emailCtrl.text = data['email'] as String? ?? ''; // ← auto-fetch email
    });
  }

  // ── Admin re-auth dialog ──────────────────────────────────────────────────────
  Future<String?> _askAdminPassword() async {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text("Admin Verification",
            style: TextStyle(
                color: AppTheme.textDark,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        content: TextField(
          controller: c,
          obscureText: true,
          style: TextStyle(color: AppTheme.textDark),
          decoration: InputDecoration(
            labelText: "Your Admin Password",
            labelStyle:
            TextStyle(color: AppTheme.textDark.withValues(alpha: 0.5)),
            prefixIcon: Icon(Icons.lock_rounded,
                color: AppTheme.primary.withValues(alpha: 0.55)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, c.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.textDark,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Verify"),
          ),
        ],
      ),
    );
  }

  // ── Send reset email ──────────────────────────────────────────────────────────
  Future<void> _sendReset() async {
    if (_selectedUser == null) {
      _snack("Please search and select a user first");
      return;
    }

    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _snack("No email address found for this user");
      return;
    }

    setState(() => _loading = true);
    try {
      final adminPassword = await _askAdminPassword();
      if (adminPassword == null || adminPassword.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      final adminUser = FirebaseAuth.instance.currentUser;
      if (adminUser == null || adminUser.email == null) {
        throw Exception("Admin not logged in");
      }

      await adminUser.reauthenticateWithCredential(
        EmailAuthProvider.credential(
            email: adminUser.email!, password: adminPassword),
      );

      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      _snack("Reset link sent to $email ✓");

      // Clear everything after success
      _nameCtrl.clear();
      _phoneCtrl.clear();
      _emailCtrl.clear();
      setState(() {
        _selectedUser    = null;
        _suggestions     = [];
        _showSuggestions = false;
      });
    } on FirebaseAuthException catch (e) {
      _snack(e.code == 'wrong-password'
          ? "Wrong admin password"
          : (e.message ?? "Authentication error"));
    } catch (e) {
      _snack("Error: $e");
    }
    if (mounted) setState(() => _loading = false);
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  void _switchMode(String mode) {
    if (_searchMode == mode) return;
    setState(() {
      _searchMode      = mode;
      _selectedUser    = null;
      _suggestions     = [];
      _showSuggestions = false;
      _nameCtrl.clear();
      _phoneCtrl.clear();
      _emailCtrl.clear();
    });
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.bgDecoration,
        child: SafeArea(
          child: Column(
            children: [
              const WarliAppBar(title: "Reset Password"),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showSuggestions = false),
                  behavior: HitTestBehavior.translucent,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Banner ─────────────────────────────────────────────
                        const WarliBanner(
                          icon:     Icons.lock_reset_rounded,
                          title:    "Password Reset",
                          subtitle: "Search a user and send them a reset link",
                        ),
                        const SizedBox(height: 24),

                        // ── Mode toggle ────────────────────────────────────────
                        const WarliSectionTitle(title: "SEARCH BY"),
                        const SizedBox(height: 10),
                        Row(children: [
                          _ModeChip(
                            label:    "Name",
                            icon:     Icons.person_search_rounded,
                            selected: _searchMode == 'name',
                            onTap:    () => _switchMode('name'),
                          ),
                          const SizedBox(width: 10),
                          _ModeChip(
                            label:    "Phone Number",
                            icon:     Icons.phone_rounded,
                            selected: _searchMode == 'phone',
                            onTap:    () => _switchMode('phone'),
                          ),
                        ]),
                        const SizedBox(height: 20),

                        // ── Name field ─────────────────────────────────────────
                        const WarliSectionTitle(title: "FULL NAME"),
                        const SizedBox(height: 8),
                        _SearchField(
                          controller: _nameCtrl,
                          label:      "Search by name…",
                          icon:       Icons.person_rounded,
                          keyboard:   TextInputType.name,
                          readOnly:   _searchMode != 'name',
                          isSelected: _selectedUser != null,
                          onChanged:  _searchMode == 'name'
                              ? _onSearchChanged
                              : null,
                        ),

                        // ── Name suggestions ───────────────────────────────────
                        if (_searchMode == 'name' && _showSuggestions) ...[
                          const SizedBox(height: 6),
                          _SuggestionsList(
                            suggestions: _suggestions,
                            onSelect:    _selectUser,
                          ),
                        ],

                        const SizedBox(height: 14),

                        // ── Phone field ────────────────────────────────────────
                        const WarliSectionTitle(title: "PHONE NUMBER"),
                        const SizedBox(height: 8),
                        _SearchField(
                          controller: _phoneCtrl,
                          label:      "Search by phone…",
                          icon:       Icons.phone_rounded,
                          keyboard:   TextInputType.phone,
                          readOnly:   _searchMode != 'phone',
                          isSelected: _selectedUser != null,
                          onChanged:  _searchMode == 'phone'
                              ? _onSearchChanged
                              : null,
                        ),

                        // ── Phone suggestions ──────────────────────────────────
                        if (_searchMode == 'phone' && _showSuggestions) ...[
                          const SizedBox(height: 6),
                          _SuggestionsList(
                            suggestions: _suggestions,
                            onSelect:    _selectUser,
                          ),
                        ],

                        const SizedBox(height: 14),

                        // ── Email field (auto-filled, always read-only) ─────────
                        const WarliSectionTitle(title: "EMAIL ADDRESS"),
                        const SizedBox(height: 8),
                        _EmailField(
                          controller: _emailCtrl,
                          hasUser:    _selectedUser != null,
                        ),

                        // ── Searching spinner ──────────────────────────────────
                        if (_searching)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(children: [
                              SizedBox(
                                width: 14, height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.primary.withValues(alpha: 0.6)),
                              ),
                              const SizedBox(width: 10),
                              Text("Searching…",
                                  style: TextStyle(
                                      color: AppTheme.textDark.withValues(alpha: 0.5),
                                      fontSize: 12)),
                            ]),
                          ),

                        const SizedBox(height: 20),

                        // ── Info note ──────────────────────────────────────────
                        Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                                color: AppTheme.primary.withValues(alpha: 0.18)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.admin_panel_settings_rounded,
                                  color: AppTheme.primary.withValues(alpha: 0.6),
                                  size: 17),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  "Admin will be asked to verify their password before the reset link is sent.",
                                  style: TextStyle(
                                      color: AppTheme.textDark.withValues(alpha: 0.65),
                                      fontSize: 12,
                                      height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),
                        WarliButton(
                          label:     "Send Reset Link",
                          loading:   _loading,
                          onPressed: _sendReset,
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
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

// ══════════════════════════════════════════════════════
//  WIDGETS
// ══════════════════════════════════════════════════════

// ─────────────────────────────────────────────
//  Mode chip toggle
// ─────────────────────────────────────────────
class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ModeChip(
      {required this.label,
        required this.icon,
        required this.selected,
        required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.78)
                : AppTheme.cardBg.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
                color: AppTheme.primary.withValues(alpha: selected ? 0.0 : 0.2)),
          ),
          child: Column(children: [
            Icon(icon,
                color: selected
                    ? AppTheme.textDark
                    : AppTheme.primary.withValues(alpha: 0.5),
                size: 20),
            const SizedBox(height: 5),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected
                      ? AppTheme.textDark
                      : AppTheme.textDark.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                )),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Search input field (name / phone)
// ─────────────────────────────────────────────
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType keyboard;
  final bool readOnly;
  final bool isSelected;     // true after a user has been picked
  final ValueChanged<String>? onChanged;

  const _SearchField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.keyboard,
    required this.readOnly,
    required this.isSelected,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Three visual states:
    //  • readOnly (inactive mode)  — very dim
    //  • active + user selected    — confirm tint with check
    //  • active + typing           — normal editable
    final bool confirmed = !readOnly && isSelected;

    return Container(
      decoration: BoxDecoration(
        color: readOnly
            ? AppTheme.cardBg.withValues(alpha: 0.40)
            : confirmed
            ? AppTheme.primary.withValues(alpha: 0.12)
            : AppTheme.cardBg.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: confirmed
              ? AppTheme.primary.withValues(alpha: 0.45)
              : AppTheme.primary.withValues(alpha: readOnly ? 0.1 : 0.2),
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        readOnly: readOnly,
        onChanged: onChanged,
        style: TextStyle(
            color: AppTheme.textDark.withValues(alpha: readOnly ? 0.3 : 1.0),
            fontSize: 14),
        decoration: InputDecoration(
          hintText: label,
          prefixIcon: Icon(icon,
              color: AppTheme.primary
                  .withValues(alpha: readOnly ? 0.2 : confirmed ? 0.8 : 0.55),
              size: 20),
          // Show a check when this field was auto-filled from selection,
          // or a search icon while the field is active & editable
          suffixIcon: confirmed
              ? Icon(Icons.check_circle_rounded,
              color: AppTheme.primary.withValues(alpha: 0.7), size: 18)
              : readOnly
              ? null
              : Icon(Icons.search_rounded,
              color: AppTheme.primary.withValues(alpha: 0.35), size: 18),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.transparent,
          hintStyle: TextStyle(
              color: AppTheme.textDark.withValues(alpha: 0.3), fontSize: 13),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Email field — always read-only, auto-filled
// ─────────────────────────────────────────────
class _EmailField extends StatelessWidget {
  final TextEditingController controller;
  final bool hasUser; // true once a user has been selected

  const _EmailField({required this.controller, required this.hasUser});

  @override
  Widget build(BuildContext context) {
    final bool hasEmail = controller.text.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: hasEmail
            ? AppTheme.primary.withValues(alpha: 0.10)
            : AppTheme.cardBg.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasEmail
              ? AppTheme.primary.withValues(alpha: 0.40)
              : AppTheme.primary.withValues(alpha: 0.12),
        ),
      ),
      child: TextField(
        controller: controller,
        readOnly: true,
        style: TextStyle(
            color: AppTheme.textDark.withValues(alpha: hasEmail ? 1.0 : 0.35),
            fontSize: 14),
        decoration: InputDecoration(
          hintText: hasUser && !hasEmail
              ? "No email on record for this user"
              : "Auto-filled from selected user",
          prefixIcon: Icon(Icons.email_rounded,
              color: AppTheme.primary
                  .withValues(alpha: hasEmail ? 0.7 : 0.25),
              size: 20),
          suffixIcon: hasEmail
              ? Icon(Icons.lock_rounded,
              color: AppTheme.primary.withValues(alpha: 0.35), size: 16)
              : null,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.transparent,
          hintStyle: TextStyle(
              color: hasUser && !hasEmail
                  ? Colors.red.withValues(alpha: 0.5)
                  : AppTheme.textDark.withValues(alpha: 0.3),
              fontSize: 13,
              fontStyle: FontStyle.italic),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Suggestions list — same card style as View Records
// ─────────────────────────────────────────────
class _SuggestionsList extends StatelessWidget {
  final List<QueryDocumentSnapshot> suggestions;
  final ValueChanged<QueryDocumentSnapshot> onSelect;
  const _SuggestionsList(
      {required this.suggestions, required this.onSelect});

  /// Two-letter initials, safe against empty / multi-space names.
  String _initials(String name) {
    final parts = name.trim().split(' ').where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: suggestions.asMap().entries.map((entry) {
          final i    = entry.key;
          final doc  = entry.value;
          final data = doc.data() as Map<String, dynamic>;

          final name    = (data['name']    as String? ?? '').trim();
          final phone   = (data['phone']   as String? ?? '').trim();
          final email   = (data['email']   as String? ?? '').trim();
          final role    = (data['role']    as String? ?? '').trim();
          final classId = (data['classId'] as String? ?? '').trim();
          final grNum   = data['grNumber']?.toString().trim() ?? '';

          return Column(children: [
            if (i > 0)
              Divider(height: 1, color: AppTheme.primary.withValues(alpha: 0.1)),
            InkWell(
              onTap: () => onSelect(doc),
              borderRadius: BorderRadius.only(
                topLeft:     Radius.circular(i == 0 ? 13 : 0),
                topRight:    Radius.circular(i == 0 ? 13 : 0),
                bottomLeft:  Radius.circular(i == suggestions.length - 1 ? 13 : 0),
                bottomRight: Radius.circular(i == suggestions.length - 1 ? 13 : 0),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Avatar ────────────────────────────────────
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                      child: Text(_initials(name),
                          style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ),
                    const SizedBox(width: 12),

                    // ── Name + detail chips ───────────────────────
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name
                          Text(name.isEmpty ? 'No Name' : name,
                              style: TextStyle(
                                  color: AppTheme.textDark,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                          if (grNum.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text("GR: $grNum",
                                  style: TextStyle(
                                      color: AppTheme.textDark.withValues(alpha: 0.45),
                                      fontSize: 11)),
                            ),
                          const SizedBox(height: 6),
                          // Detail chips row
                          Wrap(spacing: 5, runSpacing: 4, children: [
                            if (classId.isNotEmpty)
                              _Tag(label: "Class: $classId"),
                            if (phone.isNotEmpty)
                              _Tag(label: "Phone: $phone"),
                            if (email.isNotEmpty)
                              _Tag(label: email, isEmail: true),
                          ]),
                        ],
                      ),
                    ),

                    // ── Role badge ────────────────────────────────
                    if (role.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(role.toUpperCase(),
                            style: TextStyle(
                                color: AppTheme.primary,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5)),
                      ),
                  ],
                ),
              ),
            ),
          ]);
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Small inline chip used in suggestions rows
// ─────────────────────────────────────────────
class _Tag extends StatelessWidget {
  final String label;
  final bool isEmail;
  const _Tag({required this.label, this.isEmail = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isEmail
            ? AppTheme.primary.withValues(alpha: 0.15)
            : AppTheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: AppTheme.primary.withValues(alpha: isEmail ? 0.3 : 0.12)),
      ),
      child: Text(label,
          style: TextStyle(
              color: AppTheme.textDark.withValues(alpha: 0.7),
              fontSize: 10,
              fontWeight: isEmail ? FontWeight.w600 : FontWeight.normal)),
    );
  }
}