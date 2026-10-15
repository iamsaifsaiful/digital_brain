package com.iamsaifsaiful.digital_brain

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import java.io.ByteArrayOutputStream

/**
 * Turns a report (title, headings, paragraphs, tables) sent from Dart into
 * an A4 PDF. Android's own text engine lays out the Bengali, so conjuncts
 * and vowel signs come out right, and the text stays selectable.
 *
 * Blocks: {t:"h1"|"h2"|"p", text}, {t:"stats", items:[[label, value, tone]]},
 * {t:"kv", rows:[[k, v]]}, {t:"table", cols, w, a, rows}, {t:"break"}.
 * A table cell is a string or {s, c ("g" green, "o" orange, "m" muted), b (bold)}.
 */
class PdfMaker(context: Context) {
    private val regular: Typeface = font(context, "NotoSansBengali-Regular.ttf", Typeface.NORMAL)
    private val bold: Typeface = font(context, "NotoSansBengali-SemiBold.ttf", Typeface.BOLD)

    private companion object {
        const val W = 595f
        const val H = 842f
        const val M = 40f
        const val TOP = 44f
        const val BOTTOM = H - 46f
        val INK = Color.rgb(0x1F, 0x29, 0x37)
        val MUTED = Color.rgb(0x6B, 0x72, 0x80)
        val GREEN = Color.rgb(0x0F, 0x7A, 0x55)
        val ORANGE = Color.rgb(0xC2, 0x41, 0x0C)
        val LINE = Color.rgb(0xE5, 0xE7, 0xEB)
        val SOFT = Color.rgb(0xF3, 0xF6, 0xF4)
        val HEAD = Color.rgb(0xE8, 0xF3, 0xEE)

        fun font(context: Context, file: String, style: Int): Typeface = try {
            val key = io.flutter.FlutterInjector.instance().flutterLoader().getLookupKeyForAsset("assets/fonts/$file")
            Typeface.createFromAsset(context.assets, key)
        } catch (e: Exception) {
            Typeface.create(Typeface.DEFAULT, style)
        }
    }

    fun make(spec: Map<*, *>): ByteArray {
        // First pass counts the pages (for "পাতা ২ / ৫"), the second draws.
        val pages = Run(spec, null, 0).go()
        val doc = PdfDocument()
        try {
            Run(spec, doc, pages).go()
            val out = ByteArrayOutputStream()
            doc.writeTo(out)
            return out.toByteArray()
        } finally {
            doc.close()
        }
    }

