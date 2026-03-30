import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

Future<Uint8List?> _readAsArrayBufferBytes(html.File file) async {
  final completer = Completer<Uint8List?>();
  final reader = html.FileReader();
  final expectedSize = file.size;

  reader.onError.listen((_) {
    if (!completer.isCompleted) completer.complete(null);
  });
  reader.onLoadEnd.listen((_) {
    if (completer.isCompleted) return;
    final result = reader.result;

    if (result is ByteBuffer) {
      final total = result.lengthInBytes;
      final length = (expectedSize > 0 && expectedSize <= total)
          ? expectedSize
          : total;
      completer.complete(Uint8List.fromList(result.asUint8List(0, length)));
      return;
    }
    if (result is Uint8List) {
      final total = result.length;
      final length = (expectedSize > 0 && expectedSize <= total)
          ? expectedSize
          : total;
      completer.complete(Uint8List.fromList(result.sublist(0, length)));
      return;
    }
    if (result is ByteData) {
      final total = result.lengthInBytes;
      final length = (expectedSize > 0 && expectedSize <= total)
          ? expectedSize
          : total;
      completer.complete(
        Uint8List.fromList(
          result.buffer.asUint8List(result.offsetInBytes, length),
        ),
      );
      return;
    }
    if (result is List<int>) {
      final total = result.length;
      final length = (expectedSize > 0 && expectedSize <= total)
          ? expectedSize
          : total;
      completer.complete(Uint8List.fromList(result.sublist(0, length)));
      return;
    }

    completer.complete(null);
  });

  reader.readAsArrayBuffer(file);
  return completer.future;
}

Future<Uint8List?> _readAsDataUrlBytes(html.File file) async {
  final completer = Completer<Uint8List?>();
  final reader = html.FileReader();

  reader.onError.listen((_) {
    if (!completer.isCompleted) completer.complete(null);
  });
  reader.onLoadEnd.listen((_) {
    if (completer.isCompleted) return;
    final result = reader.result;
    if (result == null || result is! String) {
      completer.complete(null);
      return;
    }

    final commaIndex = result.indexOf(',');
    if (commaIndex < 0 || commaIndex >= result.length - 1) {
      completer.complete(null);
      return;
    }

    try {
      final base64Part = result.substring(commaIndex + 1).trim();
      completer.complete(Uint8List.fromList(base64.decode(base64Part)));
    } catch (_) {
      completer.complete(null);
    }
  });

  reader.readAsDataUrl(file);
  return completer.future;
}

bool _looksLikeZip(Uint8List bytes) {
  if (bytes.length < 4) return false;
  return bytes[0] == 0x50 &&
      bytes[1] == 0x4B &&
      (bytes[2] == 0x03 || bytes[2] == 0x05 || bytes[2] == 0x07) &&
      (bytes[3] == 0x04 || bytes[3] == 0x06 || bytes[3] == 0x08);
}

Future<Uint8List?> _readFileBytes(html.File file) async {
  final byArrayBuffer = await _readAsArrayBufferBytes(file);
  if (byArrayBuffer != null &&
      byArrayBuffer.isNotEmpty &&
      _looksLikeZip(byArrayBuffer)) {
    return byArrayBuffer;
  }

  final byDataUrl = await _readAsDataUrlBytes(file);
  if (byDataUrl != null && byDataUrl.isNotEmpty && _looksLikeZip(byDataUrl)) {
    return byDataUrl;
  }

  return null;
}

Future<Uint8List?> pickXlsxBytesFromBrowser() async {
  final completer = Completer<Uint8List?>();
  final body = html.document.body;
  if (body == null) {
    return null;
  }

  final input = html.FileUploadInputElement()
    ..accept =
        '.xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    ..multiple = false
    ..style.display = 'none';

  body.append(input);
  var changeTriggered = false;

  void completeOnce(Uint8List? value) {
    if (!completer.isCompleted) {
      completer.complete(value);
    }
    input.remove();
  }

  input.onChange.listen((_) async {
    changeTriggered = true;
    final files = input.files;
    if (files == null || files.isEmpty) {
      completeOnce(null);
      return;
    }

    final file = files.first;
    final bytes = await _readFileBytes(file);
    if (bytes == null || bytes.isEmpty) {
      completeOnce(null);
      return;
    }
    completeOnce(bytes);
  });

  input.onError.listen((_) => completeOnce(null));
  html.window.onFocus.first.then((_) {
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      if (!completer.isCompleted && !changeTriggered) {
        completeOnce(null);
      }
    });
  });

  input.click();
  return completer.future.timeout(
    const Duration(minutes: 2),
    onTimeout: () => null,
  );
}
