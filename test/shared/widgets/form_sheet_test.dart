import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_employees/core/theme/app_theme.dart';
import 'package:mobo_employees/shared/widgets/forms/dashed_border_box.dart';
import 'package:mobo_employees/shared/widgets/loaders/loading_widget.dart';
import 'package:mobo_employees/shared/widgets/forms/mobo_file_upload_box.dart';
import 'package:mobo_employees/shared/widgets/sheets/form_sheet_shell.dart';
import 'package:mobo_employees/shared/widgets/sheets/sheet_submit_button.dart';

Widget _host(Widget child, {EdgeInsets padding = EdgeInsets.zero}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(padding: padding),
      child: Scaffold(
        body: Align(alignment: Alignment.bottomCenter, child: child),
      ),
    ),
  );
}

Widget _shell({
  VoidCallback? onClose,
  Widget? footer,
  EdgeInsets padding = EdgeInsets.zero,
}) {
  return _host(
    FormSheetShell(
      title: 'New Allocation',
      onClose: onClose ?? () {},
      children: const [
        SizedBox(
          key: ValueKey('first-field'),
          height: 40,
          width: double.infinity,
        ),
        SizedBox(height: 10),
        SizedBox(
          key: ValueKey('last-field'),
          height: 40,
          width: double.infinity,
        ),
      ],
      footer:
          footer ??
          const SizedBox(
            key: ValueKey('footer'),
            height: 52,
            width: double.infinity,
          ),
    ),
    padding: padding,
  );
}

/// The Mobo delete icon (a bin).
final _deleteIcon = find.byWidgetPredicate(
  (w) => w is HugeIcon && identical(w.icon, HugeIcons.strokeRoundedDelete02),
);

