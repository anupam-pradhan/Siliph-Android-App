import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inspect editing_controller.dart and document.dart', () {
    final configFile = File('.dart_tool/package_config.json');
    final json = jsonDecode(configFile.readAsStringSync());
    for (final name in ['dart_pdf_editor', 'pdf_document']) {
      final p = (json['packages'] as List).firstWhere((e) => e['name'] == name);
      final rootUri = Uri.parse(p['rootUri'] as String);
      final dir = Directory.fromUri(configFile.uri.resolveUri(rootUri));
      print('=== Package: $name ===');
      for (final file in dir.listSync(recursive: true)) {
        if (file is File && file.path.endsWith('.dart')) {
          final content = file.readAsStringSync();
          if (content.contains('class PdfDocument ') || content.contains('class PdfEditingController ')) {
            print('File: ${file.path}');
            final lines = content.split('\n');
            for (var i = 0; i < lines.length; i++) {
              if (lines[i].contains('class PdfDocument') || lines[i].contains('class PdfEditingController') || lines[i].contains('PdfDocument.') || lines[i].contains('PdfEditingController(')) {
                print('  L$i: ${lines[i]}');
              }
            }
          }
        }
      }
    }
  });
}
