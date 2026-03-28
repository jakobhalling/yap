import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yap/features/overlay/overlay_controller.dart';
import 'package:yap/features/overlay/widgets/elapsed_timer.dart';
import 'package:yap/features/overlay/widgets/processing_indicator.dart';
import 'package:yap/features/overlay/widgets/profile_selector.dart';
import 'package:yap/features/overlay/widgets/transcript_view.dart';
import 'package:yap/features/overlay/widgets/waveform_animation.dart';

void main() {
  group('ElapsedTimerWidget', () {
    testWidgets('shows 0:00 for zero duration', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ElapsedTimerWidget(elapsed: Duration.zero)),
        ),
      );
      expect(find.text('0:00'), findsOneWidget);
    });

    testWidgets('formats minutes and seconds correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ElapsedTimerWidget(
              elapsed: Duration(minutes: 2, seconds: 5),
            ),
          ),
        ),
      );
      expect(find.text('2:05'), findsOneWidget);
    });
  });

  group('TranscriptView', () {
    testWidgets('shows "Listening..." when text is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TranscriptView(text: '', isStreaming: true),
          ),
        ),
      );
      expect(find.text('Listening...'), findsOneWidget);
    });

    testWidgets('shows transcript text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TranscriptView(text: 'Hello world', isStreaming: false),
          ),
        ),
      );
      expect(find.text('Hello world'), findsOneWidget);
    });
  });

  group('ProcessingIndicator', () {
    testWidgets('shows spinner when not complete', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProcessingIndicator(
              profileName: 'Structured prompt',
              streamingText: '',
              isComplete: false,
            ),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('Processing with:'), findsOneWidget);
    });

    testWidgets('hides spinner when complete', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProcessingIndicator(
              profileName: 'Test',
              streamingText: 'output',
              isComplete: true,
            ),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('Processed with:'), findsOneWidget);
      expect(find.text('output'), findsOneWidget);
    });
  });

  group('ProfileSelector', () {
    testWidgets('displays profile names', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileSelector(
              profiles: const [
                ProfileOption(slot: 1, name: 'Structured', isEmpty: false),
                ProfileOption(slot: 2, name: 'Clean', isEmpty: false),
                ProfileOption(slot: 3, name: 'Grammar', isEmpty: false),
                ProfileOption(slot: 4, name: '', isEmpty: true),
              ],
              selectedSlot: null,
            ),
          ),
        ),
      );
      expect(find.text('Structured'), findsOneWidget);
      expect(find.text('Clean'), findsOneWidget);
      expect(find.text('Grammar'), findsOneWidget);
      expect(find.text('(empty)'), findsOneWidget);
    });

    testWidgets('shows Enter and Esc hints', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileSelector(
              profiles: const [],
              selectedSlot: null,
            ),
          ),
        ),
      );
      expect(find.text('Enter'), findsOneWidget);
      expect(find.text('Paste raw'), findsOneWidget);
      expect(find.text('Esc'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });
  });

  group('WaveformAnimation', () {
    testWidgets('renders without errors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: WaveformAnimation()),
        ),
      );
      // Just verify it renders
      expect(find.byType(WaveformAnimation), findsOneWidget);
    });
  });
}
