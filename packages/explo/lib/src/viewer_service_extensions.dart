/// This library contains service extensions, which are registered in viewer
/// apps, for integration with IDEs.
library viewer_service_extensions;

import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

/// An app which is capturing render tree data.
@immutable
class TargetApp {
  const TargetApp({
    required this.id,
    required this.label,
    required this.vmServiceUri,
  });

  factory TargetApp.fromJson(Map<String, Object?> json) => TargetApp(
        id: json['id'] as String,
        label: json['label'] as String,
        vmServiceUri: Uri.parse(json['vmServiceUri']! as String),
      );

  final String id;

  /// A label for the app, to identify it in the UI.
  final String label;

  /// The URI of the VM service of the app.
  final Uri vmServiceUri;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'label': label,
        'vmServiceUri': vmServiceUri.toString(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TargetApp &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          label == other.label &&
          vmServiceUri == other.vmServiceUri;

  @override
  int get hashCode => id.hashCode ^ label.hashCode ^ vmServiceUri.hashCode;
}

/// A list of available target apps. This list is populated by external tools,
/// such as IDEs.
List<TargetApp> get targetApps => UnmodifiableListView(_targetApps);
final _targetApps = <TargetApp>[];

final _targetAppsListeners = <VoidCallback, VoidCallback>{};

/// Adds a listener that is called when the list of [targetApps] changes.
void addTargetAppsListener(VoidCallback listener) {
  // The services extension can be called from any zone, so we need to bind
  // the listener callbacks to the current zone.
  _targetAppsListeners[listener] = Zone.current.bindCallback(listener);
}

/// Removes a listener that was added with [addTargetAppsListener].
void removeTargetAppsListener(VoidCallback listener) {
  _targetAppsListeners.remove(listener);
}

void _notifyTargetAppsListeners() {
  for (final listener in _targetAppsListeners.values.toList()) {
    listener();
  }
}

@visibleForTesting
void resetViewerServiceExtension() {
  _targetApps.clear();
  _targetAppsListeners.clear();
}

const addTargetAppMethod = 'ext.explo.addTargetApp';
const removeTargetAppMethod = 'ext.explo.removeTargetApp';

var _serviceExtensionsAreRegistered = false;

void ensureViewerServiceExtensionsAreRegistered() {
  if (_serviceExtensionsAreRegistered) {
    return;
  }
  _serviceExtensionsAreRegistered = true;

  assert(() {
    _registerViewerServiceExtensions();
    return true;
  }());
}

void _registerViewerServiceExtensions() {
  registerExtension(addTargetAppMethod, (method, args) async {
    final TargetApp app;

    try {
      app =
          TargetApp.fromJson(jsonDecode(args['app']!) as Map<String, Object?>);
    } catch (e) {
      return ServiceExtensionResponse.error(
        ServiceExtensionResponse.invalidParams,
        'Could not parse arguments: $e',
      );
    }

    _targetApps.add(app);
    _notifyTargetAppsListeners();

    return ServiceExtensionResponse.result('{}');
  });

  // removeTargetAppMethod must be registered last, because it signals that
  // all viewer service extensions have been registered.
  registerExtension(removeTargetAppMethod, (method, args) async {
    final id = args["id"];
    if (id == null) {
      return ServiceExtensionResponse.error(
        ServiceExtensionResponse.invalidParams,
        'Missing argument "id".',
      );
    }

    _targetApps.removeWhere((app) => app.id == id);
    _notifyTargetAppsListeners();

    return ServiceExtensionResponse.result('{}');
  });
}
