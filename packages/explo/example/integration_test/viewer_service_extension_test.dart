import 'dart:convert';
import 'dart:developer';
import 'dart:isolate';

import 'package:explo/src/viewer_service_extensions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart' as vm;
import 'package:vm_service/vm_service_io.dart';

late final String isolateId;
late final vm.VmService vmService;

void main() {
  setUpAll(() async {
    isolateId = Service.getIsolateID(Isolate.current)!;

    final serviceInfo = await Service.getInfo();
    vmService =
        await vmServiceConnectUri(serviceInfo.serverWebSocketUri!.toString());

    ensureViewerServiceExtensionsAreRegistered();
  });

  setUp(resetViewerServiceExtension);

  test('add target app', () async {
    final targetApp = TargetApp(
      id: 'a',
      label: 'b',
      vmServiceUri: Uri.parse('ws://localhost:1234'),
    );

    addTargetAppsListener(expectAsync0(() {
      expect(targetApps, [targetApp]);
    }));

    await addTargetApp(targetApp);
  });

  test('remove target app', () async {
    final targetApp = TargetApp(
      id: 'a',
      label: 'b',
      vmServiceUri: Uri.parse('ws://localhost:1234'),
    );

    await addTargetApp(targetApp);

    addTargetAppsListener(expectAsync0(() {
      expect(targetApps, isEmpty);
    }));

    await removeTargetApp(targetApp);
  });
}

Future<void> addTargetApp(TargetApp app) {
  return vmService.callServiceExtension(
    addTargetAppMethod,
    isolateId: isolateId,
    args: <String, Object?>{
      'app': jsonEncode(app.toJson()),
    },
  );
}

Future<void> removeTargetApp(TargetApp app) {
  return vmService.callServiceExtension(
    removeTargetAppMethod,
    isolateId: isolateId,
    args: <String, Object?>{
      'id': app.id,
    },
  );
}
