// ══════════════════════════════════════════════════════
// create_user_page.dart
// ══════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:attendance_system/services/mongodb_service.dart';
import '../../services/auth_service.dart';
import 'admin_dashboard.dart';

class CreateUserPage extends StatefulWidget {
  const CreateUserPage({super.key});
  @override
  State<CreateUserPage> createState() => _CreateUserPageState();
}

class _CreateUserPageState extends State<CreateUserPage> {
  final nameController     = TextEditingController();
  final emailController    = TextEditingController();
  final passwordController = TextEditingController();
  final phoneController    = TextEditingController();

  String role = 'teacher';
  String? selectedClassId;
  bool _obscure = true, _loading = false;
  final AuthService _authService = AuthService();

  final _roles = {
    'teacher':   {'icon': Icons.person_rounded,   'label': 'Teacher'},
    'principal': {'icon': Icons.school_rounded,   'label': 'Principal'},
    'watchman':  {'icon': Icons.security_rounded, 'label': 'Watchman'},
  };

  Future<void> _createUser() async {
    final name     = nameController.text.trim();
    final email    = emailController.text.trim();
    final password = passwordController.text.trim();
    final phone    = phoneController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields")),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      // Step 1: Create Firebase Auth user + base Firestore doc via AuthService
      // adminCreateUser only takes name, email, password, role — no phone/classId
      await _authService.adminCreateUser(
        name: name,
        email: email,
        password: password,
        role: role,
      );

      // Step 2: Patch the Firestore doc with phone (and optional classId)
      // by looking up the doc that was just created
      final usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (usersSnap.docs.isNotEmpty) {
        final extraData = <String, dynamic>{'phone': phone};
        if (role == 'teacher' &&
            selectedClassId != null &&
            selectedClassId!.isNotEmpty) {
          extraData['classId'] = selectedClassId;
        }
        await usersSnap.docs.first.reference.update(extraData);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User created successfully")));
      nameController.clear();
      emailController.clear();
      passwordController.clear();
      phoneController.clear();
      setState(() { selectedClassId = null; });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.bgDecoration,
        child: SafeArea(
          child: Column(
            children: [
              WarliAppBar(title: "Create User"),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      WarliBanner(
                        icon: Icons.person_add_rounded,
                        title: "New Account",
                        subtitle: "Add teacher, principal or watchman",
                      ),
                      const SizedBox(height: 24),

                      WarliSectionTitle(title: "ACCOUNT DETAILS"),
                      const SizedBox(height: 10),

                      WarliField(
                        controller: nameController,
                        label: "Full Name",
                        icon: Icons.person_rounded,
                        required: true,
                      ),
                      const SizedBox(height: 10),

                      WarliField(
                        controller: phoneController,
                        label: "Phone Number",
                        icon: Icons.phone_rounded,
                        keyboard: TextInputType.phone,
                        required: true,
                      ),
                      const SizedBox(height: 10),

                      WarliField(
                        controller: emailController,
                        label: "Email",
                        icon: Icons.email_rounded,
                        keyboard: TextInputType.emailAddress,
                        required: true,
                      ),
                      const SizedBox(height: 10),

                      WarliField(
                        controller: passwordController,
                        label: "Password",
                        icon: Icons.lock_rounded,
                        obscure: _obscure,
                        required: true,
                        suffix: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: AppTheme.primary.withValues(alpha: 0.45),
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),

                      const SizedBox(height: 22),

                      WarliSectionTitle(title: "ASSIGN ROLE"),
                      const SizedBox(height: 10),

                      Row(
                        children: _roles.entries.map((entry) {
                          final isSelected = role == entry.key;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                role = entry.key;
                                selectedClassId = null;
                              }),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding:
                                const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.primary.withValues(alpha: 0.78)
                                      : AppTheme.cardBg.withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppTheme.primary.withValues(
                                        alpha: isSelected ? 0.0 : 0.2),
                                  ),
                                ),
                                child: Column(children: [
                                  Icon(
                                    entry.value['icon'] as IconData,
                                    color: isSelected
                                        ? AppTheme.textDark
                                        : AppTheme.primary
                                        .withValues(alpha: 0.5),
                                    size: 22,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    entry.value['label'] as String,
                                    style: TextStyle(
                                      color: isSelected
                                          ? AppTheme.textDark
                                          : AppTheme.textDark
                                          .withValues(alpha: 0.6),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ]),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      // Class assignment — only for Teacher role, optional
                      if (role == 'teacher') ...[
                        const SizedBox(height: 22),
                        WarliSectionTitle(title: "CLASS ASSIGNMENT (OPTIONAL)"),
                        const SizedBox(height: 4),
                        Text(
                          "You can assign a class now or do it later from Records.",
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textDark.withValues(alpha: 0.45)),
                        ),
                        const SizedBox(height: 10),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('classes')
                              .snapshots(),
                          builder: (_, snap) {
                            if (!snap.hasData) return const SizedBox();
                            return WarliDropdown(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedClassId,
                                  isExpanded: true,
                                  dropdownColor: AppTheme.cardBg,
                                  hint: Row(children: [
                                    Icon(Icons.class_rounded,
                                        color: AppTheme.primary
                                            .withValues(alpha: 0.55),
                                        size: 20),
                                    const SizedBox(width: 12),
                                    Text(
                                      "Select Class (optional)",
                                      style: TextStyle(
                                          color: AppTheme.textDark
                                              .withValues(alpha: 0.5),
                                          fontSize: 13),
                                    ),
                                  ]),
                                  items: [
                                    DropdownMenuItem<String>(
                                      value: null,
                                      child: Text("No Class",
                                          style: TextStyle(
                                              color: AppTheme.textDark
                                                  .withValues(alpha: 0.5))),
                                    ),
                                    ...snap.data!.docs.map((e) =>
                                        DropdownMenuItem<String>(
                                          value: e.id,
                                          child: Text(e.id,
                                              style: TextStyle(
                                                  color: AppTheme.textDark)),
                                        )),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => selectedClassId = v),
                                ),
                              ),
                            );
                          },
                        ),
                      ],

                      const SizedBox(height: 30),
                      WarliButton(
                        label: "Create User",
                        loading: _loading,
                        onPressed: _createUser,
                      ),
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