void main() {
  group('FormSheetShell', () {
    testWidgets(
      'puts a subtle grey rule between the title and the first field',
      (tester) async {
        await tester.pumpWidget(_shell());

        final title = tester.getRect(find.text('New Allocation'));
        final rule = tester.getRect(find.byType(Divider));
        final first = tester.getRect(find.byKey(const ValueKey('first-field')));

        expect(rule.top, greaterThan(title.bottom));
        expect(first.top, greaterThan(rule.bottom));
        // Edge to edge, 1px, in the light grey.
        expect(rule.width, tester.getSize(find.byType(FormSheetShell)).width);
        expect(rule.height, 1);
        expect(
          tester.widget<Divider>(find.byType(Divider)).color,
          FormSheetShell.ruleColor(false),
        );
      },
    );

    testWidgets(
      'gives the heading 16 above and below, and the fields 16 under the rule',
      (tester) async {
        await tester.pumpWidget(_shell());

        final shell = tester.getRect(find.byType(FormSheetShell));
        final rule = tester.getRect(find.byType(Divider));
        final first = tester.getRect(find.byKey(const ValueKey('first-field')));

        // Heading band: 16 + the close button's height + 16, then the rule.
        expect(rule.top - shell.top, greaterThanOrEqualTo(32));
        expect(first.top - rule.bottom, 16);
      },
    );

    testWidgets(
      'the footer has 20 above it and 20 below, and 20 at each side',
      (tester) async {
        await tester.pumpWidget(_shell());

        final shell = tester.getRect(find.byType(FormSheetShell));
        final last = tester.getRect(find.byKey(const ValueKey('last-field')));
        final footer = tester.getRect(find.byKey(const ValueKey('footer')));

        expect(footer.top - last.bottom, FormSheetShell.footerGap);
        expect(shell.bottom - footer.bottom, FormSheetShell.footerGap);
        expect(footer.left - shell.left, FormSheetShell.inset);
        expect(shell.right - footer.right, FormSheetShell.inset);
        // ...and the fields line up with it.
        final first = tester.getRect(find.byKey(const ValueKey('first-field')));
        expect(first.left, footer.left);
        expect(first.right, footer.right);
      },
    );

    testWidgets(
      'clears the system bottom inset, so a gesture bar cannot cover the footer',
      (tester) async {
        await tester.pumpWidget(
          _shell(padding: const EdgeInsets.only(bottom: 34)),
        );

        final shell = tester.getRect(find.byType(FormSheetShell));
        final footer = tester.getRect(find.byKey(const ValueKey('footer')));
        expect(shell.bottom - footer.bottom, FormSheetShell.footerGap + 34);
      },
    );

    testWidgets('the × closes it, and is dead when onClose is null', (
      tester,
    ) async {
      var closed = 0;
      await tester.pumpWidget(_shell(onClose: () => closed++));
      await tester.tap(find.byType(InkWell));
      expect(closed, 1);

      await tester.pumpWidget(
        _host(
          const FormSheetShell(
            title: 'Saving',
            onClose: null,
            children: [],
            footer: SizedBox(height: 52),
          ),
        ),
      );
      expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull);
    });
  });

  group('FormSheetShell: busy and centred', () {
    testWidgets(
      'a locked shell ignores input, and draws nothing over the form',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          _host(
            FormSheetShell(
              title: 'Saving',
              onClose: null,
              locked: true,
              children: const [Text('Employee')],
              footer: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () => taps++,
                  child: const Text('Save'),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Save'), warnIfMissed: false);
        expect(taps, 0, reason: 'the form must ignore input while locked');
        // The form is still in view, with no loading animation on top: the
        // footer's own button is what shows progress.
        expect(find.text('Employee'), findsOneWidget);
        expect(find.byType(LoadingWidget), findsNothing);
      },
    );

    testWidgets('an unlocked shell takes input', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          FormSheetShell(
            title: 'Idle',
            onClose: null,
            children: const [SizedBox(height: 40)],
            footer: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: () => taps++,
                child: const Text('Save'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Save'));
      expect(taps, 1);
    });

    testWidgets('an idle shell has no loading animation', (tester) async {
      await tester.pumpWidget(_shell());

      expect(find.byType(LoadingWidget), findsNothing);
    });

    testWidgets('a centred popup is a Dialog no wider than 560', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => FormSheetShell(
                    centered: true,
                    title: 'Popup',
                    onClose: () {},
                    children: const [SizedBox(height: 40)],
                    footer: const SizedBox(height: 52),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final card = tester.getRect(
        find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(card.width, FormSheetShell.popupMaxWidth);
      expect(card.center.dx, closeTo(700, 1));
    });
  });

  group('SheetSubmitButton', () {
    Widget button({
      bool enabled = true,
      bool loading = false,
      String? loadingLabel,
      VoidCallback? onPressed,
    }) => _host(
      Padding(
        padding: const EdgeInsets.all(20),
        child: SheetSubmitButton(
          label: 'Submit Request',
          loadingLabel: loadingLabel,
          enabled: enabled,
          isLoading: loading,
          isDark: false,
          onPressed: onPressed ?? () {},
        ),
      ),
    );

    testWidgets('is the full width of its row, 52 tall, with 16px text', (
      tester,
    ) async {
      await tester.pumpWidget(button());

      final size = tester.getSize(find.byType(ElevatedButton));
      expect(size.height, 52);
      // 20 either side of an 800px-wide test screen.
      expect(size.width, 800 - 40);
      expect(
        tester.widget<Text>(find.text('Submit Request')).style?.fontSize,
        16,
      );
    });

    testWidgets('submits when active, and not when inactive or loading', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(button(onPressed: () => taps++));
      await tester.tap(find.byType(ElevatedButton));
      expect(taps, 1);

      await tester.pumpWidget(button(enabled: false, onPressed: () => taps++));
      await tester.tap(find.byType(ElevatedButton));
      expect(taps, 1);

      await tester.pumpWidget(
        button(
          loading: true,
          loadingLabel: 'Submitting Request...',
          onPressed: () => taps++,
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(ElevatedButton));
      expect(taps, 1);
      expect(find.text('Submitting Request...'), findsOneWidget);
      expect(find.text('Submit Request'), findsNothing);
    });
  });

  group('MoboFileUploadBox', () {
    Widget box({
      String? fileName,
      VoidCallback? onPick,
      VoidCallback? onRemove,
    }) => _host(
      Padding(
        padding: const EdgeInsets.all(20),
        child: MoboFileUploadBox(
          isDark: false,
          fileName: fileName,
          onPick: onPick ?? () {},
          onRemove: onRemove ?? () {},
        ),
      ),
    );

    testWidgets(
      'empty: a dotted box labelled Attach File, with no separate button',
      (tester) async {
        await tester.pumpWidget(box());

        expect(find.text('File'), findsOneWidget);
        expect(find.text('Attach File'), findsOneWidget);
        expect(find.byType(DashedBorderBox), findsOneWidget);
        // The old grey button and its paperclip are gone.
        expect(find.byType(ElevatedButton), findsNothing);
        expect(find.byType(OutlinedButton), findsNothing);
        expect(find.byType(TextButton), findsNothing);
        // Full width, the height of the box.
        final rect = tester.getRect(find.byType(DashedBorderBox));
        expect(rect.height, MoboFileUploadBox.height);
        expect(rect.width, 800 - 40);
      },
    );

    testWidgets('tapping the box picks a file', (tester) async {
      var picked = 0;
      await tester.pumpWidget(box(onPick: () => picked++));

      await tester.tap(find.text('Attach File'));
      expect(picked, 1);
    });

    testWidgets(
      'with a file: its name and a delete icon, instead of the dotted box',
      (tester) async {
        var removed = 0;
        await tester.pumpWidget(
          box(fileName: 'medical-certificate.pdf', onRemove: () => removed++),
        );

        expect(find.text('medical-certificate.pdf'), findsOneWidget);
        expect(find.byType(DashedBorderBox), findsNothing);
        expect(find.text('Attach File'), findsNothing);

        await tester.tap(_deleteIcon);
        expect(removed, 1);
      },
    );

    testWidgets('removing is the Mobo delete icon, not a close ×', (
      tester,
    ) async {
      await tester.pumpWidget(box(fileName: 'medical-certificate.pdf'));

      expect(_deleteIcon, findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.byTooltip('Delete attachment'), findsOneWidget);
      // Red, as a destructive action is everywhere else in Mobo.
      expect(tester.widget<HugeIcon>(_deleteIcon).color, StatusColors.red);
    });

    testWidgets('the delete icon is a comfortable tap target', (tester) async {
      await tester.pumpWidget(box(fileName: 'medical-certificate.pdf'));

      final size = tester.getSize(find.byTooltip('Delete attachment'));
      expect(size.width, greaterThanOrEqualTo(28));
      expect(size.height, greaterThanOrEqualTo(28));
    });

    testWidgets('dark mode uses the softer red', (tester) async {
      await tester.pumpWidget(
        _host(
          MoboFileUploadBox(
            isDark: true,
            fileName: 'medical-certificate.pdf',
            onPick: () {},
            onRemove: () {},
          ),
        ),
      );

      expect(
        tester.widget<HugeIcon>(_deleteIcon).color,
        StatusColors.errorIcon,
      );
    });

    testWidgets('empty, there is nothing to delete', (tester) async {
      await tester.pumpWidget(box());
      expect(_deleteIcon, findsNothing);
    });
  });
}
