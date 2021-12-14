[![pub.dev](https://badgen.net/pub/v/explo_capture)](https://pub.dev/packages/explo_capture)
[![CI](https://github.com/blaugold/explo/actions/workflows/ci.yaml/badge.svg)](https://github.com/blaugold/explo/actions/workflows/ci.yaml)

<p align="center">
    <img src="https://github.com/blaugold/explo/raw/main/docs/images/explo_logo.png" width="240px">
</p>

---

> ⚠️ This package is **experimental**.

This package allows you to capture render tree data of a Flutter app, for
visualization with [Explo].

# Installation

Add `explo_capture` as a dependency:

```shell
flutter pub add explo_capture
```

# Usage

Wrap the widget tree, whose render tree you want to capture for visualization,
in `CaptureRenderTree`:

```dart
import 'package:explo_capture/explo_capture.dart';

Widget build(context) {
  return CaptureRenderTree(
      child: MyInterestingAppComponent(),
  );
}
```

You can insert multiple `CaptureRenderTree` widgets into your app. Only the
render tree of the `CaptureRenderTree`, which has been inserted most recently
into the widget tree, will be captured.

You can leave `CaptureRenderTree` permanently in your app, since it is a no-op
in release mode and only captures the render tree when requested by a viewer.

To explore the captured render tree, go to [Explo] and follow the instructions.

[explo]: https://pub.dev/packages/explo
[explo-code]:
  https://marketplace.visualstudio.com/items?itemName=blaugold.explo-code
