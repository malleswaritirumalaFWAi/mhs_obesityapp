import 'dart:typed_data';

/// Stub for non-web platforms. Camera is handled by ImagePicker natively.
Future<(Uint8List?, String)> captureImageFromCamera() async =>
    (null, 'image/jpeg');
