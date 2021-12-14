[![pub.dev](https://badgen.net/pub/v/explo)](https://pub.dev/packages/explo)
[![CI](https://github.com/blaugold/explo/actions/workflows/ci.yaml/badge.svg)](https://github.com/blaugold/explo/actions/workflows/ci.yaml)

<p align="center">
    <img src="https://github.com/blaugold/explo/raw/main/docs/images/explo_logo.png" width="240px">
</p>

---

> ⚠️ This package is **experimental**.

Explo allows you to explore the render tree of a Flutter app in 3D, through an
exploded representation.

<img src="https://github.com/blaugold/explo/raw/main/docs/images/explo_demo.gif">

# Getting Started

## Capturing the render tree

The app, whose render tree you want to capture for visualization, needs to be
instrumented with [`explo_capture`][explo_capture].

## Exploring the render tree

After you have setup your app to capture the render tree, you can explore it
either by using an IDE extension, or by embedding the `ManualConnectExploView`
into a Flutter app.

### IDE extension

This is the easiest way to explore the render tree. The extension allows you to
open a new panel, showing the render tree of any app that has been launched
through the IDE.

Currently, there is only support for VS Code, through the
[`explo-code`][explo-code] extension.

### Embedded Explo view

Add `explo` as a dependency:

```shell
flutter pub add explo
```

Then display the `ManualConnectExploView` in a Flutter app. You could for
example, create a mini app, in `explo.dart` in your `lib` folder, and add the
following code:

```dart
import 'package:flutter/material.dart';
import 'package:explo/explo.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: ManualConnectExploView(),
    );
  }
}
```

Launch both your main app and the app containing `ManualConnectExploView`. When
you open this view, you will be asked to enter the VM service URL of the app you
want to visualize. This URL is logged early on when an app is launched.

[explo_capture]: https://pub.dev/packages/explo_capture
[explo-code]:
  https://marketplace.visualstudio.com/items?itemName=blaugold.explo-code
