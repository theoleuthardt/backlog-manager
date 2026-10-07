import 'package:backlog_manager/design/shelf_theme.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/domain/themes.dart';
import 'package:flutter/material.dart';

/// Root widget of the desktop client; the router and providers land here.
class BacklogManagerApp extends StatelessWidget {
  const BacklogManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Backlog Manager',
      debugShowCheckedModeBanner: false,
      theme: buildShelfTheme(
        ShelfTokens.forTheme(resolveTheme(defaultThemeId, const [])),
      ),
      home: const Scaffold(body: Center(child: Text('Backlog Manager'))),
    );
  }
}
