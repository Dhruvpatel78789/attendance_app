import 'package:flutter/material.dart';
import 'package:attendance_system/services/mongodb_service.dart';

// Screens
import 'screens/admin/admin_dashboard.dart';
import 'screens/principal/principal_dashboard.dart';
import 'screens/teacher/teacher_dashboard.dart';
import 'screens/watchman/watchman_dashboard.dart';
import 'login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {

        // NOT LOGGED IN
        if (!snapshot.hasData) {
          return const LoginPage();
        }

        final user = FirebaseAuth.instance.currentUser!;

        // FETCH USER ROLE FROM FIRESTORE
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(user!.uid)
              .get(),
          builder: (context, snap) {

            // LOADING
            if (snap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // ERROR
            if (snap.hasError) {
              print("Firestore error: ${snap.error}");
              return Scaffold(
                body: Center(child: Text("Error: ${snap.error}")),
              );
            }

            // NO DATA
            if (!snap.hasData || !snap.data!.exists) {
              return const Scaffold(
                body: Center(child: Text("User not found in Firestore")),
              );
            }
            print("UID: ${user.uid}");
            final data = snap.data!.data() as Map<String, dynamic>;
            final role = data['role'];

            if (role == 'admin') return const AdminDashboard();
            if (role == 'teacher') return const TeacherDashboard();
            if (role == 'principal') return const PrincipalDashboard();
            if (role == 'watchman') return const WatchmanDashboard();

            return const Scaffold(
              body: Center(child: Text("Invalid role")),
            );
          },
        );
      },
    );
  }
}