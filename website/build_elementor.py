"""Turn index.html into one self-contained block for an Elementor HTML widget.

- every CSS rule is scoped under .ma-lp so the theme is not touched (and
  the theme's own heading/link styles are reset inside the block)
- fonts come from Google Fonts (Anek Bangla, Noto Sans Bengali)
- screenshots are embedded as WebP data URIs, the logo as inline SVG
"""
import base64, os, io, re, sys
from PIL import Image

D = os.path.dirname(os.path.abspath(__file__)) + '/'
src = open(D + 'index.html', encoding='utf-8').read()
css = src[src.index('<style>') + 7:src.index('</style>')]
body = src[src.index('<body>') + 6:src.index('</body>')]

# ---- CSS -------------------------------------------------------------
css = re.sub(r'/\*.*?\*/', '', css, flags=re.S)
css = re.sub(r'@font-face\{[^}]*\}', '', css)
css = css.replace('font-family:Anek,Noto,sans-serif', "font-family:'Anek Bangla','Noto Sans Bengali',sans-serif")
css = css.replace('font-family:Noto,sans-serif', "font-family:'Noto Sans Bengali',sans-serif")
css = css.replace(':root{', '.ma-lp{')

def scope_sel(sel):
    sel = sel.strip()
    if sel in ('html', 'body', '.ma-lp'):
        return '.ma-lp'
    if sel == '*':
        return '.ma-lp,.ma-lp *'
    return '.ma-lp ' + sel

def scope(block):
    out, i = [], 0
    while i < len(block):
        j = block.find('{', i)
        if j < 0:
            break
        head = block[i:j].strip()
        if head.startswith('@media'):
            depth, k = 1, j + 1
            while depth:
                depth += {'{': 1, '}': -1}.get(block[k], 0)
                k += 1
            out.append(head + '{' + scope(block[j + 1:k - 1]) + '}')
            i = k
        else:
            k = block.index('}', j)
            sels = ','.join(scope_sel(s) for s in head.split(','))
            out.append(sels + block[j:k + 1])
            i = k + 1
    return '\n'.join(out)

css = scope(css)
# merge duplicate .ma-lp blocks are harmless; add resets against theme styles
reset = """
.ma-lp{font-size:16px;line-height:1.5;text-align:left;overflow-x:clip}
.ma-lp h1,.ma-lp h2,.ma-lp h3{color:inherit;text-transform:none;margin:0;padding:0;border:0}
.ma-lp p{margin:0;padding:0}
.ma-lp a,.ma-lp a:hover,.ma-lp a:focus{text-decoration:none;box-shadow:none}
.ma-lp img{max-width:100%;border:0;box-shadow:none;border-radius:0}
.ma-lp ul,.ma-lp ol{margin:0;padding:0}
.ma-lp table{margin:40px 0 0;border-collapse:separate}
.ma-lp th,.ma-lp td{border-top:0;border-left:0;border-right:0;background:#fff}
.ma-lp figure{margin:0}
.ma-lp svg{display:inline-block;vertical-align:middle}
"""
css = css + reset
css = re.sub(r'\n\s*\n+', '\n', css).strip()

# ---- images ----------------------------------------------------------
def webp(name):
    b = io.BytesIO()
    Image.open(D + 'img/' + name).convert('RGB').save(b, 'WEBP', quality=78, method=6)
    return 'data:image/webp;base64,' + base64.b64encode(b.getvalue()).decode()

for n in ['home_light', 'home_dark', 'report_light', 'report_dark', 'chat_light', 'chat_dark']:
    body = body.replace(f'src="img/{n}.png"', f'src="{webp(n + ".png")}"')

svg = open(D + 'img/icon.svg', encoding='utf-8').read()
svg = re.sub(r'<\?xml[^>]*>\s*', '', svg)
svg_b64 = 'data:image/svg+xml;base64,' + base64.b64encode(svg.encode()).decode()
body = body.replace('src="img/icon.svg"', f'src="{svg_b64}"')

# ---- links that point at real pages -------------------------------------
PRO = '/buy-pro/'
# The app on Google Play (owner, 1 Nov). Until it leaves closed testing only testers can open it.
DOWNLOAD = 'https://play.google.com/store/apps/details?id=app.getmyassistant'
body = body.replace('href="pro.html"', f'href="{PRO}"')
body = body.replace('<a class="btn btn-main" href="#download">ডাউনলোড</a>', '<a class="btn btn-main" href="{DOWNLOAD}">ডাউনলোড</a>'.replace('{DOWNLOAD}', DOWNLOAD))
body = body.replace('<a class="btn btn-main" href="#">', f'<a class="btn btn-main" href="{DOWNLOAD}">')
body = body.replace('<a class="brand" href="#">', '<a class="brand" href="/">')
body = body.replace('<a href="#">গোপনীয়তা নীতি</a><a href="#">শর্তাবলি</a><span class="ph">[যোগাযোগের ইমেইল]</span>',
                    '<a href="/privacy/">গোপনীয়তা নীতি</a><a href="/terms-and-conditions/">শর্তাবলি</a><a href="mailto:info@getmyassistant.app">info@getmyassistant.app</a>')
# plan cards open the payment page with the plan already chosen
body = body.replace('<div class="plan best"><span class="tag">', f'<a class="plan best" href="{PRO}?plan=yearly"><span class="tag">')
body = re.sub(r'(<a class="plan[^>]*>.*?<p class="note">[^<]*</p>)</div>', r'\1</a>', body)
css += '\n.ma-lp a.plan{display:block;color:var(--ink)}'

# the holiday count is worked out on the visitor's phone, so it never goes stale
body = body.replace('<span class="a">বিজয় দিবস, ১৬ ডিসেম্বর — <b>আর ৬১ দিন</b>।</span>',
                    '<span class="a">বিজয় দিবস, ১৬ ডিসেম্বর — <b id="ma-vd">সামনেই</b>।</span>')
script = """<script>
(function(){var el=document.getElementById('ma-vd');if(!el)return;
var n=new Date(),t=new Date(n.getFullYear(),11,16);n=new Date(n.getFullYear(),n.getMonth(),n.getDate());
if(t<n)t=new Date(n.getFullYear()+1,11,16);var d=Math.round((t-n)/864e5);
var bn=function(x){return String(x).replace(/\\d/g,function(c){return '০১২৩৪৫৬৭৮৯'[c]})};
el.textContent=d===0?'আজই':'আর '+bn(d)+' দিন';})();
</script>"""

body = re.sub(r'\n\s*\n+', '\n', body).strip()

out = f"""<!-- My Assistant ল্যান্ডিং পেইজ — Elementor HTML উইজেটে পুরোটা পেস্ট করুন -->
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Anek+Bangla:wdth,wght@75..100,400..800&family=Noto+Sans+Bengali:wght@400;500;600;700&display=swap" rel="stylesheet">
<style>
{css}
</style>
<div class="ma-lp">
{body}
</div>
{script}
"""
for bad in ['img/', 'pro.html', '[যোগাযোগের', 'href="#"']:
    assert bad not in out, bad
open(D + 'my-assistant-landing-elementor.html', 'w', encoding='utf-8').write(out)
print(len(out.encode()) // 1024, 'KB')
