/// Datei-Download (nur Web): bedingter Import, ohne Web liefert
/// [downloadTextFile] `false`.
library;

export 'file_download_stub.dart' if (dart.library.js_interop) 'file_download_web.dart';
