// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'dart:typed_data';

/// Resize [bytes] to at most [maxDim] pixels on the longest side,
/// re-encoded as JPEG at [quality] (0.0–1.0) using the HTML Canvas API.
/// This keeps images small for the Claude vision API, avoiding rate-limit
/// errors caused by sending multi-megabyte raw camera photos.
Future<Uint8List> _resizeImage(Uint8List bytes, {int maxDim = 320, double quality = 0.4}) async {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);

  final img = html.ImageElement();
  final loadCompleter = Completer<void>();
  img.onLoad.first.then((_) => loadCompleter.complete());
  img.onError.first.then((_) => loadCompleter.complete()); // resolve even on error
  img.src = url;
  await loadCompleter.future;
  html.Url.revokeObjectUrl(url);

  final nw = img.naturalWidth ?? 0;
  final nh = img.naturalHeight ?? 0;
  if (nw == 0 || nh == 0) return bytes; // decode failed, return original

  // Compute scaled dimensions preserving aspect ratio.
  double w = nw.toDouble();
  double h = nh.toDouble();
  if (w > maxDim || h > maxDim) {
    if (w >= h) { h = (h * maxDim / w).roundToDouble(); w = maxDim.toDouble(); }
    else        { w = (w * maxDim / h).roundToDouble(); h = maxDim.toDouble(); }
  }

  final canvas = html.CanvasElement(width: w.round(), height: h.round());
  canvas.context2D.drawImageScaled(img, 0, 0, w, h);

  final resizedBlob = await canvas.toBlob('image/jpeg', quality);
  if (resizedBlob == null) return bytes;

  final reader = html.FileReader();
  final readCompleter = Completer<Uint8List>();
  reader.onLoadEnd.first.then((_) {
    final result = reader.result;
    if (result is Uint8List) {
      readCompleter.complete(result);
    } else if (result is List<int>) {
      readCompleter.complete(Uint8List.fromList(result));
    } else {
      readCompleter.complete(bytes);
    }
  });
  reader.readAsArrayBuffer(resizedBlob);
  return readCompleter.future;
}

/// Opens the device camera on web via an <input capture="environment"> element.
/// On mobile browsers this launches the rear camera directly.
/// On desktop browsers it opens a file picker (browser limitation — no native camera API).
Future<(Uint8List?, String)> captureImageFromCamera() async {
  final completer = Completer<(Uint8List?, String)>();

  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..style.display = 'none';
  // The capture attribute tells the browser to use the camera directly.
  input.setAttribute('capture', 'environment');

  html.document.body!.append(input);

  // Resolve with the selected/captured image bytes (resized before returning).
  input.onChange.listen((_) async {
    final files = input.files;
    if (files == null || files.isEmpty) {
      _cleanup(input, completer, null);
      return;
    }
    final file = files[0];
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoadEnd.first;
    final result = reader.result;
    Uint8List? bytes;
    if (result is Uint8List) {
      bytes = result;
    } else if (result is List<int>) {
      bytes = Uint8List.fromList(result);
    }
    if (bytes == null) {
      _cleanup(input, completer, null);
      return;
    }
    // Resize to max 512px / JPEG 60% — reduces a 5MB photo to ~40KB,
    // cutting Claude vision token usage by 30-50× and eliminating rate-limit errors.
    final resized = await _resizeImage(bytes);
    _cleanup(input, completer, (resized, 'image/jpeg'));
  });

  // If the user dismisses without picking (window regains focus with no file),
  // resolve after a short delay so the UI doesn't hang.
  html.window.addEventListener('focus', (_) {
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!completer.isCompleted) {
        _cleanup(input, completer, null);
      }
    });
  }, true);

  input.click();
  return completer.future;
}

void _cleanup(
  html.FileUploadInputElement input,
  Completer<(Uint8List?, String)> completer,
  (Uint8List?, String)? result,
) {
  if (input.parent != null) input.remove();
  if (!completer.isCompleted) {
    completer.complete(result ?? (null, 'image/jpeg'));
  }
}
