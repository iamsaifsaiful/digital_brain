import 'dart:io' show ZLibCodec;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Reports as PDF files. Pages are drawn with Flutter's own text engine
/// (so Bangla joins correctly) and stored as images inside the PDF.
class PdfDoc {
  PdfDoc(this.title, {this.subtitle = '', this.footer = ''});
  final String title;
  final String subtitle;
  final String footer;
  final _blocks = <_Block>[];

  // A4 at 150 dpi.
  static const w = 1240.0, h = 1754.0, margin = 80.0;
  static const _ink = Color(0xFF1A1A1A), _muted = Color(0xFF6B6B6B), _line = Color(0xFFE2E2E2), _blue = Color(0xFF2F6BEA), _navy = Color(0xFF14284B);

  void heading(String text) => _blocks.add(_Heading(text));
  void para(String text, {bool muted = false}) => _blocks.add(_Para(text, muted));

  /// Summary boxes, two per row: (label, value).
  void tiles(List<(String, String)> items) => _blocks.add(_Tiles(items));

  /// A table; [flex] sets the column widths, [right] the columns aligned right.
  void table(List<String> head, List<List<String>> rows, {List<double>? flex, Set<int> right = const {}, String empty = 'কিছু নেই।'}) =>
      _blocks.add(_Table(head, rows, flex ?? List.filled(head.length, 1), right, empty));

  static TextStyle style(double size, {FontWeight w = FontWeight.w400, Color c = _ink}) =>
      TextStyle(fontFamily: 'NotoBengali', fontFamilyFallback: const ['Roboto', 'sans-serif'], fontSize: size, fontWeight: w, color: c, height: 1.35);

  static TextPainter text(String s, TextStyle st, double maxW, {TextAlign align = TextAlign.left}) =>
      TextPainter(text: TextSpan(text: s, style: st), textDirection: TextDirection.ltr, textAlign: align)..layout(maxWidth: maxW);

  /// Lays the blocks out on pages, draws them, and returns the PDF bytes.
  Future<Uint8List> build() async {
    final pages = <List<void Function(Canvas)>>[[]];
    var y = margin;
    const bottom = h - margin - 50;
    const cw = w - 2 * margin;

    void newPage() {
      pages.add([]);
      y = margin;
    }

    void draw(void Function(Canvas) f) => pages.last.add(f);

    // Title.
    final tp = text(title, style(40, w: FontWeight.w700, c: _navy), cw);
    final y0 = y;
    draw((c) => tp.paint(c, Offset(margin, y0)));
    y += tp.height + 4;
    if (subtitle.isNotEmpty) {
      final sp = text(subtitle, style(22, c: _muted), cw);
      final y1 = y;
      draw((c) => sp.paint(c, Offset(margin, y1)));
      y += sp.height;
    }
    final y2 = y + 14;
    draw((c) => c.drawRect(Rect.fromLTWH(margin, y2, cw, 4), Paint()..color = _blue));
    y = y2 + 34;

    for (final b in _blocks) {
      switch (b) {
        case _Heading(:final t):
          final p = text(t, style(28, w: FontWeight.w700), cw);
          if (y + p.height + 60 > bottom) newPage();
          final yy = y + 10;
          draw((c) => p.paint(c, Offset(margin, yy)));
          y = yy + p.height + 12;
        case _Para(:final t, :final muted):
          final p = text(t, style(22, c: muted ? _muted : _ink), cw);
          if (y + p.height > bottom) newPage();
          final yy = y;
          draw((c) => p.paint(c, Offset(margin, yy)));
          y += p.height + 12;
        case _Tiles(:final items):
          const gap = 20.0;
          const tw = (cw - gap) / 2;
          for (var i = 0; i < items.length; i += 2) {
            final row = items.sublist(i, i + 2 > items.length ? items.length : i + 2);
            final painters = [for (final (l, v) in row) (text(l, style(19, c: _muted), tw - 40), text(v, style(30, w: FontWeight.w700), tw - 40))];
            final th = painters.fold<double>(0, (m, p) => p.$1.height + p.$2.height + 40 > m ? p.$1.height + p.$2.height + 40 : m);
            if (y + th > bottom) newPage();
            final yy = y;
            for (var j = 0; j < painters.length; j++) {
              final x = margin + j * (tw + gap);
              final (lp, vp) = painters[j];
              draw((c) {
                c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, yy, tw, th), const Radius.circular(18)), Paint()..color = const Color(0xFFF2F4F8));
                lp.paint(c, Offset(x + 20, yy + 18));
                vp.paint(c, Offset(x + 20, yy + 20 + lp.height));
              });
            }
            y += th + gap;
          }
          y += 6;
        case _Table(:final head, :final rows, :final flex, :final right, :final empty):
          final total = flex.fold<double>(0, (a, b) => a + b);
          final widths = [for (final f in flex) cw * f / total];
          List<TextPainter> cells(List<String> r, TextStyle st) => [
                for (var i = 0; i < widths.length; i++) text(i < r.length ? r[i] : '', st, widths[i] - 16, align: right.contains(i) ? TextAlign.right : TextAlign.left),
              ];
          double rowH(List<TextPainter> ps) => ps.fold<double>(0, (m, p) => p.height > m ? p.height : m) + 18;
          void drawRow(List<TextPainter> ps, {bool header = false}) {
            final rh = rowH(ps);
            final yy = y;
            draw((c) {
              if (header) c.drawRect(Rect.fromLTWH(margin, yy, cw, rh), Paint()..color = const Color(0xFFE6EEFD));
              var x = margin;
              for (var i = 0; i < ps.length; i++) {
                final p = ps[i];
                final dx = right.contains(i) ? x + widths[i] - 8 - p.width : x + 8;
                p.paint(c, Offset(dx, yy + 9));
                x += widths[i];
              }
              c.drawLine(
                  Offset(margin, yy + rh),
                  Offset(margin + cw, yy + rh),
                  Paint()
                    ..color = _line
                    ..strokeWidth = 1.5);
            });
            y += rh;
          }

