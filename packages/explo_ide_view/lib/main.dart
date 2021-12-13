import 'package:explo/explo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'config.dart';
import 'noop_url_strategy.dart';

void main() {
  setUrlStrategy(NoopUrlStrategy());
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.from(colorScheme: const ColorScheme.light()),
      darkTheme: ThemeData.from(colorScheme: const ColorScheme.dark()),
      home: ExploView(vmServiceUri: Uri.parse(vmServiceUri)),
    );
  }
}
