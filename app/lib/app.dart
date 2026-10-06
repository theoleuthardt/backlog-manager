import 'package:flutter/material.dart';

/// Root widget of the desktop client; the router and providers land here.
class BacklogManagerApp extends StatelessWidget {
  const BacklogManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Backlog Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark),
      home: const Scaffold(body: Center(child: Text('Backlog Manager'))),
    );
  }
}
