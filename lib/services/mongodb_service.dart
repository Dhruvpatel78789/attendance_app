import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:shared_preferences/shared_preferences.dart';

// ── MOCK/SHIM CLASSES FOR FIREBASE ───────────────────────────────────────────

// Dummy settings and options to make Firebase calls compile
class Settings {
  final bool persistenceEnabled;
  const Settings({this.persistenceEnabled = true});
}

class FirebaseOptions {
  final String apiKey;
  final String appId;
  final String messagingSenderId;
  final String projectId;
  const FirebaseOptions({
    required this.apiKey,
    required this.appId,
    required this.messagingSenderId,
    required this.projectId,
  });
}

class FirebaseApp {
  final String name;
  final FirebaseOptions options;
  FirebaseApp({required this.name, required this.options});

  Future<void> delete() async {}
}

class Firebase {
  static final FirebaseApp _defaultApp = FirebaseApp(
    name: '[DEFAULT]',
    options: const FirebaseOptions(
      apiKey: 'demo-api-key',
      appId: 'demo-app-id',
      messagingSenderId: 'demo-sender-id',
      projectId: 'demo-project-id',
    ),
  );

  static FirebaseApp app() => _defaultApp;

  static Future<FirebaseApp> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    await MongoDBService.init();
    return _defaultApp;
  }
}

// ── TIMESTAMP SHIM ───────────────────────────────────────────────────────────
class Timestamp implements Comparable<Timestamp> {
  final int seconds;
  final int nanoseconds;

  const Timestamp(this.seconds, this.nanoseconds);

  factory Timestamp.fromDate(DateTime date) {
    final ms = date.millisecondsSinceEpoch;
    final sec = ms ~/ 1000;
    final nano = (ms % 1000) * 1000000;
    return Timestamp(sec, nano);
  }

  factory Timestamp.now() => Timestamp.fromDate(DateTime.now());

  DateTime toDate() => DateTime.fromMillisecondsSinceEpoch(seconds * 1000 + nanoseconds ~/ 1000000);

  @override
  int compareTo(Timestamp other) {
    if (seconds != other.seconds) {
      return seconds.compareTo(other.seconds);
    }
    return nanoseconds.compareTo(other.nanoseconds);
  }

  @override
  bool operator ==(Object other) =>
      other is Timestamp &&
      other.seconds == seconds &&
      other.nanoseconds == nanoseconds;

  @override
  int get hashCode => Object.hash(seconds, nanoseconds);

  @override
  String toString() => 'Timestamp(seconds=$seconds, nanoseconds=$nanoseconds)';
}

// ── MONGO DATABASE MANAGER via REST API ───────────────────────────────────────
class MongoDBService {
  static String get baseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5050/api';
    }
    return 'http://localhost:5050/api';
  }

  static final StreamController<String> _dbUpdates = StreamController<String>.broadcast();

  static Future<void> init() async {
    print("REST API client initialized. Base URL: $baseUrl");
  }

  static void notifyUpdate(String collectionName) {
    _dbUpdates.add(collectionName);
  }

  static Stream<String> get updateStream => _dbUpdates.stream;
}

// ── FIRESTORE SHIM IMPLEMENTATION ────────────────────────────────────────────

class SetOptions {
  final bool merge;
  const SetOptions({this.merge = false});
}

class FieldValueDelete {
  const FieldValueDelete();
}

class FieldValue {
  static DateTime serverTimestamp() => DateTime.now();
  static FieldValueDelete delete() => const FieldValueDelete();
}

class FirebaseFirestore {
  static final FirebaseFirestore instance = FirebaseFirestore._();
  FirebaseFirestore._();

  Settings settings = const Settings();

  CollectionReference collection(String path) {
    return CollectionReference(path);
  }

  WriteBatch batch() => WriteBatch();
}

class DocumentReference {
  final String collectionPath;
  final String id;

  DocumentReference(this.collectionPath, this.id);

