import 'dart:developer';
import 'dart:isolate';

import 'package:explo_capture/explo_capture.dart';
import 'package:explo_capture/internal.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vm_service/vm_service.dart' as vm;
import 'package:vm_service/vm_service_io.dart';

late final String isolateId;
late final vm.VmService vmService;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    isolateId = Service.getIsolateID(Isolate.current)!;
    final serviceInfo = await Service.getInfo();
    vmService =
        await vmServiceConnectUri(serviceInfo.serverWebSocketUri.toString());
    // Listen to extension events, so we receive render tree change events.
    await vmService.streamListen(vm.EventStreams.kExtension);
  });

  tearDownAll(() async {
    await vmService.dispose();
  });

  testWidgets(
    'ext.explo.getRenderTree returns currently captured render tree',
    (tester) async {
      // Build the widget tree, with CaptureRenderTree to register the capture
      // service extensions.
      await tester.pumpWidget(CaptureRenderTree(child: Container()));

      var renderTreeData = await getRenderTree();
      expect(renderTreeData, isNotNull);
      expect(renderTreeData!.type, 'RenderLimitedBox');

      // Rebuild without CaptureRenderTree.
      await tester.pumpWidget(Container());

      // Without a CaptureRenderTree, no render tree should be captured.
      renderTreeData = await getRenderTree();
      expect(renderTreeData, isNull);
    },
  );

  testWidgets(
    'posts ext.explo.renderTreeChanged event after each frame',
    (tester) async {
      // Build the widget tree, with CaptureRenderTree to register the capture
      // service extensions.
      await tester.pumpWidget(CaptureRenderTree(child: Container()));

      expect(
        renderTreeChanges().map((event) => event?.type),
        emitsInOrder(<Object>['RenderLimitedBox']),
      );

      // This frame wont trigger an event, because 0 listener is registered.
      await tester.pumpWidget(CaptureRenderTree(child: Container()));

      await updateRenderTreeChangeListeners(1);

      // This frame will trigger an event, because 1 listener is registered.
      await tester.pumpWidget(CaptureRenderTree(child: Container()));

      await updateRenderTreeChangeListeners(-1);

      // This frame wont trigger an event, because 0 listener is registered.
      await tester.pumpWidget(CaptureRenderTree(child: Container()));
    },
  );
}

Future<RenderObjectData?> getRenderTree() async {
  final response = await vmService.callServiceExtension(
    getRenderTreeMethod,
    isolateId: isolateId,
  );
  return renderTreeFromJson(response.json);
}

Future<void> updateRenderTreeChangeListeners(int delta) {
  return vmService.callServiceExtension(
    updateRenderTreeChangeListenersMethod,
    isolateId: isolateId,
    args: <String, dynamic>{
      'delta': delta,
    },
  );
}

Stream<RenderObjectData?> renderTreeChanges() {
  return vmService.onExtensionEvent
      .where((event) =>
          event.isolate?.id == isolateId &&
          event.extensionKind == renderTreeChangedEvent)
      .map((event) => renderTreeFromJson(event.extensionData!.data));
}
