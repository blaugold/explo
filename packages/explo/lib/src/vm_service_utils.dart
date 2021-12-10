import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

VmService vmServiceConnectUri(Uri uri, {Log? log}) {
  if (uri.scheme != 'ws' && uri.scheme != 'wss') {
    uri = uri.replace(scheme: 'ws');
  }

  final channel = WebSocketChannel.connect(uri);
  final controller = StreamController<dynamic>();
  late VmService vmService;

  channel.stream.listen(
    controller.add,
    onDone: controller.close,
    onError: (Object error, StackTrace stackTrace) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'explo',
        context: ErrorDescription('Failed to connect to VM service.'),
      ));
      return vmService.dispose();
    },
    cancelOnError: true,
  );

  return vmService = VmService(
    controller.stream,
    channel.sink.add,
    log: log,
    disposeHandler: channel.sink.close,
  );
}
