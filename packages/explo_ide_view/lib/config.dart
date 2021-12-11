@JS('explo.config')
library config;

import 'package:js/js.dart';

/// The VM Service URI of the target.
///
/// This has to be set in the browser environment, before the Flutter app is
/// loaded.
///
/// ```js
/// window.explo = { config: { vmServiceUri: ... } }
/// ```
@JS()
external String get vmServiceUri;
