import 'package:flutter/material.dart';
import 'package:attendance_system/services/mongodb_service.dart';
import 'admin_dashboard.dart';

class ViewRecordsPage extends StatefulWidget {
  /// Optionally pre-select the main toggle: 'users' or 'classes'
  final String? initialMainType;
  /// Optionally pre-select the user sub-filter: 'students' | 'teacher' | 'principal' | 'watchman'
  final String? initialType;

  const ViewRecordsPage({super.key, this.initialMainType, this.initialType});

  @override
  State<ViewRecordsPage> createState() => _ViewRecordsPageState();
}

class _ViewRecordsPageState extends State<ViewRecordsPage> {
  late String mainType;
  late String selectedType;

  // ── Search ──────────────────────────────────────────────────────────────
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  final List<String> userTypes = ['students', 'teacher', 'principal', 'watchman'];
  final Map<String, Map<String, dynamic>> _typeInfo = {
    'students':  {'icon': Icons.people_rounded,   'label': 'Students'},
    'teacher':   {'icon': Icons.person_rounded,   'label': 'Teachers'},
    'principal': {'icon': Icons.school_rounded,   'label': 'Principals'},
    'watchman':  {'icon': Icons.security_rounded, 'label': 'Watchmen'},
  };

  @override
  void initState() {
    super.initState();
    mainType     = widget.initialMainType ?? 'users';
    selectedType = widget.initialType    ?? 'students';
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String get collectionName => selectedType == 'students' ? 'students' : 'users';
  bool isMatchingRole(Map<String, dynamic> data) =>
      selectedType == 'students' ? true : data['role'] == selectedType;

  String formatKey(String key) => key[0].toUpperCase() + key.substring(1);
  String formatValue(dynamic value) {
    if (value is Timestamp) return value.toDate().toString().split('.')[0];
    return value?.toString() ?? 'N/A';
  }

  // ─── Edit dialog ───────────────────────────────────────────────────────────
  Future<void> _showEditDialog(String docId, Map<String, dynamic> data) async {
    final nameCtrl    = TextEditingController(text: data['name']    ?? '');
    final emailCtrl   = TextEditingController(text: data['email']   ?? '');
    final phoneCtrl   = TextEditingController(text: data['phone']   ?? '');
    final addressCtrl = TextEditingController(text: data['address'] ?? '');
    final rollCtrl    = TextEditingController(text: data['roll']?.toString() ?? '');
    String selectedClass  = data['classId'] ?? '';
    String selectedGender = data['gender']  ?? 'male';
    DateTime? selectedDob;

    if (data['dob'] is Timestamp) selectedDob = (data['dob'] as Timestamp).toDate();
    else if (data['dob'] is String) selectedDob = DateTime.tryParse(data['dob']);

    final bool isStudent = selectedType == 'students';
    final bool isTeacher = data['role'] == 'teacher';

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(
            isStudent ? "Edit Student" : "Edit ${data['role']?.toString().capitalize() ?? 'User'}",
            style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Column(children: [
              // Name — always shown
              _dialogField(controller: nameCtrl, label: "Name", icon: Icons.person_rounded),
              const SizedBox(height: 10),

              // Phone — always shown (students + staff)
              _dialogField(controller: phoneCtrl, label: "Phone", icon: Icons.phone_rounded, keyboard: TextInputType.phone),
              const SizedBox(height: 10),

              // ── Student-specific fields ──────────────────────
              if (isStudent) ...[
                _dialogField(controller: rollCtrl, label: "Roll No", icon: Icons.format_list_numbered_rounded, keyboard: TextInputType.number),
                const SizedBox(height: 10),
                // Class picker
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('classes').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox();
                    return DropdownButtonFormField<String>(
                      value: selectedClass.isEmpty ? null : selectedClass,
                      hint: const Text("Select Class"),
                      decoration: InputDecoration(
                        labelText: "Class",
                        prefixIcon: const Icon(Icons.school_rounded, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: snapshot.data!.docs.map((doc) =>
                          DropdownMenuItem<String>(value: doc['name'], child: Text(doc['name']))).toList(),
                      onChanged: (value) => setDialogState(() => selectedClass = value!),
                    );
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedGender,
                  decoration: InputDecoration(
                    labelText: "Gender",
                    prefixIcon: const Icon(Icons.wc_rounded, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'male',   child: Text("Male")),
                    DropdownMenuItem(value: 'female', child: Text("Female")),
                  ],
                  onChanged: (value) => setDialogState(() => selectedGender = value!),
                ),
                const SizedBox(height: 10),
                _dialogField(controller: addressCtrl, label: "Address", icon: Icons.home_rounded),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: Text(
                    selectedDob == null ? "DOB: Not set" : "DOB: ${selectedDob!.toString().split(' ')[0]}",
                    style: const TextStyle(fontSize: 13),
                  )),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDob ?? DateTime(2010),
                        firstDate: DateTime(1990),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setDialogState(() => selectedDob = picked);
                    },
                    child: Text("Pick", style: TextStyle(color: AppTheme.primary)),
                  ),
                ]),
              ],

              // ── Staff-specific fields ────────────────────────
              if (!isStudent) ...[
                _dialogField(controller: emailCtrl, label: "Email", icon: Icons.email_rounded, keyboard: TextInputType.emailAddress),
                const SizedBox(height: 10),

                // Class assignment — shown for teachers
                if (isTeacher) ...[
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('classes').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox();
                      return DropdownButtonFormField<String>(
                        value: selectedClass.isEmpty ? null : selectedClass,
                        hint: const Text("Assign Class (optional)"),
                        decoration: InputDecoration(
                          labelText: "Assigned Class",
                          prefixIcon: const Icon(Icons.class_rounded, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: [
                          const DropdownMenuItem<String>(value: '', child: Text("No Class")),
                          ...snapshot.data!.docs.map((doc) =>
                              DropdownMenuItem<String>(value: doc.id, child: Text(doc.id))),
                        ],
                        onChanged: (value) => setDialogState(() => selectedClass = value ?? ''),
                      );
                    },
                  ),
                ],
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                if (isStudent) {
                  await FirebaseFirestore.instance.collection(collectionName).doc(docId).update({
                    'name':    nameCtrl.text.trim(),
                    'roll':    int.tryParse(rollCtrl.text.trim()),
                    'classId': selectedClass,
                    'phone':   phoneCtrl.text.trim(),
                    'gender':  selectedGender,
                    'address': addressCtrl.text.trim(),
                    'dob':     selectedDob,
                  });
                } else {
                  final updateMap = <String, dynamic>{
                    'name':  nameCtrl.text.trim(),
                    'email': emailCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                  };
                  if (isTeacher) updateMap['classId'] = selectedClass;
                  await FirebaseFirestore.instance.collection(collectionName).doc(docId).update(updateMap);
                }
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Updated")));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.textDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("Update"),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Quick class-assign sheet (for teachers, from bottom sheet) ───────────
  Future<void> _showAssignClassDialog(String docId) async {
    String? picked;
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(2)),
            ),
            Text("Assign Class", style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark, fontSize: 15)),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('classes').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final classes = snapshot.data!.docs;
                return Column(children: [
                  ListTile(
                    leading: Icon(Icons.block_rounded, color: AppTheme.primary.withOpacity(0.5)),
                    title: Text("No Class", style: TextStyle(color: AppTheme.textDark)),
                    onTap: () { picked = ''; Navigator.pop(context); },
                  ),
                  ...classes.map((doc) => ListTile(
                    leading: Icon(Icons.class_rounded, color: AppTheme.primary),
                    title: Text(doc.id, style: TextStyle(color: AppTheme.textDark)),
                    onTap: () { picked = doc.id; Navigator.pop(context); },
                  )),
                ]);
              },
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
    if (picked != null && mounted) {
      await FirebaseFirestore.instance.collection('users').doc(docId).update({'classId': picked});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(picked!.isEmpty ? "Class removed" : "Class assigned: $picked"),
      ));
    }
  }

  Widget _dialogField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Future<void> deleteRecord(String docId) async {
    await FirebaseFirestore.instance.collection(collectionName).doc(docId).delete();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Deleted")));
  }

  // ─── Users / Students list ─────────────────────────────────────────────────
  Widget _buildUsers() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(collectionName).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs.where((doc) {
          final raw = doc.data();
          if (raw == null || raw is! Map<String, dynamic>) return false;
          if (!isMatchingRole(raw)) return false;
          // ── Case-insensitive name search ──
          if (_query.isNotEmpty) {
            final name = (raw['name']?.toString() ?? '').toLowerCase();
            return name.contains(_query);
          }
          return true;
        }).toList();

        if (docs.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.search_off_rounded, size: 56, color: AppTheme.primary.withOpacity(0.2)),
            const SizedBox(height: 10),
            Text(
              _query.isNotEmpty ? 'No results for "$_query"' : "No records found",
              style: TextStyle(color: AppTheme.textDark.withOpacity(0.45), fontSize: 14),
            ),
          ]));
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc  = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final name = data['name'] ?? 'No Name';
            final initials = name.toString().trim().split(' ')
                .map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();

            List<Widget> chips = [];
            for (var key in ['classId', 'phone', 'gender', 'address', 'roll', 'dob', 'email', 'role']) {
              if (data.containsKey(key) && data[key] != null && data[key].toString().isNotEmpty) {
                chips.add(_Chip(label: formatKey(key), value: formatValue(data[key])));
              }
            }

            final bool isTeacher = data['role'] == 'teacher';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppTheme.cardBg.withOpacity(0.78),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: AppTheme.primary.withOpacity(0.16)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(13),
                // Single tap opens bottom sheet for quick action
                onTap: () async {
                  final action = await _showActionSheet(context, isTeacher: isTeacher);
                  if (action == "edit")         _showEditDialog(doc.id, data);
                  if (action == "assign_class") _showAssignClassDialog(doc.id);
                  if (action == "delete") {
                    final confirm = await _showDeleteConfirm();
                    if (confirm == true) await deleteRecord(doc.id);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    CircleAvatar(
                      radius: 21,
                      backgroundColor: AppTheme.primary.withOpacity(0.1),
                      child: Text(initials, style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark)),
                      if (selectedType == 'students' && data['grNumber'] != null)
                        Text("GR: ${data['grNumber']}", style: TextStyle(color: AppTheme.textDark.withOpacity(0.45), fontSize: 11)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 5, children: chips),
                    ])),
                    Icon(Icons.more_vert_rounded, color: AppTheme.primary.withOpacity(0.35), size: 18),
                  ]),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Bottom sheet for record actions.
  Future<String?> _showActionSheet(BuildContext context, {bool isTeacher = false}) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 36, height: 4,
          margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(2)),
        ),
        ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.edit_rounded, color: AppTheme.primary, size: 18),
          ),
          title: Text("Edit Profile", style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textDark)),
          onTap: () => Navigator.pop(context, "edit"),
        ),
        if (isTeacher)
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.class_rounded, color: AppTheme.primary, size: 18),
            ),
            title: Text("Assign / Change Class", style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textDark)),
            onTap: () => Navigator.pop(context, "assign_class"),
          ),
        ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.delete_rounded, color: Colors.red, size: 18),
          ),
          title: const Text("Delete", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
          onTap: () => Navigator.pop(context, "delete"),
        ),
        const SizedBox(height: 8),
      ])),
    );
  }

  Future<bool?> _showDeleteConfirm() {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text("Delete Record"),
        content: const Text("This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  // ─── Classes list ──────────────────────────────────────────────────────────
  Widget _buildClasses() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('classes').snapshots(),
      builder: (context, classSnapshot) {
        if (!classSnapshot.hasData) return const Center(child: CircularProgressIndicator());
        final classes = classSnapshot.data!.docs.where((doc) {
          if (_query.isEmpty) return true;
          final name = ((doc.data() as Map<String, dynamic>)['name']
              ?.toString() ??
              '')
              .toLowerCase();
          return name.contains(_query);
        }).toList();
        if (classes.isEmpty) return Center(child: Text(
            _query.isNotEmpty ? 'No results for "$_query"' : "No classes",
            style: TextStyle(color: AppTheme.textDark.withOpacity(0.4))));

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: classes.length,
          itemBuilder: (context, index) {
            final classDoc  = classes[index];
            final classData = classDoc.data() as Map<String, dynamic>;
            final className = classData['name'] ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppTheme.cardBg.withOpacity(0.78),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: AppTheme.primary.withOpacity(0.16)),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Center(child: Text(
                      className.length > 4 ? className.substring(0, 4) : className,
                      style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 11),
                    )),
                  ),
                  title: Text("Class $className", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark)),
                  subtitle: Row(children: [
                    _MiniTag(label: "Total ${classData['totalStudents'] ?? 0}"),
                    const SizedBox(width: 6),
                    _MiniTag(label: "Boys ${classData['boys'] ?? 0}"),
                    const SizedBox(width: 6),
                    _MiniTag(label: "Girls ${classData['girls'] ?? 0}"),
                  ]),
                  children: [
                    Divider(height: 1, indent: 16, endIndent: 16, color: AppTheme.primary.withOpacity(0.12)),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('students')
                          .where('classId', isEqualTo: classDoc.id).snapshots(),
                      builder: (context, snap) {
                        if (!snap.hasData) return const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator());
                        final students = snap.data!.docs;
                        if (students.isEmpty) return Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text("No students", style: TextStyle(color: AppTheme.textDark.withOpacity(0.4), fontSize: 13)),
                        );
                        return Column(children: students.map((doc) {
                          final sData = doc.data() as Map<String, dynamic>;
                          final sName = sData['name'] ?? 'No Name';
                          final initials = sName.toString().trim().split(' ')
                              .map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                            leading: CircleAvatar(
                              radius: 15,
                              backgroundColor: AppTheme.primary.withOpacity(0.1),
                              child: Text(initials, style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 10)),
                            ),
                            title: Text(sName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textDark)),
                            trailing: sData['grNumber'] != null
                                ? Text("GR: ${sData['grNumber']}", style: TextStyle(color: AppTheme.textDark.withOpacity(0.4), fontSize: 11))
                                : null,
                          );
                        }).toList());
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.bgDecoration,
        child: SafeArea(
          child: Column(
            children: [
              Container(
                color: AppTheme.primary.withOpacity(0.82),
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 14),
                child: Column(children: [
                  WarliAppBar(title: "View Records"),
                  const SizedBox(height: 12),

                  // ── Main toggle ──────────────────────────────────────────
                  Row(children: [
                    Expanded(child: _Toggle(
                      label: "Users / Students",
                      selected: mainType == 'users',
                      onTap: () => setState(() {
                        mainType = 'users';
                        _searchCtrl.clear();
                        _query = '';
                      }),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _Toggle(
                      label: "Classes",
                      selected: mainType == 'classes',
                      onTap: () => setState(() {
                        mainType = 'classes';
                        _searchCtrl.clear();
                        _query = '';
                      }),
                    )),
                  ]),

                  // ── Users sub-filter chips ───────────────────────────────
                  if (mainType == 'users') ...[
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: userTypes.map((type) {
                        final isSelected = selectedType == type;
                        return GestureDetector(
                          onTap: () => setState(() {
                            selectedType = type;
                            _searchCtrl.clear();
                            _query = '';
                          }),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.secondary.withOpacity(0.3)
                                  : AppTheme.textDark.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: isSelected
                                      ? AppTheme.secondary.withOpacity(0.5)
                                      : Colors.transparent),
                            ),
                            child: Text(
                              _typeInfo[type]!['label'] as String,
                              style: const TextStyle(
                                  color: AppTheme.textDark,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12),
                            ),
                          ),
                        );
                      }).toList()),
                    ),
                  ],

                  // ── Search bar (shown for both Users AND Classes) ─────────
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
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
                      style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 13),
                      decoration: InputDecoration(
                        hintText: mainType == 'classes'
                            ? 'Search classes by name…'
                            : 'Search by name…',
                        hintStyle: const TextStyle(
                            color: Color(0xFF888888), fontSize: 12),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: Color(0xFF666666), size: 20),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Color(0xFF666666), size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                ]),
              ),
              Expanded(child: mainType == 'users' ? _buildUsers() : _buildClasses()),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Helper extension ─────────────────────────────────────────────────────────
extension StringCapitalize on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

// ─── Supporting widgets ───────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String label, value;
  const _Chip({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
      ),
      child: Text("$label: $value", style: TextStyle(color: AppTheme.textDark.withOpacity(0.7), fontSize: 11)),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  const _MiniTag({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: AppTheme.primary.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

class _Toggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Toggle({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.secondary.withOpacity(0.25) : AppTheme.textDark.withOpacity(0.1),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: selected ? AppTheme.secondary.withOpacity(0.4) : Colors.transparent),
        ),
        child: Center(child: Text(label, style: const TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.w600, fontSize: 12))),
      ),
    );
  }
}