    private fun paint(size: Float, strong: Boolean = false, color: Int = INK) = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        typeface = if (strong) bold else regular
        textSize = size
        this.color = color
    }

    private fun layout(text: String, p: TextPaint, width: Float, align: Layout.Alignment = Layout.Alignment.ALIGN_NORMAL, spacing: Float = 1.15f): StaticLayout =
        StaticLayout.Builder.obtain(text, 0, text.length, p, width.toInt().coerceAtLeast(10))
            .setAlignment(align)
            .setLineSpacing(0f, spacing)
            .setIncludePad(false)
            .build()

    private fun tone(c: Any?): Int = when (c) {
        "g" -> GREEN
        "o" -> ORANGE
        "m" -> MUTED
        else -> INK
    }

    private fun digits(n: Int, bn: Boolean): String {
        val s = n.toString()
        if (!bn) return s
        val d = "০১২৩৪৫৬৭৮৯"
        return s.map { if (it in '0'..'9') d[it - '0'] else it }.joinToString("")
    }

    /** One pass over the blocks; draws only when [doc] is set. */
    private inner class Run(val spec: Map<*, *>, val doc: PdfDocument?, val total: Int) {
        val title = spec["title"] as? String ?: ""
        val footer = spec["footer"] as? String ?: ""
        val pageWord = spec["pageWord"] as? String ?: "Page"
        val bn = spec["bnDigits"] as? Boolean ?: true
        var page: PdfDocument.Page? = null
        var canvas: Canvas? = null
        var number = 0
        var y = TOP
        val width = W - 2 * M

        fun go(): Int {
            newPage(first = true)
            header()
            for (b in spec["blocks"] as? List<*> ?: emptyList<Any>()) {
                val m = b as? Map<*, *> ?: continue
                when (m["t"]) {
                    "h1" -> h1(m["text"] as? String ?: "")
                    "h2" -> h2(m["text"] as? String ?: "")
                    "p" -> para(m["text"] as? String ?: "", m["muted"] == true)
                    "stats" -> stats(m["items"] as? List<*> ?: emptyList<Any>())
                    "kv" -> kv(m["rows"] as? List<*> ?: emptyList<Any>())
                    "table" -> table(m)
                    "break" -> if (y > TOP + 40) newPage()
                }
            }
            finish()
            return number
        }

        fun newPage(first: Boolean = false) {
            if (!first) finish()
            number++
            y = TOP
            if (doc != null) {
                val p = doc.startPage(PdfDocument.PageInfo.Builder(W.toInt(), H.toInt(), number).create())
                page = p
                canvas = p.canvas
            }
            if (!first) {
                // A small running title on every page after the first.
                val l = layout(title, paint(8.5f, color = MUTED), width)
                draw(l, M, 22f)
                canvas?.drawLine(M, 36f, W - M, 36f, Paint().apply { color = LINE; strokeWidth = 0.7f })
            }
        }

        fun finish() {
            val c = canvas
            if (c != null && doc != null) {
                val line = Paint().apply { color = LINE; strokeWidth = 0.7f }
                c.drawLine(M, H - 34f, W - M, H - 34f, line)
                draw(layout(footer, paint(8f, color = MUTED), width * 0.7f), M, H - 28f)
                val pn = "$pageWord ${digits(number, bn)} / ${digits(total, bn)}"
                draw(layout(pn, paint(8f, color = MUTED), width * 0.3f, Layout.Alignment.ALIGN_OPPOSITE), M + width * 0.7f, H - 28f)
                doc.finishPage(page)
            }
            page = null
            canvas = null
        }

        fun draw(l: StaticLayout, x: Float, top: Float) {
            val c = canvas ?: return
            c.save()
            c.translate(x, top)
            l.draw(c)
            c.restore()
        }

        fun ensure(h: Float) {
            if (y + h > BOTTOM && y > TOP + 1) newPage()
        }

        fun header() {
            val brand = spec["brand"] as? String ?: ""
            if (brand.isNotEmpty()) {
                val b = layout(brand, paint(9.5f, true, GREEN), width)
                draw(b, M, y)
                y += b.height + 4
            }
            val t = layout(title, paint(21f, true), width)
            draw(t, M, y)
            y += t.height + 4
            val sub = spec["subtitle"] as? String ?: ""
            if (sub.isNotEmpty()) {
                val s = layout(sub, paint(10f, color = MUTED), width)
                draw(s, M, y)
                y += s.height
            }
            y += 10
            canvas?.drawRect(M, y, M + 46f, y + 3f, Paint().apply { color = GREEN })
            y += 16
        }

        fun h1(text: String) {
            val l = layout(text, paint(14.5f, true), width - 12)
            ensure(l.height + 60f) // keep a heading with the start of what follows
            y += 6
            canvas?.drawRoundRect(RectF(M, y + 1, M + 4f, y + l.height - 1), 2f, 2f, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = GREEN })
            draw(l, M + 12, y)
            y += l.height + 8
        }

        fun h2(text: String) {
            val l = layout(text, paint(11.5f, true, GREEN), width)
            ensure(l.height + 40f)
            y += 4
            draw(l, M, y)
            y += l.height + 5
        }

        /** A paragraph, split across pages line by line when it is long. */
        fun para(text: String, muted: Boolean) {
            if (text.isEmpty()) return
            val l = layout(text, paint(10f, color = if (muted) MUTED else INK), width, spacing = 1.25f)
            var line = 0
            while (line < l.lineCount) {
                ensure((l.getLineBottom(line) - l.getLineTop(line)).toFloat())
                val startTop = l.getLineTop(line)
                var end = line
                while (end + 1 < l.lineCount && y + (l.getLineBottom(end + 1) - startTop) <= BOTTOM) end++
                val c = canvas
                if (c != null) {
                    c.save()
                    c.translate(M, y - startTop)
                    c.clipRect(0f, startTop.toFloat(), width, l.getLineBottom(end).toFloat())
                    l.draw(c)
                    c.restore()
                }
                y += (l.getLineBottom(end) - startTop).toFloat()
                line = end + 1
                if (line < l.lineCount) newPage()
            }
            y += 6
        }

        /** Summary boxes in a row ("আয় ৳…", "খরচ ৳…", "ব্যালেন্স ৳…"). */
        fun stats(items: List<*>) {
            val list = items.mapNotNull { it as? List<*> }
            if (list.isEmpty()) return
            val perRow = minOf(list.size, 3)
            val gap = 8f
            val boxW = (width - gap * (perRow - 1)) / perRow
            for (row in list.chunked(perRow)) {
                val ls = row.map { r ->
                    Pair(layout("${r.getOrNull(0) ?: ""}", paint(8.5f, color = MUTED), boxW - 16), layout("${r.getOrNull(1) ?: ""}", paint(14f, true, tone(r.getOrNull(2))), boxW - 16))
                }
                val h = ls.maxOf { it.first.height + it.second.height } + 18f
                ensure(h)
                ls.forEachIndexed { i, (a, b) ->
                    val x = M + i * (boxW + gap)
                    canvas?.drawRoundRect(RectF(x, y, x + boxW, y + h), 6f, 6f, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = SOFT })
                    draw(a, x + 8, y + 8)
                    draw(b, x + 8, y + 9 + a.height)
                }
                y += h + gap
            }
            y += 2
        }

        /** Label: value lines (a person's details, a document's fields). */
        fun kv(rows: List<*>) {
            val kw = width * 0.32f
            for (r in rows) {
                val p = r as? List<*> ?: continue
                val k = layout("${p.getOrNull(0) ?: ""}", paint(9.5f, color = MUTED), kw - 8)
                val v = layout("${p.getOrNull(1) ?: ""}", paint(10f), width - kw)
                val h = maxOf(k.height, v.height).toFloat() + 6
                ensure(h)
                draw(k, M, y + 3)
                draw(v, M + kw, y + 3)
                y += h
                canvas?.drawLine(M, y, W - M, y, Paint().apply { color = LINE; strokeWidth = 0.5f })
            }
            y += 8
        }

        fun table(m: Map<*, *>) {
            val cols = (m["cols"] as? List<*>)?.map { "$it" } ?: return
            val n = cols.size
            if (n == 0) return
            val weights = (m["w"] as? List<*>)?.map { (it as? Number)?.toFloat() ?: 1f } ?: List(n) { 1f }
            val sum = weights.sum().takeIf { it > 0 } ?: 1f
            val widths = List(n) { width * (weights.getOrElse(it) { 1f } / sum) }
            val aligns = (m["a"] as? List<*>)?.map { if (it == "r") Layout.Alignment.ALIGN_OPPOSITE else if (it == "c") Layout.Alignment.ALIGN_CENTER else Layout.Alignment.ALIGN_NORMAL }
                ?: List(n) { Layout.Alignment.ALIGN_NORMAL }
            val pad = 5f

            fun rowLayouts(cells: List<Any?>, head: Boolean): List<StaticLayout> = List(n) { i ->
                val cell = cells.getOrNull(i)
                val text: String
                var color = if (head) GREEN else INK
                var strong = head
                if (cell is Map<*, *>) {
                    text = "${cell["s"] ?: ""}"
                    color = tone(cell["c"])
                    strong = strong || cell["b"] == true
                } else {
                    text = "${cell ?: ""}"
                }
                layout(text, paint(if (head) 8.8f else 9.2f, strong, color), widths[i] - 2 * pad, aligns.getOrElse(i) { Layout.Alignment.ALIGN_NORMAL })
            }

            fun drawRow(ls: List<StaticLayout>, h: Float, fill: Int?) {
                if (fill != null) canvas?.drawRect(M, y, W - M, y + h, Paint().apply { color = fill })
                var x = M
                ls.forEachIndexed { i, l ->
                    draw(l, x + pad, y + pad)
                    x += widths[i]
                }
                canvas?.drawLine(M, y + h, W - M, y + h, Paint().apply { color = LINE; strokeWidth = 0.5f })
                y += h
            }

            val head = rowLayouts(cols, true)
            val headH = head.maxOf { it.height } + 2 * pad
            ensure(headH + 24f)
            drawRow(head, headH, HEAD)
            val rows = m["rows"] as? List<*> ?: emptyList<Any>()
            rows.forEachIndexed { r, row ->
                val cells = (row as? List<*>) ?: return@forEachIndexed
                val ls = rowLayouts(cells, false)
                val h = ls.maxOf { it.height } + 2 * pad
                if (y + h > BOTTOM) {
                    newPage()
                    drawRow(head, headH, HEAD) // the column names again on the new page
                }
                drawRow(ls, h, if (r % 2 == 1) Color.rgb(0xFA, 0xFB, 0xFA) else null)
            }
            y += 10
        }
    }
}
