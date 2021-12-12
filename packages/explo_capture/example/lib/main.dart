import 'package:explo_capture/explo_capture.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const CaptureRenderTree(
      child: MaterialApp(
        title: 'My App',
        home: Scaffold(
          body: Center(child: Text('Hello Explo')),
        ),
      ),
    );
  }
}