  String get _resolvedId {
    if (collectionPath == 'students' ||
        collectionPath == 'classes' ||
        collectionPath == 'attendance' ||
        collectionPath == 'leave_requests') {
      final schoolId = FirebaseAuth.instance.currentSchoolId;
      if (schoolId != null && !id.startsWith('${schoolId}_')) {
        return '${schoolId}_$id';
      }
    }
    return id;
  }

  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    if (options?.merge == true) {
      await update(data);
      return;
    }

    final cleanData = _normalizeData(data);
    
    // Inject schoolId automatically if user is logged in
    final schoolId = FirebaseAuth.instance.currentSchoolId;
    if (schoolId != null && !cleanData.containsKey('schoolId') && collectionPath != 'schools') {
      cleanData['schoolId'] = schoolId;
    }

    final jsonPayload = _serializeForJson(cleanData);
    final response = await http.post(
      Uri.parse('${MongoDBService.baseUrl}/documents/$collectionPath/$_resolvedId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(jsonPayload),
    );

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to save document');
    }

    MongoDBService.notifyUpdate(collectionPath);
  }

  Future<void> update(Map<String, dynamic> data) async {
    final cleanData = <String, dynamic>{};
    final unsetFields = <String, dynamic>{};

    data.forEach((key, val) {
      final mongoVal = _convertToMongoTypes(val);
      if (mongoVal is FieldValueDelete) {
        unsetFields[key] = "";
      } else {
        cleanData[key] = mongoVal;
      }
    });

    final payload = <String, dynamic>{};
    if (cleanData.isNotEmpty) {
      payload[r'$set'] = _serializeForJson(cleanData);
    }
    if (unsetFields.isNotEmpty) {
      payload[r'$unset'] = unsetFields;
    }

    final response = await http.put(
      Uri.parse('${MongoDBService.baseUrl}/documents/$collectionPath/$_resolvedId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to update document');
    }

    MongoDBService.notifyUpdate(collectionPath);
  }

  Future<void> delete() async {
    final response = await http.delete(
      Uri.parse('${MongoDBService.baseUrl}/documents/$collectionPath/$_resolvedId'),
    );

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to delete document');
    }

    MongoDBService.notifyUpdate(collectionPath);
  }

  Future<DocumentSnapshot> get() async {
    final response = await http.get(
      Uri.parse('${MongoDBService.baseUrl}/documents/$collectionPath/$_resolvedId'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to get document');
    }

    final body = response.body.trim();
    if (body.isEmpty || body == 'null') {
      return DocumentSnapshot(id, null, collectionPath);
    }

    final doc = jsonDecode(response.body) as Map<String, dynamic>;
    if (collectionPath == 'users' && doc['_id'] == FirebaseAuth.instance.currentUser?.uid) {
      FirebaseAuth.instance.currentSchoolId = doc['schoolId'] as String?;
    }
    return DocumentSnapshot(id, doc, collectionPath);
  }

  Stream<DocumentSnapshot> snapshots() {
    final controller = StreamController<DocumentSnapshot>();
    
    void fetch() async {
      try {
        final doc = await get();
        if (!controller.isClosed) controller.add(doc);
      } catch (_) {}
    }

    fetch();
    final sub = MongoDBService.updateStream.listen((coll) {
      if (coll == collectionPath) fetch();
    });

    final timer = Timer.periodic(const Duration(milliseconds: 1500), (_) => fetch());

    controller.onCancel = () {
      sub.cancel();
      timer.cancel();
      controller.close();
    };

    return controller.stream;
  }
}

class DocumentSnapshot {
  final String id;
  final Map<String, dynamic>? _data;
  final String collectionPath;

  DocumentSnapshot(String id, this._data, this.collectionPath)
      : id = _cleanId(id, collectionPath);

  static String _cleanId(String rawId, String colPath) {
    if (colPath == 'students' ||
        colPath == 'classes' ||
        colPath == 'attendance' ||
        colPath == 'leave_requests') {
      final schoolId = FirebaseAuth.instance.currentSchoolId;
      if (schoolId != null && rawId.startsWith('${schoolId}_')) {
        return rawId.substring(schoolId.length + 1);
      }
    }
    return rawId;
  }

  bool get exists => _data != null;

  Map<String, dynamic> data() {
    if (_data == null) return {};
    return _convertToFirebaseMap(_data!);
  }

