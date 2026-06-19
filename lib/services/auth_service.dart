import 'package:attendance_system/services/mongodb_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Admin creates a new user
  Future<void> adminCreateUser({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    // Get the current school ID from the main auth instance
    final schoolId = FirebaseAuth.instance.currentSchoolId;

    // Create secondary Firebase app so admin stays logged in
    FirebaseApp tempApp = await Firebase.initializeApp(
      name: 'SecondaryApp',
      options: Firebase.app().options,
    );

    FirebaseAuth tempAuth = FirebaseAuth.instanceFor(app: tempApp);

    // Create user in Firebase Auth with correct schoolId and role
    UserCredential userCred = await tempAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
      role: role,
      schoolId: schoolId,
    );

    String uid = userCred.user!.uid;

    // Save user in Firestore
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'name': name,
      'email': email,
      'role': role,
      'schoolId': schoolId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Delete temp app
    await tempApp.delete();
  }
  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
  }
}