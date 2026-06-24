import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:attendance_system/services/mongodb_service.dart';

import 'screens/admin/admin_dashboard.dart';
import 'screens/principal/principal_dashboard.dart';
import 'screens/teacher/teacher_dashboard.dart';
import 'screens/watchman/watchman_dashboard.dart';

// ── WARLI THEME COLOURS ──────────────────────────────────────────────────────
const _parchment      = Color(0xFFF0DFC0);
const _parchmentLight = Color(0xFFFFF8EA);
const _maroon         = Color(0xFF6B1A1A);
const _maroonDark     = Color(0xFF3D1505);
const _maroonLight    = Color(0xFFC4956A);
const _textMuted      = Color(0xFFA07840);

enum _LoginMode { email, phone }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _loginEmailCtrl  = TextEditingController();
  final _loginPhoneCtrl  = TextEditingController();
  final _loginPassCtrl   = TextEditingController();
  final _signupNameCtrl  = TextEditingController();
  final _signupPhoneCtrl = TextEditingController();
  final _signupEmailCtrl = TextEditingController();
  final _signupPassCtrl  = TextEditingController();
  final _signupSchoolNameCtrl = TextEditingController();
  final _signupAdminIdCtrl = TextEditingController();
  final _signupConfirmPassCtrl = TextEditingController();
  final _signupAddressCtrl = TextEditingController();

  _LoginMode _loginMode = _LoginMode.email;
  bool _showSignup      = false;
  bool _obscureLogin    = true;
  bool _obscureSignup   = true;
  bool _loading         = false;
  String _error         = '';

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
        begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    for (final c in [
      _loginEmailCtrl, _loginPhoneCtrl, _loginPassCtrl,
      _signupNameCtrl, _signupPhoneCtrl, _signupEmailCtrl, _signupPassCtrl,
      _signupSchoolNameCtrl, _signupAdminIdCtrl, _signupConfirmPassCtrl, _signupAddressCtrl
    ]) { c.dispose(); }
    super.dispose();
  }

  // ── AUTH ──────────────────────────────────────────────────────────────────

  String _cleanError(dynamic e) {
    final str = e.toString();
    if (str.contains('SocketException') ||
        str.contains('Failed host lookup') ||
        str.contains('ClientException') ||
        str.contains('NetworkImage') ||
        str.contains('HandshakeException')) {
      return 'Unable to connect to the server. Please check your internet connection and try again.';
    }
    if (str.contains('Connection refused') || str.contains('Connection timed out')) {
      return 'Server is currently unreachable. Please try again later.';
    }
    return str;
  }

  Future<void> _loginWithEmail() async {
    setState(() { _loading = true; _error = ''; });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _loginEmailCtrl.text.trim(),
        password: _loginPassCtrl.text.trim(),
      );
      await _navigateByRole();
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Login failed');
    } catch (e) {
      if (mounted) setState(() => _error = _cleanError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Login with phone number: look up email by phone number, then sign in normally.
  Future<void> _loginWithPhone() async {
    final phone    = _loginPhoneCtrl.text.trim();
    final password = _loginPassCtrl.text.trim();
    if (phone.isEmpty || password.isEmpty) {
      setState(() => _error = 'Mobile number and password are required.');
      return;
    }
    setState(() { _loading = true; _error = ''; });
    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();
      if (query.docs.isEmpty) {
        setState(() =>
        _error = 'No account found for this mobile number.');
        return;
      }
      final email = (query.docs.first.data()['email'] as String?) ?? '';
      if (email.isEmpty) {
        setState(() => _error = 'Account setup incomplete. Contact admin.');
        return;
      }
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      await _navigateByRole();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        setState(() => _error = 'Incorrect password. Please try again.');
      } else {
        setState(() => _error = e.message ?? 'Login failed');
      }
    } catch (e) {
      if (mounted) setState(() => _error = _cleanError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _navigateByRole() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance
        .collection('users').doc(uid).get();
    if (!doc.exists) throw Exception('User not found in Firestore');
    final role = doc['role'] as String;
    if (!mounted) return;
    final Widget dest;
    if (role == 'admin') {
      dest = const AdminDashboard();
    } else if (role == 'principal') {
      dest = const PrincipalDashboard();
    } else if (role == 'crc') {
      dest = const PrincipalDashboard(isCrc: true);
    } else if (role == 'teacher') {
      dest = const TeacherDashboard();
    } else if (role == 'watchman') {
      dest = const WatchmanDashboard();
    } else {
      throw Exception('Invalid role: $role');
    }
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => dest));
  }

  Future<void> _signUp() async {
    final name  = _signupNameCtrl.text.trim();
    final phone = _signupPhoneCtrl.text.trim();
    final email = _signupEmailCtrl.text.trim();
    final pass  = _signupPassCtrl.text.trim();
    final schoolName = _signupSchoolNameCtrl.text.trim();
    final adminId = _signupAdminIdCtrl.text.trim();
    final confirmPass = _signupConfirmPassCtrl.text.trim();
    final address = _signupAddressCtrl.text.trim();

    if ([name, phone, email, pass, schoolName, adminId, confirmPass, address].any((s) => s.isEmpty)) {
      setState(() => _error = 'All fields are required.');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (pass != confirmPass) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() { _loading = true; _error = ''; });
    try {
      final schoolId = 'school_${schoolName.replaceAll(RegExp(r'\s+'), '_').toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}';

      // 1. Create user in Firebase Auth with custom adminId
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: email,
            password: pass,
            customUid: adminId,
            role: 'admin',
            schoolId: schoolId,
          );
      
      await cred.user!.updateDisplayName(name);

      // 2. Save school record
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .set({
            'name': schoolName,
            'address': address,
            'createdAt': FieldValue.serverTimestamp(),
          });

      // Cache schoolId in Auth immediately for constraint checks to pass during the user write
      FirebaseAuth.instance.currentSchoolId = schoolId;

      // 3. Save admin user details
      await FirebaseFirestore.instance
          .collection('users')
          .doc(adminId)
          .set({
            'name': name,
            'phone': phone,
            'email': email,
            'role': 'admin',
            'schoolId': schoolId,
            'schoolName': schoolName,
            'schoolAddress': address,
            'createdAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const AdminDashboard()));
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Sign-up failed');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleView() {
    setState(() { _showSignup = !_showSignup; _error = ''; });
    _animCtrl..reset()..forward();
  }

  void _switchMode(_LoginMode mode) {
    setState(() {
      _loginMode = mode;
      _error = '';
      _loginPassCtrl.clear();
      _loginEmailCtrl.clear();
      _loginPhoneCtrl.clear();
    });
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _parchment,
      body: Stack(children: [
        // Gradient background
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFEDD9A3), Color(0xFFC4A472)],
            ),
          ),
        ),

        Column(children: [
          // ── Top header ─────────────────────────────────────────────────
          Expanded(
            flex: 4,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: _maroon.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: _maroon.withValues(alpha: 0.45), width: 1.5),
                      ),
                      child: const Icon(Icons.how_to_reg_rounded,
                          color: _maroon, size: 28),
                    ),
                    const SizedBox(height: 20),
                    const Text('Attendance\nSystem',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          color: _maroonDark,
                          height: 1.15,
                          letterSpacing: -0.5,
                        )),
                    const SizedBox(height: 10),
                    Text('Sign in to your account to continue',
                        style: TextStyle(
                            fontSize: 13,
                            color: _maroonDark.withValues(alpha: 0.5))),
                  ],
                ),
              ),
            ),
          ),

          // ── Bottom card ────────────────────────────────────────────────
          Expanded(
            flex: 9,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Container(
                  decoration: BoxDecoration(
                    color: _parchmentLight.withValues(alpha: 0.97),
                    borderRadius: const BorderRadius.only(
                      topLeft:  Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x28643C0A),
                          blurRadius: 24,
                          offset: Offset(0, -6)),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 32, 28, 0),
                    child: Column(
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _showSignup
                              ? _SignupForm(
                            key: const ValueKey('signup'),
                            nameCtrl:  _signupNameCtrl,
                            phoneCtrl: _signupPhoneCtrl,
                            emailCtrl: _signupEmailCtrl,
                            passCtrl:  _signupPassCtrl,
                            schoolNameCtrl: _signupSchoolNameCtrl,
                            adminIdCtrl: _signupAdminIdCtrl,
                            confirmPassCtrl: _signupConfirmPassCtrl,
                            addressCtrl: _signupAddressCtrl,
                            obscure:   _obscureSignup,
                            onToggle:  () => setState(
                                    () => _obscureSignup = !_obscureSignup),
                            loading:   _loading,
                            error:     _error,
                            onSignup:  _signUp,
                            onSwitch:  _toggleView,
                          )
                              : _LoginForm(
                            key: const ValueKey('login'),
                            loginMode:    _loginMode,
                            emailCtrl:    _loginEmailCtrl,
                            phoneCtrl:    _loginPhoneCtrl,
                            passCtrl:     _loginPassCtrl,
                            obscure:      _obscureLogin,
                            onToggle:     () => setState(
                                    () => _obscureLogin = !_obscureLogin),
                            loading:      _loading,
                            error:        _error,
                            onLogin:      _loginMode == _LoginMode.email
                                ? _loginWithEmail
                                : _loginWithPhone,
                            onSwitch:     _toggleView,
                            onModeSwitch: _switchMode,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const _WarliDancerBorder(),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ── LOGIN FORM ────────────────────────────────────────────────────────────────

class _LoginForm extends StatelessWidget {
  final _LoginMode loginMode;
  final TextEditingController emailCtrl, phoneCtrl, passCtrl;
  final bool obscure;
  final VoidCallback onToggle, onLogin, onSwitch;
  final bool loading;
  final String error;
  final void Function(_LoginMode) onModeSwitch;

  const _LoginForm({
    super.key,
    required this.loginMode,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.passCtrl,
    required this.obscure,
    required this.onToggle,
    required this.loading,
    required this.error,
    required this.onLogin,
    required this.onSwitch,
    required this.onModeSwitch,
  });

  @override
  Widget build(BuildContext context) {
    final isPhone = loginMode == _LoginMode.phone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Welcome back',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _maroonDark,
            )),
        const SizedBox(height: 4),
        const Text('Enter your credentials below',
            style: TextStyle(fontSize: 13, color: _textMuted)),
        const SizedBox(height: 20),

        // ── Toggle pill ──────────────────────────────────────────────────
        // The key fix: the outer container has a fixed height of 52.
        // Each tab is an Expanded widget whose child is an AnimatedContainer
        // with height: double.infinity — so it truly fills the pill slot.
        Container(
          height: 52,
          decoration: BoxDecoration(
            // Slightly darker parchment so unselected tabs are visible
            color: const Color(0xFFE8D0A8),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _maroon.withValues(alpha: 0.25), width: 1.2),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              // ── Email tab ────────────────────────────────────────────
              Expanded(
                child: GestureDetector(
                  onTap: () => onModeSwitch(_LoginMode.email),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 230),
                    curve: Curves.easeInOut,
                    // height: double.infinity fills the pill's inner height (44px)
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: !isPhone ? _maroon : Colors.transparent,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: !isPhone
                          ? [
                        BoxShadow(
                            color: _maroon.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2))
                      ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.mail_outline_rounded,
                            size: 15,
                            color: !isPhone ? _parchmentLight : _textMuted),
                        const SizedBox(width: 6),
                        Text('Email',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: !isPhone ? _parchmentLight : _textMuted,
                            )),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Mobile (Teacher) tab ─────────────────────────────────
              Expanded(
                child: GestureDetector(
                  onTap: () => onModeSwitch(_LoginMode.phone),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 230),
                    curve: Curves.easeInOut,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: isPhone ? _maroon : Colors.transparent,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: isPhone
                          ? [
                        BoxShadow(
                            color: _maroon.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2))
                      ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.phone_outlined,
                            size: 15,
                            color: isPhone ? _parchmentLight : _textMuted),
                        const SizedBox(width: 6),
                        Text('Mobile',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isPhone ? _parchmentLight : _textMuted,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── Identifier field ─────────────────────────────────────────────
        if (!isPhone) ...[
          const _FieldLabel(label: 'Email Address'),
          const SizedBox(height: 8),
          _Field(
            controller: emailCtrl,
            hint: 'you@school.edu',
            prefixIcon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
          ),
        ] else ...[
          const _FieldLabel(label: 'Mobile Number'),
          const SizedBox(height: 8),
          _Field(
            controller: phoneCtrl,
            hint: 'e.g. 9876543210',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            formatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text(
              'Use the mobile number registered by your admin.',
              style:
              TextStyle(fontSize: 11, color: _textMuted.withValues(alpha: 0.7)),
            ),
          ),
        ],

        const SizedBox(height: 18),
        const _FieldLabel(label: 'Password'),
        const SizedBox(height: 8),
        _Field(
          controller: passCtrl,
          hint: '••••••••',
          prefixIcon: Icons.lock_outline_rounded,
          obscure: obscure,
          suffix: IconButton(
            icon: Icon(
              obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: _textMuted, size: 20,
            ),
            onPressed: onToggle,
          ),
        ),

        const SizedBox(height: 28),
        if (loading)
          const Center(
              child: CircularProgressIndicator(
                  color: _maroon, strokeWidth: 2.5))
        else
          _BigButton(
            label: isPhone ? 'Sign In as Teacher' : 'Sign In',
            onPressed: onLogin,
          ),

        if (error.isNotEmpty) ...[
          const SizedBox(height: 14),
          _ErrorBanner(message: error),
        ],

        const SizedBox(height: 28),
        const _HRule(label: 'admin?'),
        const SizedBox(height: 12),
        Center(
          child: GestureDetector(
            onTap: onSwitch,
            child: RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 13, color: _textMuted),
                children: [
                  TextSpan(text: 'Sign Up '),
                  TextSpan(
                    text: '(Admin only)',
                    style: TextStyle(
                      color: _maroon,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── SIGN-UP FORM ──────────────────────────────────────────────────────────────

class _SignupForm extends StatelessWidget {
  final TextEditingController nameCtrl, phoneCtrl, emailCtrl, passCtrl;
  final TextEditingController schoolNameCtrl, adminIdCtrl, confirmPassCtrl, addressCtrl;
  final bool obscure;
  final VoidCallback onToggle, onSignup, onSwitch;
  final bool loading;
  final String error;

  const _SignupForm({
    super.key,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.emailCtrl,
    required this.passCtrl,
    required this.schoolNameCtrl,
    required this.adminIdCtrl,
    required this.confirmPassCtrl,
    required this.addressCtrl,
    required this.obscure,
    required this.onToggle,
    required this.loading,
    required this.error,
    required this.onSignup,
    required this.onSwitch,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Admin badge
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: _maroon.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _maroon.withValues(alpha: 0.3)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_outlined, color: _maroon, size: 14),
              SizedBox(width: 6),
              Text('School & Admin Registration',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _maroon,
                      letterSpacing: 0.3)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text('Create School Account',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _maroonDark,
            )),
        const SizedBox(height: 4),
        const Text('Register your school and administrator account',
            style: TextStyle(fontSize: 13, color: _textMuted)),
        const SizedBox(height: 24),

        // School Fields
        const _FieldLabel(label: 'School Name'),
        const SizedBox(height: 8),
        _Field(controller: schoolNameCtrl, hint: 'e.g. Greenfield Public School',
            prefixIcon: Icons.school_outlined),
        const SizedBox(height: 16),

        const _FieldLabel(label: 'School Address'),
        const SizedBox(height: 8),
        _Field(controller: addressCtrl, hint: 'Full physical address',
            prefixIcon: Icons.location_on_outlined),
        const SizedBox(height: 16),

        // Admin Fields
        const _FieldLabel(label: 'Admin Name'),
        const SizedBox(height: 8),
        _Field(controller: nameCtrl, hint: 'Your full name',
            prefixIcon: Icons.person_outline_rounded),
        const SizedBox(height: 16),

        const _FieldLabel(label: 'Admin ID'),
        const SizedBox(height: 8),
        _Field(controller: adminIdCtrl, hint: 'Choose a unique username or ID',
            prefixIcon: Icons.badge_outlined),
        const SizedBox(height: 16),

        const _FieldLabel(label: 'Admin Number (Phone)'),
        const SizedBox(height: 8),
        _Field(
          controller: phoneCtrl,
          hint: 'e.g. 9876543210',
          prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          formatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
        ),
        const SizedBox(height: 16),

        const _FieldLabel(label: 'Admin Email Address'),
        const SizedBox(height: 8),
        _Field(controller: emailCtrl, hint: 'admin@school.edu',
            prefixIcon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 16),

        const _FieldLabel(label: 'Create Password'),
        const SizedBox(height: 8),
        _Field(
          controller: passCtrl,
          hint: 'At least 6 characters',
          prefixIcon: Icons.lock_outline_rounded,
          obscure: obscure,
          suffix: IconButton(
            icon: Icon(
              obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: _textMuted, size: 20,
            ),
            onPressed: onToggle,
          ),
        ),
        const SizedBox(height: 16),

        const _FieldLabel(label: 'Confirm Password'),
        const SizedBox(height: 8),
        _Field(
          controller: confirmPassCtrl,
          hint: 'Re-enter password',
          prefixIcon: Icons.lock_outline_rounded,
          obscure: obscure,
        ),

        const SizedBox(height: 28),
        if (loading)
          const Center(
              child: CircularProgressIndicator(
                  color: _maroon, strokeWidth: 2.5))
        else
          _BigButton(label: 'Register & Setup School', onPressed: onSignup),

        if (error.isNotEmpty) ...[
          const SizedBox(height: 14),
          _ErrorBanner(message: error),
        ],

        const SizedBox(height: 24),
        Center(
          child: GestureDetector(
            onTap: onSwitch,
            child: RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 13, color: _textMuted),
                children: [
                  TextSpan(text: 'Already have an account? '),
                  TextSpan(
                    text: 'Sign In',
                    style: TextStyle(
                      color: _maroon,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── SHARED HELPER WIDGETS ─────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
    label.toUpperCase(),
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: Color(0xFF5C2E08),
      letterSpacing: 0.8,
    ),
  );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? formatters;

  const _Field({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.obscure    = false,
    this.suffix,
    this.keyboardType,
    this.formatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      style: const TextStyle(fontSize: 14, color: _maroonDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
        const TextStyle(color: Color(0xFFC4A47A), fontSize: 14),
        prefixIcon: Icon(prefixIcon, color: _textMuted, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: _parchmentLight.withValues(alpha: 0.7),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide:
            const BorderSide(color: _maroonLight, width: 1.5)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide:
            const BorderSide(color: _maroonLight, width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide:
            const BorderSide(color: _maroon, width: 2)),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _BigButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _maroon,
          foregroundColor: _parchmentLight,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                )),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFC83232).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border:
        Border.all(color: const Color(0xFFB43232).withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded,
            color: Color(0xFF8B1A1A), size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF8B1A1A))),
        ),
      ]),
    );
  }
}

class _HRule extends StatelessWidget {
  final String label;
  const _HRule({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
          child: Container(
              height: 1, color: _maroonLight.withValues(alpha: 0.4))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(label,
            style: const TextStyle(fontSize: 12, color: _textMuted)),
      ),
      Expanded(
          child: Container(
              height: 1, color: _maroonLight.withValues(alpha: 0.4))),
    ]);
  }
}

// ── WARLI DANCER BORDER ───────────────────────────────────────────────────────

class _WarliDancerBorder extends StatelessWidget {
  const _WarliDancerBorder();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: CustomPaint(
        painter: _DancerPainter(),
        size: Size(MediaQuery.of(context).size.width, 48),
      ),
    );
  }
}

class _DancerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = _maroon
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final fill = Paint()
      ..color = _maroon
      ..style = PaintingStyle.fill;

    final spacing = 14.0;
    final count   = (size.width / spacing).ceil();

    for (var i = 0; i < count; i++) {
      final x    = i * spacing + spacing / 2;
      final cy   = size.height - 28.0;
      final flip = i.isEven ? 1.0 : -1.0;
      canvas.drawCircle(Offset(x, cy - 12), 2.5, fill);
      canvas.drawLine(Offset(x, cy - 9), Offset(x, cy - 2), stroke);
      canvas.drawLine(
          Offset(x, cy - 7), Offset(x - flip * 3.5, cy - 4), stroke);
      canvas.drawLine(
          Offset(x, cy - 7), Offset(x + flip * 3.5, cy - 4), stroke);
      canvas.drawLine(Offset(x, cy - 2), Offset(x - 3, cy + 4), stroke);
      canvas.drawLine(Offset(x, cy - 2), Offset(x + 3, cy + 4), stroke);
    }
    canvas.drawLine(
        Offset(0, size.height - 32),
        Offset(size.width, size.height - 32),
        Paint()
          ..color = _maroon.withValues(alpha: 0.4)
          ..strokeWidth = 0.8);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}