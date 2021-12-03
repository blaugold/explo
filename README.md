[![pub.dev](https://badgen.net/pub/v/flutter_exploded)](https://pub.dev/packages/flutter_exploded)

> ⚠️ This package is **experimental**.

This package allows you to display an exploded view of the render tree of a
Flutter app.

<img src="https://github.com/blaugold/flutter_exploded/raw/master/doc/images/flutter_explode_demo.gif">

# Getting Started

You will need to have two Flutter apps running at the same time. One will
display the exploded visualization, the other is the app you want to visualize.

## Instrument your app

The app you want to visualize must be instrumented. First add `flutter_exploded`
as a dependency:

```yaml
dependencies:
  flutter_exploded: ...
```

Then register the `flutter_exploded` service extension:

```dart
import 'package:flutter_exploded/flutter_exploded.dart';

void main() {
    WidgetsFlutterBinding.ensureInitialized();
    registerFlutterExplodedServiceExtension();
    runApp(MyApp());
}
```

The last step is to mark subtrees of the app's widget tree that you want to
visualize:

```dart
import 'package:flutter_exploded/flutter_exploded.dart';

ExplodedTreeMarker(
    child: MyInterestingAppComponent(),
);
```

## Viewer app

Again, add `flutter_exploded` as a dependency:

```yaml
dependencies:
  flutter_exploded: ...
```

And then place display the `FlutterExplodedPage` somewhere:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_exploded/flutter_exploded.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FlutterExplodedPage(),
    );
  }
}
```

When you open this page, you will be asked to enter the VM service URL of the
app you want to visualize. This URL is logged early on when an app is launched.