  dynamic operator [](String key) {
    if (_data == null) return null;
    if (key == 'id') return id;
    return _convertToFirebaseTypes(_data![key]);
  }

  DocumentReference get reference => DocumentReference(collectionPath, id);
}

class QueryDocumentSnapshot extends DocumentSnapshot {
  QueryDocumentSnapshot(super.id, super.data, super.collectionPath);
}

class QuerySnapshot {
  final List<QueryDocumentSnapshot> docs;
  QuerySnapshot(this.docs);
}

class Query {
  final String collectionPath;
  final Map<String, dynamic> _filters;
  final int? _limit;
  final String? _orderByField;
  final bool _orderByDescending;

  Query(this.collectionPath, [Map<String, dynamic>? filters, this._limit, this._orderByField, this._orderByDescending = false])
      : _filters = filters != null ? Map<String, dynamic>.from(filters) : {};

  Query where(String field, {dynamic isEqualTo, List<dynamic>? whereIn}) {
    final newFilters = Map<String, dynamic>.from(_filters);
    if (isEqualTo != null) {
      final key = field == 'id' || field == 'uid' || field == 'grNumber' ? '_id' : field;
      newFilters[key] = _convertToMongoTypes(isEqualTo);
    }
    if (whereIn != null) {
      final key = field == 'id' || field == 'uid' || field == 'grNumber' ? '_id' : field;
      newFilters[key] = {r'$in': whereIn.map(_convertToMongoTypes).toList()};
    }
    return Query(collectionPath, newFilters, _limit, _orderByField, _orderByDescending);
  }

  Query limit(int l) {
    return Query(collectionPath, _filters, l, _orderByField, _orderByDescending);
  }

  Query orderBy(String field, {bool descending = false}) {
    return Query(collectionPath, _filters, _limit, field, descending);
  }

  Future<QuerySnapshot> get() async {
    final schoolId = FirebaseAuth.instance.currentSchoolId;
    final Map<String, dynamic> activeFilters = Map<String, dynamic>.from(_filters);
    
    if (schoolId != null && 
        collectionPath != 'schools' && 
        collectionPath != 'users' && 
        !activeFilters.containsKey('schoolId')) {
      activeFilters['schoolId'] = schoolId;
    }
    if (schoolId != null && collectionPath == 'users' && !activeFilters.containsKey('schoolId') && !activeFilters.containsKey('_id')) {
      activeFilters['schoolId'] = schoolId;
    }

    final cleanFilters = _serializeForJson(activeFilters);

    Map<String, String> params = {
      'filters': jsonEncode(cleanFilters),
    };
    if (_limit != null) {
      params['limit'] = _limit.toString();
    }
    if (_orderByField != null) {
      final sortKey = _orderByField == 'id' || _orderByField == 'uid' || _orderByField == 'grNumber' ? '_id' : _orderByField;
      params['sort'] = jsonEncode({sortKey: _orderByDescending ? -1 : 1});
    }

    final uri = Uri.parse('${MongoDBService.baseUrl}/documents/$collectionPath').replace(queryParameters: params);
    final response = await http.get(uri);
    
    if (response.statusCode != 200) {
      throw Exception('Failed to load documents: ${response.body}');
    }

    final List<dynamic> list = jsonDecode(response.body);
    final docs = list.map((item) {
      final map = item as Map<String, dynamic>;
      final docId = map['_id']?.toString() ?? '';
      return QueryDocumentSnapshot(docId, map, collectionPath);
    }).toList();

    return QuerySnapshot(docs);
  }

  Stream<QuerySnapshot> snapshots() {
    final controller = StreamController<QuerySnapshot>();

    void fetch() async {
      try {
        final snap = await get();
        if (!controller.isClosed) controller.add(snap);
      } catch (_) {}
    }

    fetch();
    final sub = MongoDBService.updateStream.listen((coll) {
      if (coll == collectionPath) fetch();
    });

    final timer = Timer.periodic(const Duration(milliseconds: 1500), (_) => fetch());

    controller.onCancel = () {
      sub.cancel();
      timer.cancel();
      controller.close();
    };

    return controller.stream;
  }
}