          final headPs = cells(head, style(19, w: FontWeight.w700, c: _navy));
          if (y + rowH(headPs) * 2 > bottom) newPage();
          drawRow(headPs, header: true);
          if (rows.isEmpty) {
            final p = text(empty, style(20, c: _muted), cw);
            final yy = y + 8;
            draw((c) => p.paint(c, Offset(margin + 8, yy)));
            y = yy + p.height + 8;
          }
          for (final r in rows) {
            final ps = cells(r, style(19));
            if (y + rowH(ps) > bottom) {
              newPage();
              drawRow(cells(head, style(19, w: FontWeight.w700, c: _navy)), header: true);
            }
            drawRow(ps);
          }
          y += 24;
      }
    }

    final images = <(int, int, Uint8List)>[];
    for (var i = 0; i < pages.length; i++) {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec, const Rect.fromLTWH(0, 0, w, h));
      c.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFFFFFFFF));
      for (final f in pages[i]) {
        f(c);
      }
      final foot = text('$footer${footer.isEmpty ? '' : '   ·   '}পৃষ্ঠা ${_bn('${i + 1}')}/${_bn('${pages.length}')}', style(17, c: _muted), w - 2 * margin, align: TextAlign.center);
      foot.paint(c, Offset(margin, h - margin + 4));
      final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
      final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      img.dispose();
      final rgba = data!.buffer.asUint8List();
      final rgb = Uint8List(w.toInt() * h.toInt() * 3);
      for (var s = 0, d = 0; s < rgba.length; s += 4, d += 3) {
        rgb[d] = rgba[s];
        rgb[d + 1] = rgba[s + 1];
        rgb[d + 2] = rgba[s + 2];
      }
      images.add((w.toInt(), h.toInt(), Uint8List.fromList(ZLibCodec(level: 6).encode(rgb))));
    }
    return writePdf(images);
  }
}

String _bn(String s) => s.replaceAllMapped(RegExp('[0-9]'), (m) => '০১২৩৪৫৬৭৮৯'[int.parse(m[0]!)]);

/// A PDF with one full-page image per page (Flate-compressed RGB).
Uint8List writePdf(List<(int, int, Uint8List)> pages) {
  final out = BytesBuilder();
  final offsets = <int>[];
  void add(String s) => out.add(Uint8List.fromList(s.codeUnits));
  void obj(int n, String body, [Uint8List? stream]) {
    offsets.add(out.length);
    add('$n 0 obj\n$body\n');
    if (stream != null) {
      add('stream\n');
      out.add(stream);
      add('\nendstream\n');
    }
    add('endobj\n');
  }

  add('%PDF-1.4\n%âãÏÓ\n');
  final kids = [for (var i = 0; i < pages.length; i++) '${3 + i * 3} 0 R'].join(' ');
  obj(1, '<< /Type /Catalog /Pages 2 0 R >>');
  obj(2, '<< /Type /Pages /Kids [$kids] /Count ${pages.length} >>');
  for (var i = 0; i < pages.length; i++) {
    final (pw, ph, data) = pages[i];
    final n = 3 + i * 3;
    obj(n, '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595.28 841.89] /Resources << /XObject << /Im0 ${n + 2} 0 R >> >> /Contents ${n + 1} 0 R >>');
    final content = Uint8List.fromList('q 595.28 0 0 841.89 0 0 cm /Im0 Do Q'.codeUnits);
    obj(n + 1, '<< /Length ${content.length} >>', content);
    obj(n + 2, '<< /Type /XObject /Subtype /Image /Width $pw /Height $ph /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /FlateDecode /Length ${data.length} >>', data);
  }
  final xref = out.length;
  final count = offsets.length + 1;
  add('xref\n0 $count\n0000000000 65535 f \n');
  for (final o in offsets) {
    add('${o.toString().padLeft(10, '0')} 00000 n \n');
  }
  add('trailer\n<< /Size $count /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n');
  return out.toBytes();
}

sealed class _Block {}

class _Heading extends _Block {
  _Heading(this.t);
  final String t;
}

class _Para extends _Block {
  _Para(this.t, this.muted);
  final String t;
  final bool muted;
}

class _Tiles extends _Block {
  _Tiles(this.items);
  final List<(String, String)> items;
}

class _Table extends _Block {
  _Table(this.head, this.rows, this.flex, this.right, this.empty);
  final List<String> head;
  final List<List<String>> rows;
  final List<double> flex;
  final Set<int> right;
  final String empty;
}
