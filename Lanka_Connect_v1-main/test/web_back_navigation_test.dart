import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanka_connect/ui/web/web_page_scaffold.dart';
import 'package:lanka_connect/ui/web/web_shell.dart';

void _noopSelect(String _) {}

void main() {
  testWidgets('web page scaffold hides back button at root', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WebPageScaffold(
          title: 'Root',
          useScaffold: true,
          child: SizedBox.shrink(),
        ),
      ),
    );

    expect(find.byTooltip('Back'), findsNothing);
  });

  testWidgets('web page scaffold shows back button on pushed route', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const WebPageScaffold(
                        title: 'Detail',
                        useScaffold: true,
                        child: SizedBox.shrink(),
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Back'), findsOneWidget);
  });

  testWidgets('web shell shows back button only for pushed pages', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WebShell(
          appTitle: 'Lanka Connect',
          navItems: [
            WebShellNavItem(id: 'home', label: 'Home', icon: Icons.home),
          ],
          currentId: 'home',
          onSelect: _noopSelect,
          pageTitle: 'Home',
          child: SizedBox.shrink(),
        ),
      ),
    );

    expect(find.byTooltip('Back'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const WebShell(
                        appTitle: 'Lanka Connect',
                        navItems: [
                          WebShellNavItem(
                            id: 'home',
                            label: 'Home',
                            icon: Icons.home,
                          ),
                        ],
                        currentId: 'home',
                        onSelect: _noopSelect,
                        pageTitle: 'Detail',
                        child: SizedBox.shrink(),
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Back'), findsOneWidget);
  });
}
