import 'package:vm_service/vm_service.dart';

import 'render_object_info.dart';
import 'service_extension.dart';

Future<RenderObjectInfo?> getRenderObjectInfoTree(
  VmService vmService, {
  String? isolateId,
}) async {
  if (isolateId == null) {
    final vm = await vmService.getVM();
    isolateId = vm.isolates!.first.id;
  }

  try {
    final result = await vmService.callServiceExtension(
      getRenderObjectInfoTreeMethod,
      isolateId: isolateId,
    );
    final json = result.json;

    if (json == null || json.isEmpty) {
      // Null is returned if no element has been marked for visualization.
      return null;
    }

    return RenderObjectInfo.fromJson(json);
  } on RPCError catch (e) {
    // The service extension probably has not been registered yet, because the
    // ExplodedTreeMarker has not yet been added to the widget tree.
    // The ExplodedTreeMarker ensures that the service extension is registered.
    if (e.code == RPCError.kMethodNotFound) {
      return null;
    }
    rethrow;
  }
}

const _getRenderObjectInfoTree = getRenderObjectInfoTree;

extension FlutterExplodedClientExtension on VmService {
  Future<RenderObjectInfo?> getRenderObjectInfoTree({String? isolateId}) =>
      _getRenderObjectInfoTree(this, isolateId: isolateId);
}
