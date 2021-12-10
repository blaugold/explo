import 'dart:async';

import 'package:vm_service/vm_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

VmService vmServiceConnectUri(Uri wsUri, {Log? log}) {
  final channel = WebSocketChannel.connect(wsUri);
  final controller = StreamController<dynamic>();
  late VmService vmService;

  channel.stream.listen(
    controller.add,
    onDone: controller.close,
    onError: (Object error, StackTrace stackTrace) => vmService.dispose(),
    cancelOnError: true,
  );

  return vmService = VmService(
    controller.stream,
    channel.sink.add,
    log: log,
    disposeHandler: channel.sink.close,
  );
}
