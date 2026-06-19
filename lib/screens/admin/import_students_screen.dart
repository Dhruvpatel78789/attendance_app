import 'dart:convert';
import '../../utils/download_helper.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:attendance_system/services/mongodb_service.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart' as excel;

import 'admin_dashboard.dart';

enum DuplicateAction { overwrite, reassign, skip }

class ImportStudentsScreen extends StatefulWidget {
  const ImportStudentsScreen({super.key});

  @override
  State<ImportStudentsScreen> createState() => _ImportStudentsScreenState();
}

class _ImportStudentsScreenState extends State<ImportStudentsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool loading  = false;
  int  progress = 0;
  int  total    = 0;

  // upload success banner state
  bool _uploadDone    = false;
  int  _uploadSuccess = 0;
  int  _uploadSkipped = 0;

  // ════════════════════════════════════════════════════════════════
  // DOWNLOAD SAMPLE CSV
  // ════════════════════════════════════════════════════════════════
  Future<void> downloadSampleCsv() async {
    const csvContent =
        'Roll.No,Class,Division,GR.No,Name of student,Gender (Male/Female),Date of Birth,Address (Pada Vilage),Aadhaar No,Contact No\n'
        '1,10,A,641,Rahul Sharma,Male,15/08/2015,"123 Gandhi Nagar, Surat",123456789012,9876543210\n';

    try {
      await downloadCsv(csvContent);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not download template: $e'),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  // ════════════════════════════════════════════════════════════════
  // PICK CSV  (core logic unchanged)
  // ════════════════════════════════════════════════════════════════
  Future<void> pickFile() async {
    setState(() {
      _uploadDone = false;
    });

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx'],
    );

    if (result == null) return;

    final file = result.files.single;
    final ext = file.extension?.toLowerCase();

    try {
      List<Map<String, dynamic>> rows;

      /// 🌐 WEB (bytes available)
      if (file.bytes != null) {
        if (ext == 'csv') {
          final raw = utf8.decode(file.bytes!);
          rows = parseCsv(raw);
        } else if (ext == 'xlsx') {
          rows = parseExcel(file.bytes!);
        } else {
          throw Exception("Unsupported file type");
        }
      }

      /// 📱 MOBILE / DESKTOP (path available)
      else if (file.path != null) {
        final fileBytes = await File(file.path!).readAsBytes();

        if (ext == 'csv') {
          final raw = utf8.decode(fileBytes);
          rows = parseCsv(raw);
        } else if (ext == 'xlsx') {
          rows = parseExcel(fileBytes);
        } else {
          throw Exception("Unsupported file type");
        }
      }

      else {
        throw Exception("Unable to read file");
      }

      await processRows(rows);

    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error reading file: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ════════════════════════════════════════════════════════════════
  // PARSE CSV  (core logic unchanged)
  // ════════════════════════════════════════════════════════════════
  List<Map<String, dynamic>> parseCsv(String rawCsv) {
    final rows    = const CsvToListConverter().convert(rawCsv);
    if (rows.isEmpty) return [];

    int headerIndex = 0;
    for (int i = 0; i < (rows.length < 5 ? rows.length : 5); i++) {
      final r = rows[i];
      final hasHeader = r.any((cell) {
        final s = cell?.toString().trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') ?? '';
        return s == 'grno' || s == 'rollno' || s == 'nameofstudent' || s == 'grnumber' || s == 'class';
      });
      if (hasHeader) {
        headerIndex = i;
        break;
      }
    }

    final headers = rows[headerIndex].map((e) => e.toString()).toList();
    return rows.skip(headerIndex + 1).map((row) {
      final map = <String, dynamic>{};
      for (int i = 0; i < headers.length; i++) {
        if (i < row.length) {
          map[headers[i]] = row[i]?.toString();
        }
      }
      return map;
    }).toList();
  }

  List<Map<String, dynamic>> parseExcel(Uint8List bytes) {
    final excelFile = excel.Excel.decodeBytes(bytes);
    final sheet = excelFile.tables.values.first;

    if (sheet == null || sheet.rows.isEmpty) {
      throw Exception("Excel file is empty");
    }

    int headerIndex = 0;
    for (int i = 0; i < (sheet.rows.length < 5 ? sheet.rows.length : 5); i++) {
      final r = sheet.rows[i];
      final hasHeader = r.any((cell) {
        final s = cell?.value?.toString().trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') ?? '';
        return s == 'grno' || s == 'rollno' || s == 'nameofstudent' || s == 'grnumber' || s == 'class';
      });
      if (hasHeader) {
        headerIndex = i;
        break;
      }
    }

    final headers = sheet.rows[headerIndex].map((cell) {
      return cell?.value.toString().trim();
    }).toList();

    return sheet.rows.skip(headerIndex + 1).map((row) {
      final map = <String, dynamic>{};
      for (int i = 0; i < headers.length; i++) {
        final key = headers[i];
        if (key == null || key.isEmpty) continue;
        final cell = i < row.length ? row[i] : null;
        map[key] = cell?.value?.toString().trim();
      }
      return map;
    }).toList();
  }

  // ════════════════════════════════════════════════════════════════
  // PROCESS + PREVIEW  (core logic unchanged)
  // ════════════════════════════════════════════════════════════════
  Future<void> processRows(List<Map<String, dynamic>> rows) async {
    List<Map<String, dynamic>> students = [];
    List<String> errors = [];
    for (var row in rows) {
      final student = mapStudent(row, errors);
      if (student != null) students.add(student);
    }
    total = students.length;
    showPreviewDialog(students, errors);
  }

  // ════════════════════════════════════════════════════════════════
  // MAP + VALIDATE  (core logic unchanged)
  // ════════════════════════════════════════════════════════════════
  dynamic _findValue(Map<String, dynamic> row, List<String> synonyms) {
    for (final entry in row.entries) {
      final cleanKey = entry.key
          .replaceAll('\uFEFF', '') // Strip BOM
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '');
      
      for (final syn in synonyms) {
        final cleanSyn = syn.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        if (cleanKey == cleanSyn) {
          return entry.value;
        }
      }
    }
    return null;
  }

  String? normalizeClassId(String? className, String? division) {
    if (className == null || className.trim().isEmpty) return null;
    
    String cleanClass = className.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '').replaceAll('-', '');
    String cleanDiv = division?.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '').replaceAll('-', '') ?? '';
    
    // If division is provided in cleanDiv, and cleanClass ends with cleanDiv, strip it from cleanClass
    if (cleanDiv.isNotEmpty && cleanClass.endsWith(cleanDiv)) {
      cleanClass = cleanClass.substring(0, cleanClass.length - cleanDiv.length);
    }
    
    // If division is empty, but cleanClass ends with a letter (e.g. "12A", "XIIA")
    if (cleanDiv.isEmpty && cleanClass.length > 1) {
      final lastChar = cleanClass.substring(cleanClass.length - 1);
      if (RegExp(r'[A-Z]').hasMatch(lastChar)) {
        cleanDiv = lastChar;
        cleanClass = cleanClass.substring(0, cleanClass.length - 1);
      }
    }
    
    if (cleanDiv.isEmpty) {
      return cleanClass;
    }
    return '$cleanClass-$cleanDiv';
  }

  Map<String, dynamic>? mapStudent(Map<String, dynamic> row, List<String> errors) {
    final grVal = _findValue(row, ['GR.No', 'GR. No', 'GR No.', 'GRNo', 'grNumber', 'gr_no', 'gr']);
    final gr = grVal?.toString().trim();
    
    final nameVal = _findValue(row, ['Name of student', 'Name', 'Student Name', 'student_name']);
    final name = nameVal?.toString().trim();
    
    final phoneVal = _findValue(row, ['Contact No', 'Contact', 'Phone', 'Phone Number', 'contact_no']);
    final phone = phoneVal?.toString().trim();
    
    final aadhaarVal = _findValue(row, ['Aadhaar No', 'Aadhaar', 'Aadhar No', 'Aadhar', 'aadhaar_no']);
    String? aadhaar = aadhaarVal?.toString().trim().replaceAll(RegExp(r'\D'), '');

    if (gr == null || gr.isEmpty) {
      errors.add("Missing GR");
      return null;
    }
    if (!RegExp(r'^\d{1,10}$').hasMatch(gr)) {
      errors.add("Invalid GR: $gr (Must be 1 to 10 digits)");
      return null;
    }
    if (name == null || name.isEmpty) {
      errors.add("Missing Name (GR: $gr)");
      return null;
    }
    if (phone != null && phone.isNotEmpty && !RegExp(r'^\d{10}$').hasMatch(phone)) {
      errors.add("Invalid Phone (GR: $gr)");
      return null;
    }
    if (aadhaar != null && aadhaar.isNotEmpty && !RegExp(r'^\d{12}$').hasMatch(aadhaar)) {
      errors.add("Invalid Aadhaar (GR: $gr)");
      return null;
    }

    final dobVal = _findValue(row, ['Date of Birth', 'DOB', 'Birth Date', 'date_of_birth']);
    final dob = parseDate(dobVal);
    
    final classNameVal = _findValue(row, ['Class', 'className']);
    final className = classNameVal?.toString().trim();
    
    final divisionVal = _findValue(row, ['Division', 'div']);
    final division = divisionVal?.toString().trim();
    
    final classId = normalizeClassId(className, division);

    final addressVal = _findValue(row, ['Address (Pada, Vilage)', 'Address (Pada Vilage)', 'Address', 'address', 'Address (Pada Vilage)']);
    final genderVal = _findValue(row, ['Gender (Male/Female)', 'Gender']);
    final rollNoVal = _findValue(row, ['Roll.No', 'Roll No', 'Roll No.', 'RollNo', 'roll_no']);

    return {
      'grNumber':      gr,
      'name':          name,
      'phone':         (phone == null || phone.isEmpty) ? null : phone,
      'aadhaarNumber': (aadhaar == null || aadhaar.isEmpty) ? null : aadhaar,
      'address':       addressVal?.toString().trim(),
      'gender':        genderVal?.toString().trim().toLowerCase(),
      'dob':           dob,
      'rollNo':        rollNoVal?.toString().isEmpty ?? true ? null : int.tryParse(rollNoVal.toString().trim()),
      'classId':       classId,
      'createdAt':     FieldValue.serverTimestamp(),
    };
  }

  String? parseDate(dynamic input) {
    if (input == null) return null;

    final value = input.toString().trim();

    if (value.isEmpty) return null;

    try {
      /// 🔥 CASE 1: Excel serial number (e.g. 45123)
      if (RegExp(r'^\d+$').hasMatch(value)) {
        final days = int.parse(value);

        // Excel epoch: 1899-12-30
        final date = DateTime(1899, 12, 30).add(Duration(days: days));

        return date.toIso8601String();
      }

      /// 🔥 CASE 2: DD/MM/YYYY
      if (value.contains('/')) {
        final p = value.split('/');
        if (p.length == 3) {
          return DateTime(
            int.parse(p[2]),
            int.parse(p[1]),
            int.parse(p[0]),
          ).toIso8601String();
        }
      }

      /// 🔥 CASE 3: ISO or other formats
      return DateTime.parse(value).toIso8601String();

    } catch (_) {
      return null;
    }
  }

  // ════════════════════════════════════════════════════════════════
  // DUPLICATES  (core logic unchanged)
  // ════════════════════════════════════════════════════════════════
  Future<List<String>> findDuplicates(List<Map<String, dynamic>> students) async {
    List<String> duplicates = [];
    for (var s in students) {
      final doc = await _firestore.collection('students').doc(s['grNumber']).get();
      if (doc.exists) duplicates.add(s['grNumber']);
    }
    return duplicates;
  }

  // ════════════════════════════════════════════════════════════════
  // REASSIGN INPUT  (core logic unchanged)
  // ════════════════════════════════════════════════════════════════
  Future<String?> askNewGr(String oldGr) async {
    final c = TextEditingController();
    return await showDialog<String>(
      context: context,
      builder: (_) => _StyledDialog(
        title: "Reassign GR",
        icon: Icons.edit_rounded,
        actions: [
          _DBtn(label: "Skip", onTap: () => Navigator.pop(context, null)),
          _DBtn(label: "OK",   primary: true, onTap: () => Navigator.pop(context, c.text.trim())),
        ],
        children: [
          Text("Old GR: $oldGr",
              style: TextStyle(fontSize: 13, color: AppTheme.textDark.withOpacity(0.6))),
          const SizedBox(height: 12),
          TextField(
            controller: c,
            style: TextStyle(color: AppTheme.textDark),
            decoration: InputDecoration(
              hintText: "New GR number",
              filled: true,
              fillColor: AppTheme.secondary.withOpacity(0.5),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppTheme.primary.withOpacity(0.2))),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // BATCH IMPORT  (core logic unchanged)
  // ════════════════════════════════════════════════════════════════
  Future<void> startImport(
      List<Map<String, dynamic>> students,
      DuplicateAction action,
      List<String> initialErrors,
      ) async {
    setState(() { loading = true; progress = 0; });

    int success = 0, skipped = 0;
    List<String> errors = [...initialErrors];

    final existingSnapshot = await _firestore.collection('students').get();
    final existingGRs = existingSnapshot.docs.map((e) => e.id).toSet();

    // Fetch existing classes and build a case/space/hyphen-insensitive canonical mapping
    final classesSnapshot = await _firestore.collection('classes').get();
    final Map<String, String> existingClassesMap = {};
    for (var doc in classesSnapshot.docs) {
      final docId = doc.id;
      final canonical = docId.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
      existingClassesMap[canonical] = docId;
    }

    const chunkSize = 50;
    for (int i = 0; i < students.length; i += chunkSize) {
      final chunk = students.skip(i).take(chunkSize);
      WriteBatch batch = _firestore.batch();

      for (var student in chunk) {
        // Auto-create class if it doesn't exist
        final classId = student['classId'];
        if (classId != null && classId.toString().isNotEmpty) {
          final normalized = classId.toString().trim();
          final canonical = normalized.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

          String targetClassDocId;
          if (existingClassesMap.containsKey(canonical)) {
            targetClassDocId = existingClassesMap[canonical]!;
          } else {
            targetClassDocId = normalized; // e.g. "12-A"
            await _firestore.collection('classes').doc(targetClassDocId).set({
              'name': targetClassDocId,
              'totalStudents': 0,
              'boys': 0,
              'girls': 0,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            existingClassesMap[canonical] = targetClassDocId;
          }
          student['classId'] = targetClassDocId;
        }

        final gr     = student['grNumber'];
        final docRef = _firestore.collection('students').doc(gr);
        final exists = existingGRs.contains(gr);

        if (exists) {
          if (action == DuplicateAction.skip)      { skipped++; errors.add("Skipped duplicate GR: $gr"); continue; }
          if (action == DuplicateAction.overwrite) { batch.set(docRef, student); success++; continue; }
          if (action == DuplicateAction.reassign) {
            final newGr = await askNewGr(gr);
            if (newGr == null || newGr.isEmpty) { skipped++; errors.add("Skipped GR: $gr"); continue; }
            if (existingGRs.contains(newGr))    { errors.add("New GR exists: $newGr"); skipped++; continue; }
            final oldDoc = existingSnapshot.docs.firstWhere((d) => d.id == gr);
            batch.set(_firestore.collection('students').doc(newGr), {...oldDoc.data(), 'grNumber': newGr});
            batch.set(docRef, student);
            existingGRs.add(newGr);
            success++;
          }
        } else {
          batch.set(docRef, student);
          success++;
        }
        progress++;
      }

      await batch.commit();
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 50));
    }

    // Recalculate and update student counts for all classes in database to ensure accuracy
    try {
      final updatedStudentsSnapshot = await _firestore.collection('students').get();
      final Map<String, Map<String, int>> classCounts = {};
      for (var doc in updatedStudentsSnapshot.docs) {
        final data = doc.data();
        final cId = data['classId']?.toString();
        if (cId == null || cId.isEmpty) continue;
        final gender = data['gender']?.toString().toLowerCase() ?? '';
        
        classCounts.putIfAbsent(cId, () => {'total': 0, 'boys': 0, 'girls': 0});
        classCounts[cId]!['total'] = (classCounts[cId]!['total'] ?? 0) + 1;
        if (gender == 'male' || gender == 'boy' || gender == 'm') {
          classCounts[cId]!['boys'] = (classCounts[cId]!['boys'] ?? 0) + 1;
        } else if (gender == 'female' || gender == 'girl' || gender == 'f') {
          classCounts[cId]!['girls'] = (classCounts[cId]!['girls'] ?? 0) + 1;
        } else {
          classCounts[cId]!['boys'] = (classCounts[cId]!['boys'] ?? 0) + 1;
        }
      }

      for (var entry in classCounts.entries) {
        final cId = entry.key;
        final counts = entry.value;
        await _firestore.collection('classes').doc(cId).update({
          'totalStudents': counts['total'],
          'boys': counts['boys'],
          'girls': counts['girls'],
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      errors.add("Error updating class counts: $e");
    }

    setState(() {
      loading        = false;
      _uploadDone    = true;        // ← show success banner
      _uploadSuccess = success;
      _uploadSkipped = skipped;
    });

    showSummary(success, skipped, errors);
  }

  // ════════════════════════════════════════════════════════════════
  // DIALOGS  (same logic, themed shell)
  // ════════════════════════════════════════════════════════════════
  void showPreviewDialog(List<Map<String, dynamic>> students, List<String> errors) {
    showDialog(
      context: context,
      builder: (_) => _StyledDialog(
        title: "Preview Import",
        icon: Icons.preview_rounded,
        actions: [
          _DBtn(
            label: "Continue",
            primary: true,
            onTap: () async {
              Navigator.pop(context);
              final duplicates = await findDuplicates(students);
              if (duplicates.isEmpty) {
                startImport(students, DuplicateAction.overwrite, errors);
              } else {
                showDuplicateDialog(students, duplicates, errors);
              }
            },
          ),
        ],
        children: [
          Row(children: [
            _Badge(label: "Valid",  value: "${students.length}", ok: true),
            const SizedBox(width: 10),
            _Badge(label: "Errors", value: "${errors.length}",   ok: false),
          ]),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.separated(
              itemCount: students.length > 6 ? 6 : students.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: AppTheme.primary.withOpacity(0.1)),
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(students[i]['grNumber'],
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(students[i]['name'],
                      style: TextStyle(fontSize: 13, color: AppTheme.textDark))),
                ]),
              ),
            ),
          ),
          if (students.length > 6)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text("+${students.length - 6} more…",
                  style: TextStyle(fontSize: 12, color: AppTheme.textDark.withOpacity(0.4))),
            ),
        ],
      ),
    );
  }

  void showDuplicateDialog(
      List<Map<String, dynamic>> students,
      List<String> duplicates,
      List<String> errors,
      ) {
    showDialog(
      context: context,
      builder: (_) => _StyledDialog(
        title: "Duplicates Found",
        icon: Icons.warning_amber_rounded,
        actions: [
          _DBtn(label: "Skip",      onTap: () { Navigator.pop(context); startImport(students, DuplicateAction.skip,      errors); }),
          _DBtn(label: "Reassign",  onTap: () { Navigator.pop(context); startImport(students, DuplicateAction.reassign,  errors); }),
          _DBtn(label: "Overwrite", primary: true, onTap: () { Navigator.pop(context); startImport(students, DuplicateAction.overwrite, errors); }),
        ],
        children: [
          _Badge(label: "Duplicates", value: "${duplicates.length}", ok: false),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.builder(
              itemCount: duplicates.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                  ),
                  child: Text(duplicates[i],
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppTheme.secondary.withOpacity(0.5),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
            ),
            child: Text("How to handle these duplicate GR numbers?",
                style: TextStyle(fontSize: 12, color: AppTheme.textDark.withOpacity(0.65))),
          ),
        ],
      ),
    );
  }

  void showSummary(int success, int skipped, List<String> errors) {
    showDialog(
      context: context,
      builder: (_) => _StyledDialog(
        title: "Import Complete",
        icon: Icons.check_circle_rounded,
        actions: [
          _DBtn(label: "Done", primary: true, onTap: () => Navigator.pop(context)),
        ],
        children: [
          Row(children: [
            _Badge(label: "Imported", value: "$success", ok: true),
            const SizedBox(width: 10),
            _Badge(label: "Skipped",  value: "$skipped", ok: false),
          ]),
          const SizedBox(height: 14),
          if (errors.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: errors.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.error_outline_rounded, size: 13, color: Colors.red.withOpacity(0.7)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(errors[i],
                        style: TextStyle(fontSize: 12, color: AppTheme.textDark.withOpacity(0.65)))),
                  ]),
                ),
              ),
            )
          else
            Expanded(
              child: Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.check_circle_outline_rounded, size: 44,
                      color: AppTheme.primary.withOpacity(0.4)),
                  const SizedBox(height: 8),
                  Text("All students imported successfully!",
                      style: TextStyle(color: AppTheme.textDark.withOpacity(0.55), fontSize: 13)),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.bgDecoration,
        child: SafeArea(
          child: Column(children: [
            WarliAppBar(title: "Import Students"),
            Expanded(child: loading ? _buildLoading() : _buildIdle()),
          ]),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    final pct = total > 0 ? progress / total : 0.0;
    return Center(
      child: Container(
        margin: const EdgeInsets.all(30),
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: AppTheme.cardBg.withOpacity(0.88),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2.5),
          const SizedBox(height: 18),
          Text("Importing Students…",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
          const SizedBox(height: 4),
          Text("$progress of $total records",
              style: TextStyle(fontSize: 12, color: AppTheme.textDark.withOpacity(0.5))),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct, minHeight: 5,
              backgroundColor: AppTheme.primary.withOpacity(0.1),
              color: AppTheme.primary,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildIdle() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header ────────────────────────────────────────────────
        WarliBanner(
          icon: Icons.upload_file_rounded,
          title: "Bulk Import via CSV/Excel File",
          subtitle: "Upload a CSV/Excel File to register multiple students",
        ),

        const SizedBox(height: 20),

        // ── Upload success banner ─────────────────────────────────
        if (_uploadDone) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.35)),
            ),
            child: Row(children: [
              Icon(Icons.check_circle_rounded, color: Colors.green[600], size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("File uploaded successfully!",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.green[700])),
                  const SizedBox(height: 2),
                  Text("$_uploadSuccess students imported  •  $_uploadSkipped skipped",
                      style: TextStyle(fontSize: 12, color: Colors.green[600])),
                ]),
              ),
              GestureDetector(
                onTap: () => setState(() => _uploadDone = false),
                child: Icon(Icons.close_rounded, size: 16, color: Colors.green[400]),
              ),
            ]),
          ),
          const SizedBox(height: 16),
        ],

        // ── Required columns card ─────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBg.withOpacity(0.78),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 13, 16, 9),
              child: Text("REQUIRED COLUMNS",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      letterSpacing: 1.2, color: AppTheme.primary.withOpacity(0.55))),
            ),
            Divider(height: 1, color: AppTheme.primary.withOpacity(0.1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(children: const [
                _CsvRow(label: "Roll.No",                desc: "Roll number"),
                _CsvRow(label: "Class",                  desc: "Class number e.g. 10"),
                _CsvRow(label: "Division",               desc: "Division e.g. A"),
                _CsvRow(label: "GR.No",                  desc: "Unique GR number"),
                _CsvRow(label: "Name of student",        desc: "Full name"),
                _CsvRow(label: "Gender (Male/Female)",   desc: "Male or Female"),
                _CsvRow(label: "Date of Birth",          desc: "DD/MM/YYYY"),
                _CsvRow(label: "Address (Pada, Vilage)", desc: "Student address"),
                _CsvRow(label: "Aadhaar No",              desc: "12-digit Aadhaar"),
                _CsvRow(label: "Contact No",             desc: "10-digit phone"),
              ]),
            ),
          ]),
        ),

        const SizedBox(height: 14),

        // ── Info note ─────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppTheme.secondary.withOpacity(0.55),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline_rounded, color: AppTheme.primary.withOpacity(0.55), size: 17),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                "Header row must match column names exactly. Entries with Invalid rows will be skipped. The file should have one sheet only.",
                style: TextStyle(fontSize: 12, color: AppTheme.textDark.withOpacity(0.65), height: 1.4),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 14),

        // ── Download sample CSV ───────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: downloadSampleCsv,
            icon: Icon(Icons.download_rounded, size: 18, color: AppTheme.primary),
            label: Text("Download Sample CSV",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primary)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              side: BorderSide(color: AppTheme.primary.withOpacity(0.4), width: 1.2),
              backgroundColor: AppTheme.primary.withOpacity(0.06),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ── Upload CSV ────────────────────────────────────────────
        WarliButton(label: "Choose CSV/Excel File", onPressed: pickFile),

        const SizedBox(height: 12),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// STYLED DIALOG SHELL
