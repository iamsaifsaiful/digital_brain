import 'dart:typed_data';

import '../logic/doc_dates.dart';
import '../models/models.dart';
import '../services/ocr.dart';

/// What a paper's photos/pages say: the whole text, the facts found in it,
/// and its last valid day — for the user to check before keeping.
class DocScan {
  const DocScan(this.text, this.fields, this.expiry);
  final String text;
  final List<DocField> fields;
  final DocDate? expiry;

  bool get empty => text.trim().isEmpty;
}

/// Reads up to [max] photos or PDFs on the phone.
Future<DocScan> scanPages(TextReader reader, List<(Uint8List, String)> pages, DateTime now, {int max = 6}) async {
  final texts = <String>[];
  for (final (bytes, mime) in pages.where((p) => readable(p.$2)).take(max)) {
    final t = await reader.read(bytes, mime: mime);
    if (t != null && t.trim().isNotEmpty) texts.add(t.trim());
  }
  final all = texts.join('\n');
  return DocScan(all, docFieldsIn(all), docDateIn(all, now));
}

/// [fields] added to [have], one per name: what is already there stays.
List<DocField> mergeFields(List<DocField> have, List<DocField> fields) => [
      ...have,
      for (final f in fields)
        if (!have.any((h) => h.label == f.label)) f,
    ];