class CollectionReference extends Query {
  CollectionReference(super.collectionPath);

  DocumentReference doc([String? id]) {
    final actualId = id ?? (mongo.ObjectId().oid);
    return DocumentReference(collectionPath, actualId);
  }

  Future<DocumentReference> add(Map<String, dynamic> data) async {
    final docId = mongo.ObjectId().oid;
    final ref = doc(docId);
    await ref.set(data);
    return ref;
  }
}

class WriteBatch {
  final List<Future<void> Function()> _operations = [];

  void set(DocumentReference ref, Map<String, dynamic> data) {
    _operations.add(() => ref.set(data));
  }

  void update(DocumentReference ref, Map<String, dynamic> data) {
    _operations.add(() => ref.update(data));
  }

  void delete(DocumentReference ref) {
    _operations.add(() => ref.delete());
  }

  Future<void> commit() async {
    for (final op in _operations) {
      await op();
    }
  }
}

// ── AUTH SHIM IMPLEMENTATION ─────────────────────────────────────────────────

class AuthCredential {}

class EmailAuthProvider {
  static AuthCredential credential({required String email, required String password}) => AuthCredential();
}

class User {
  final String uid;
  final String? email;
  String? displayName;

  User({required this.uid, this.email, this.displayName});

  Future<void> updateDisplayName(String name) async {
    displayName = name;
    await FirebaseFirestore.instance.collection('users').doc(uid).update({'name': name});
    await FirebaseAuth.instance._persistSession(this, FirebaseAuth.instance.jwtToken, FirebaseAuth.instance.currentSchoolId);
  }

  Future<void> reauthenticateWithCredential(AuthCredential credential) async {}
}

class UserCredential {
  final User? user;
  UserCredential({this.user});
}

class FirebaseAuthException implements Exception {
  final String code;
  final String? message;
  FirebaseAuthException({required this.code, this.message});

  @override
  String toString() => message ?? code;
}

class FirebaseAuth {
  static final FirebaseAuth instance = FirebaseAuth._();
  FirebaseAuth._();

  static final Map<String, FirebaseAuth> _instances = {};

  static FirebaseAuth instanceFor({required FirebaseApp app}) {
    return _instances.putIfAbsent(app.name, () => FirebaseAuth._());
  }

  User? _currentUser;
  String? _jwtToken; 
  String? _currentSchoolId; // Cached schoolId for data isolation

  String? get currentSchoolId => _currentSchoolId;
  set currentSchoolId(String? val) {
    _currentSchoolId = val;
    _persistSession(_currentUser, _jwtToken, val);
  }

  static SharedPreferences? _prefs;

  static Future<void> initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    final uid = _prefs?.getString('auth_uid');
    final email = _prefs?.getString('auth_email');
    final name = _prefs?.getString('auth_name');
    final schoolId = _prefs?.getString('auth_schoolId');
    final token = _prefs?.getString('auth_token');