// ══════════════════════════════════════════════════════════════════
class _StyledDialog extends StatelessWidget {
  final String       title;
  final IconData     icon;
  final List<Widget> children;
  final List<_DBtn>  actions;

  const _StyledDialog({
    required this.title,
    required this.icon,
    required this.children,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: AppTheme.cardBg,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 520),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.8),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(children: [
              Icon(icon, color: AppTheme.textDark.withOpacity(0.9), size: 20),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
            ]),
          ),
          // Body
          Flexible(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
            ),
          ),
          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: actions
                  .map((b) => Padding(padding: const EdgeInsets.only(left: 8), child: b))
                  .toList(),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Dialog button ──────────────────────────────────────────────────
class _DBtn extends StatelessWidget {
  final String       label;
  final bool         primary;
  final VoidCallback onTap;
  const _DBtn({required this.label, required this.onTap, this.primary = false});

  @override
  Widget build(BuildContext context) {
    if (primary) {
      return ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: AppTheme.textDark,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      );
    }
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.textDark,
        side: BorderSide(color: AppTheme.primary.withOpacity(0.25)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }
}

// ── Badge chip ─────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label, value;
  final bool   ok;
  const _Badge({required this.label, required this.value, required this.ok});

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppTheme.primary : Colors.red[600]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: color.withOpacity(0.75))),
      ]),
    );
  }
}

// ── CSV row ────────────────────────────────────────────────────────
class _CsvRow extends StatelessWidget {
  final String label, desc;
  const _CsvRow({required this.label, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 5, height: 5,
          margin: const EdgeInsets.only(top: 5, right: 9),
          decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.5), shape: BoxShape.circle),
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 12.5, color: AppTheme.textDark),
              children: [
                TextSpan(text: label, style: const TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: "  —  $desc",
                    style: TextStyle(color: AppTheme.textDark.withOpacity(0.5))),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}