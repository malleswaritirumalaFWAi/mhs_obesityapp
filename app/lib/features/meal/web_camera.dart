/// Conditional export: on web, uses dart:html to trigger camera capture.
/// On mobile, provides a stub (ImagePicker handles camera natively).
export 'web_camera_stub.dart'
    if (dart.library.html) 'web_camera_impl.dart';
