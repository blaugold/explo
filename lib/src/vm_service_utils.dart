import 'dart:async';

import 'package:vm_service/vm_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Future<VmService> vmServiceConnectUri(String wsUri, {Log? log}) async {
  final channel = WebSocketChannel.connect(Uri.parse(wsUri));
  final controller = StreamController<dynamic>();
  final streamClosedCompleter = Completer<void>();

  channel.stream.listen(
    controller.add,
    onDone: streamClosedCompleter.complete,
  );

  return VmService(
    controller.stream,
    (String message) => channel.sink.add(message),
    log: log,
    disposeHandler: () => channel.sink.close(),
    streamClosed: streamClosedCompleter.future,
  );
}
