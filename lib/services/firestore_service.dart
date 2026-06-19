import 'package:attendance_system/services/mongodb_service.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Save user profile with role
  Future<void> createUserProfile({
    required String uid,
    required String name,
    required String email,
    required String role,
  }) async {
    await _db.collection('users').doc(uid).set({
      'name': name,
      'email': email,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Get current user's role
  Future<String> getUserRole(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc['role'];
  }
}