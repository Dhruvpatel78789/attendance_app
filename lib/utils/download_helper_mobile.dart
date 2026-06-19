import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> downloadCsv(String content) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/students_import_template.csv');

  await file.writeAsString(content);

  await Share.shareXFiles(
    [XFile(file.path)],
    subject: 'Students Import Template',
    text: 'Fill in your student data and upload this CSV to the app.',
  );
}