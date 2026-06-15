import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';

final _controller = StreamController<Uint8List>.broadcast();

Future<void> initZenohCamera(String host, String key) async {
  final locator = 'ws://$host:7447';
  final r2k9Zenoh = js_util.getProperty(html.window, 'r2k9Zenoh');

  if (r2k9Zenoh == null) {
    throw Exception('Zenoh helper is not loaded in the browser page.');
  }

  await js_util.promiseToFuture(js_util.callMethod(r2k9Zenoh, 'connect', [locator]));

  final callback = allowInterop((String base64) {
    final bytes = base64Decode(base64);
    if (!_controller.isClosed) {
      _controller.add(bytes);
    }
  });

  js_util.setProperty(html.window, 'r2k9ZenohCallback', callback);
  await js_util.promiseToFuture(js_util.callMethod(r2k9Zenoh, 'subscribeImage', ['r2k9/camera/processed_image', 'r2k9ZenohCallback']));
}

Future<void> closeZenohCamera() async {
  final r2k9Zenoh = js_util.getProperty(html.window, 'r2k9Zenoh');
  if (r2k9Zenoh != null) {
    await js_util.promiseToFuture(js_util.callMethod(r2k9Zenoh, 'close', []));
  }
  await _controller.close();
}

Stream<Uint8List> get zenohImageStream => _controller.stream;
