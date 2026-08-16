import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siliph/app/theme/siliph_theme.dart';
import 'package:siliph/domain/models/file_item.dart';
import 'package:siliph/domain/providers.dart';
import 'package:siliph/features/ai/ai_ask_screen.dart';
import 'package:siliph/features/ai/ai_summarize_screen.dart';
import 'package:siliph/features/pages/pdf_page_numbers_screen.dart';
import 'package:siliph/features/reader/pdf_tts_screen.dart';

import 'fake_gateways.dart';

Widget _app(Widget home, {FakeFileGateway? files, FakePdfGateway? pdfs}) {
  final f = files ?? FakeFileGateway();
  final p = pdfs ?? FakePdfGateway();
  return ProviderScope(
    overrides: [
      fileGatewayProvider.overrideWithValue(f),
      pdfGatewayProvider.overrideWithValue(p),
    ],
    child: MaterialApp(theme: SiliphTheme.build(), home: home),
  );
}

void main() {
  group('New Features Screens Widget Tests', () {
    testWidgets('AiSummarizeScreen renders title and pick file CTA',
        (tester) async {
      await tester.pumpWidget(_app(const AiSummarizeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('AI Summarizer'), findsOneWidget);
      expect(find.text('Select PDF or Image document'), findsOneWidget);
      expect(find.text('Pick File'), findsOneWidget);
    });

    testWidgets('AiAskScreen renders document chat interface and input',
        (tester) async {
      await tester.pumpWidget(_app(const AiAskScreen()));
      await tester.pumpAndSettle();

      expect(find.text('AI Document Chat'), findsOneWidget);
      expect(find.text('No document selected'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('PdfPageNumbersScreen renders options after picking PDF',
        (tester) async {
      final files = FakeFileGateway();
      files.nextOpen = [
        const FileItem(uri: 'content://test/doc.pdf', displayName: 'doc.pdf')
      ];
      final pdfs = FakePdfGateway();

      await tester.pumpWidget(_app(const PdfPageNumbersScreen(), files: files, pdfs: pdfs));
      await tester.pumpAndSettle();

      expect(find.text('Add Page Numbers'), findsOneWidget);
      expect(find.text('Pick PDF'), findsOneWidget);

      await tester.tap(find.text('Pick PDF'));
      await tester.pumpAndSettle();

      expect(find.text('doc.pdf'), findsOneWidget);
      expect(find.text('Page Number Options'), findsOneWidget);
      expect(find.text('Bottom Center'), findsOneWidget);
      expect(find.text('Page X of Y'), findsOneWidget);
    });

    testWidgets('PdfTtsScreen renders speed controls and audio player buttons',
        (tester) async {
      await tester.pumpWidget(_app(const PdfTtsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('PDF Text-to-Speech'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });
  });
}
