import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Web: speichert [content] ueber einen Blob-Link als Datei.
bool downloadTextFile(String filename, String content, {String mime = 'application/json'}) {
  final blob = web.Blob([content.toJS].toJS, web.BlobPropertyBag(type: '$mime;charset=utf-8'));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename;
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
  return true;
}

bool get canDownloadFiles => true;
