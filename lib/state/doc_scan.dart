import 'dart:typed_data';

import '../logic/doc_dates.dart';
import '../models/models.dart';
import '../services/ocr.dart';

/// What a paper's photos/pages say: the whole text, the facts found in it,
/// and its last valid day — for the user to check before keeping.
class DocScan {
  const DocScan(this.text, this.fields, this.expiry, {this.pages = const []});
  final String text;

  /// What each page said, in the order given (null: not read).
  final List<String?> pages;
  final List<DocField> fields;
  final DocDate? expiry;

  bool get empty => text.trim().isEmpty;
}

/// Reads up to [max] photos or PDFs on the phone.
Future<DocScan> scanPages(TextReader reader, List<(Uint8List, String)> pages, DateTime now, {int max = 6}) async {
  final each = <String?>[];
  var read = 0;
  for (final (bytes, mime) in pages) {
    if (!readable(mime) || read >= max) {
      each.add(null);
      continue;
    }
    read++;
    final t = await reader.read(bytes, mime: mime);
    each.add(t == null ? null : t.trim());
  }
  final all = [for (final t in each) if (t != null && t.isNotEmpty) t].join('\n');
  return DocScan(all, docFieldsIn(all), docDateIn(all, now), pages: each);
}

/// [fields] added to [have], one per name: what is already there stays.
List<DocField> mergeFields(List<DocField> have, List<DocField> fields) => [
      ...have,
      for (final f in fields)
        if (!have.any((h) => h.label == f.label)) f,
    ];