    if (uid != null) {
      instance._currentUser = User(uid: uid, email: email, displayName: name);
      instance._jwtToken = token;
      instance._currentSchoolId = schoolId;
    }
  }

  Future<void> _persistSession(User? user, String? token, String? schoolId) async {
    if (_prefs == null) _prefs = await SharedPreferences.getInstance();
    if (user != null) {
      await _prefs?.setString('auth_uid', user.uid);
      await _prefs?.setString('auth_email', user.email ?? '');
      await _prefs?.setString('auth_name', user.displayName ?? '');
      await _prefs?.setString('auth_token', token ?? '');
      if (schoolId != null) {
        await _prefs?.setString('auth_schoolId', schoolId);
      } else {
        await _prefs?.remove('auth_schoolId');
      }
    } else {
      await _prefs?.remove('auth_uid');
      await _prefs?.remove('auth_email');
      await _prefs?.remove('auth_name');
      await _prefs?.remove('auth_token');
      await _prefs?.remove('auth_schoolId');
    }
  }

  final StreamController<User?> _authController = StreamController<User?>.broadcast();

  User? get currentUser => _currentUser;
  String? get jwtToken => _jwtToken;

  Stream<User?> authStateChanges() {
    Timer.run(() => _authController.add(_currentUser));
    return _authController.stream;
  }

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('${MongoDBService.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode != 200) {
      final err = jsonDecode(response.body)['error'] ?? 'Login failed';
      throw FirebaseAuthException(code: 'auth-error', message: err);
    }

    final res = jsonDecode(response.body);
    _jwtToken = res['token'] as String?;
    final userDoc = res['user'] as Map<String, dynamic>;
    _currentSchoolId = userDoc['schoolId'] as String?;
    
    _currentUser = User(
      uid: res['uid'] as String,
      email: email,
      displayName: userDoc['name'] as String?,
    );
    await _persistSession(_currentUser, _jwtToken, _currentSchoolId);
    _authController.add(_currentUser);
    return UserCredential(user: _currentUser);
  }

  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
    String? customUid,
    String? role,
    String? schoolId,
  }) async {
    final response = await http.post(
      Uri.parse('${MongoDBService.baseUrl}/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'customUid': customUid,
        'role': role,
        'schoolId': schoolId,
      }),
    );

    if (response.statusCode != 200) {
      final err = jsonDecode(response.body)['error'] ?? 'Signup failed';
      throw FirebaseAuthException(code: 'email-already-in-use', message: err);
    }

    final res = jsonDecode(response.body);
    _jwtToken = res['token'] as String?;
    if (schoolId != null) {
      _currentSchoolId = schoolId;
    }
    
    _currentUser = User(
      uid: res['uid'] as String,
      email: email,
    );
    await _persistSession(_currentUser, _jwtToken, _currentSchoolId);
    _authController.add(_currentUser);
    return UserCredential(user: _currentUser);
  }

  Future<void> sendPasswordResetEmail({required String email}) async {}

  Future<void> signOut() async {
    _currentUser = null;
    _jwtToken = null;
    _currentSchoolId = null;
    await _persistSession(null, null, null);
    _authController.add(null);
  }
}

// Helper to sanitize/normalize data values for MongoDB insertion (e.g. converting FieldValue and Timestamp)
Map<String, dynamic> _normalizeData(Map<String, dynamic> data) {
  final result = <String, dynamic>{};
  data.forEach((key, val) {
    result[key] = _convertToMongoTypes(val);
  });
  return result;
}

dynamic _convertToMongoTypes(dynamic val) {
  if (val is Timestamp) {
    return val.toDate();
  } else if (val is FieldValueDelete) {
    return val; // Handle specially in update()
  } else if (val is Function) {
    return DateTime.now();
  } else if (val is Map) {
    return val.map((k, v) => MapEntry(k, _convertToMongoTypes(v)));
  } else if (val is List) {
    return val.map(_convertToMongoTypes).toList();
  }
  return val;
}

Map<String, dynamic> _convertToFirebaseMap(Map raw) {
  final Map<String, dynamic> result = {};
  raw.forEach((key, value) {
    if (key.toString() == '_id') return;
    result[key.toString()] = _convertToFirebaseTypes(value);
  });
  return result;
}

dynamic _convertToFirebaseTypes(dynamic val) {
  if (val is String) {
    // Attempt parsing Mongo BSON Date strings returned by Express JSON parser
    try {
      final parsed = DateTime.parse(val);
      if (val.length >= 19 && val.contains('-') && val.contains('T')) {
        return Timestamp.fromDate(parsed);
      }
    } catch (_) {}
  }
  if (val is DateTime) {
    return Timestamp.fromDate(val);
  } else if (val is Map) {
    return _convertToFirebaseMap(val);
  } else if (val is List) {
    return val.map(_convertToFirebaseTypes).toList();
  }
  return val;
}

dynamic _serializeForJson(dynamic val) {
  if (val is Timestamp) {
    return val.toDate().toIso8601String();
  } else if (val is DateTime) {
    return val.toIso8601String();
  } else if (val is Map) {
    return val.map((k, v) => MapEntry(k.toString(), _serializeForJson(v)));
  } else if (val is List) {
    return val.map(_serializeForJson).toList();
  }
  return val;
}
