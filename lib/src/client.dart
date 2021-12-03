import 'package:vm_service/vm_service.dart';

import 'internal.dart';
import 'render_object_info.dart';

Future<RenderObjectInfo> getRenderObjectInfoTree(
  VmService vmService, {
  String? isolateId,
}) async {
  if (isolateId == null) {
    final vm = await vmService.getVM();
    isolateId = vm.isolates!.first.id;
  }

  final result = await vmService.callServiceExtension(
    getRenderObjectInfoTreeKey,
    isolateId: isolateId,
  );

  return RenderObjectInfo.fromJson(result.json!);
}

const _getRenderObjectInfoTree = getRenderObjectInfoTree;

extension FlutterExplodedClientExtension on VmService {
  Future<RenderObjectInfo> getRenderObjectInfoTree({String? isolateId}) =>
      _getRenderObjectInfoTree(this, isolateId: isolateId);
}
