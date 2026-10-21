# The NLU spec from one source: writes tool/nlu/spec/{intents,slots,states,
# pairs,out_of_scope}.json and docs/nlu-spec.md.
#   python3 tool/nlu/spec/build_spec.py
import json, os, sys
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
from intents_core import CORE  # noqa: E402
from intents_more import MORE  # noqa: E402

INTENTS = CORE + MORE

SLOTS = {
  'date': 'নির্দিষ্ট দিন (১৫ জুন, ১৫ই ফেব্রুয়ারী ২০২৯), আপেক্ষিক দিন (কাল, পরশু, আগামী শুক্রবার, মাসের শেষে), মাস, সাল, রেঞ্জ। মান: ISO দিন, বা span (week/month/year)।',
  'time': 'ঘড়ির সময় (৯টা, সাড়ে ৭টা, ৬.৩০)। শুধু ঘণ্টা আর daypart নেই → await_ampm। "রাত ১২টা" = পরের তারিখের 00:00।',
  'daypart': 'ভোর, সকাল, দুপুর, বিকাল, সন্ধ্যা, রাত।',
  'repeat': 'প্রতিদিন, প্রতি সপ্তাহ (বারসহ), প্রতি মাস (তারিখসহ), প্রতি বছর, মিনিট-ব্যবধান।',
  'before': 'আগে মনে করানো (৩০ মিনিট আগে, আগের দিন)।',
  'minutes': 'স্নুজের মিনিট।',
  'amount': 'টাকা: ৫০০, দেড় হাজার, আড়াইশো, সাড়ে তিন হাজার, 2k, ১৫০০০/=, "৫০০ করে" (প্রতিজনে)। মানের হিসাব অ্যাপ করে, মডেল নয়।',
  'amount2': 'দ্বিতীয় অঙ্ক (ফি, আংশিক পরিশোধ)।',
  'balance': 'ledger_set: মোট অবস্থা; চিহ্ন (কে পাবে) অ্যাপ ঠিক করে।',
  'quantity': 'পরিমাণ ("৩ কেজি ৩০০ টাকা"-র ৩)।',
  'unit': 'একক (কেজি, লিটার, পিস, ডজন, হালি)।',
  'unit_price': 'একক-দর ("কেজি ৬০ টাকা")।',
  'person': 'মানুষের নাম/সম্পর্ক বিভক্তি ছাড়া (রহিমকে → রহিম)। খোঁজার ক্রম: লেনদেনের বই → রাখা কন্টাক্ট → ফোনের তালিকা; পুরো নাম আংশিক মিলের আগে।',
  'item': 'জিনিস (পেঁয়াজ, চাল)।',
  'category': 'খাত বা নোটের বিভাগ।',
  'account': 'প্রজেক্ট/অন্যান্য হিসাব বা ব্যাংক একাউন্ট।',
  'list_ref': 'দেখানো তালিকার জিনিস: index (৩নং, তৃতীয়টা, শেষেরটা), range (২ থেকে ৪), first/last N, except (১ ছাড়া), all (এগুলো সব), it (ওটা/এটা/এখানে)।',
  'filter_year': 'সাল দিয়ে বাছাই (২০২৭ সালের)।',
  'filter_month': 'মাস দিয়ে বাছাই (নভেম্বরের, ফেব্রুয়ারি ২০২৯-এর)।',
  'filter': 'জরুরি, দেরি, তারিখহীন, খোলা, শেষ করা।',
  'title': 'কাজ/রিমাইন্ডারের বিষয়, ব্যবহারকারীর শব্দে।',
  'new_title': 'rename: নতুন নাম, হুবহু।',
  'text': 'নোট/স্মৃতি/মেসেজের লেখা।',
  'terms': 'খোঁজার শব্দ।',
  'via': 'call | sms | whatsapp।',
  'page': 'অ্যাপ ম্যাপের পাতা id।',
  'folder': 'কাগজের ফোল্ডার বা নোটের বিভাগ।',
  'ledger_kind': 'lent | borrowed | received | repaid | unclear।',
  'cash_kind': 'income | expense।',
  'special_kind': 'birthday | anniversary | deathday | other।',
  'health_kind': 'bp | sugar | weight | pulse | temp …',
  'op': 'মেনুর কাজ — app_map.dart voiceCaps-এর বন্ধ তালিকা থেকে।',
  'target': 'মেনুর নাম (একাউন্ট, লক্ষ্য, ওষুধ, অভ্যাস, প্রজেক্ট, দোকান, মানুষ)।',
  'target2': 'দ্বিতীয় নাম (টাকা যেখানে গেল)।',
  'shift_days': '+N পিছানো, −N এগোনো।',
  'urgent': 'জরুরি হ্যাঁ/না।',
  'note': 'কাজের সাথে বাড়তি লেখা।',
  'alarm': 'অ্যালার্ম চাওয়া হয়েছে।',
  'ask': 'ledger_query: person | receivable | payable | all।',
  'phone': 'ফোন নম্বর — শুধু ফোনে, কখনো ক্লাউডে নয়।',
}

STATES = [
  ('idle', 'কিছু অপেক্ষায় নেই', 'সব intent', '—'),
  ('await_time', 'কয়টায়? (রিমাইন্ডার/কাজের রিমাইন্ডার)', 'inform (time, daypart); confirm_yes = প্রস্তাবিত সময় (শুধু "হ্যাঁ" হলে একবার নিশ্চিত); cancel', 'প্রশ্ন, অভিযোগ, নতুন বিষয়, ৩০ মিনিট'),
  ('await_ampm', 'সকাল না সন্ধ্যা?', 'inform (daypart, time), cancel', 'একই'),
  ('await_new_value', 'নতুন সময়/তারিখ কত? (reminder_edit, task_edit)', 'inform (time, date), cancel', 'একই'),
  ('await_person', 'কার সাথে লেনদেন?', 'inform (person), select, cancel, correct', 'একই'),
  ('await_kind', 'দিলেন না নিলেন? / আয় না খরচ?', 'ledger_kind/cash_kind, select, cancel', 'একই'),
  ('confirm_delete', 'এই N টা মুছে দেব? (তালিকাসহ)', 'confirm_yes, confirm_no; select ("শুধু ২০২৭ সালের", "১ ছাড়া") → প্রস্তাব ছোট করে আবার জিজ্ঞেস; cancel', 'তালিকা দেখতে চাইলে প্রশ্ন বাদ — কিছু মোছা হয় না; নতুন বিষয়'),
  ('confirm_save', 'রাখি? (টাকা, নোটের নতুন বিভাগ)', 'confirm_yes, confirm_no, correct (মান বদলে আবার দেখানো)', 'নতুন অনুরোধে পুরনোটা বাদ — কখনো নতুন বাক্যের "দাও" দিয়ে সেভ নয়'),
  ('confirm_batch', 'কয়েকটা একসাথে রাখব?', 'confirm_yes, confirm_no, select, correct', 'একই'),
  ('pick_one', 'কয়েকটা মিলেছে — কোনটা?', 'select (নম্বর, নাম, "সব"), cancel', 'অভিযোগ ("এটা না") হলে আবার জিজ্ঞেস; নতুন বিষয়'),
  ('clarify', 'দুই বিকল্প (সরাব নাকি আরেকটা? / আজকেরগুলো নাকি সব?)', 'select; বিকল্পের শব্দ (প্রশ্নবোধক ছাড়া)', 'প্রশ্নবোধক নতুন অনুরোধ'),
  ('dictating_list', 'তালিকা লেখা চলছে — শেষ / বাতিল', 'task_add (প্রতি লাইন), dictate_end, cancel', 'প্রশ্ন বা অভিযোগে লেখা থামিয়ে উত্তর, "লেখা চালাও"-তে ফেরা; ১০ মিনিট নীরবতা'),
]

PAIRS = [
  ('প্রশ্ন বনাম রাখা', 'রহিম কত পাবে?', 'ledger_query', 'রহিম ৫০০ পাবে', 'ledger_add', 'প্রশ্নবোধক শব্দ ("কত", "কী") আর অঙ্ক নেই → প্রশ্ন; অঙ্ক বলা → রাখা'),
  ('হয়ে গেছে / হবে / হয়নি', 'রহিমকে ৫০০ দিলাম', 'ledger_add', 'রহিমকে কাল ৫০০ দেব', 'task_add', 'অতীত = ঘটনা রাখা; ভবিষ্যৎ = করণীয়; "দিইনি" = কিছু রাখা হবে না (correct)'),
  ('কাজ বনাম রিমাইন্ডার', 'কাল ব্যাংকে যাব', 'task_add', 'কাল সকাল ৯টায় ব্যাংকের কথা মনে করিও', 'reminder_add', 'ঘড়ির সময় + মনে করানো → রিমাইন্ডার; শুধু দিন + করণীয় → কাজ'),
  ('ধার বনাম নিজের খরচ', 'রহিমকে ৫০০ দিলাম', 'ledger_add', 'রিকশায় ৫০০ গেল', 'cash_add', 'মানুষ + দেওয়া/নেওয়া → ধার; জিনিস/খাত → খরচ; অনিশ্চিত হলে "লেনদেন, নাকি নিজের খরচ?"'),
  ('নোট বনাম টাকার হিসাব', 'ইমরান ১০ হাজার দিয়েছে', 'ledger_add', 'ইমরান ১০ হাজার দিয়েছে, শুধু নোট করে রাখো', 'note_add', 'ব্যবহারকারী জায়গা বলে দিলে সেটাই'),
  ('তালিকা দেখা বনাম লেখা', 'কালকের লিস্ট দাও', 'task_query', 'কালকের লিস্ট লিখব, বলছি', 'dictate_start', '"দাও/দেখাও/কী আছে" দেখা; "লিখব/বানাও/বলছি" লেখা'),
  ('বাকিতে মাল দেওয়া বনাম বাকি আদায়', 'রহিমকে ১২০০ টাকার মাল বাকিতে দিলাম', 'menu_shop', 'রহিম বাকির ৫০০ দিয়ে গেল', 'ledger_add', 'মাল দেওয়া = বিক্রি (credit_sale); বাকি আদায় = পাওনা ফেরত (received)'),
  ('"সরাও": দিন বদল বনাম মোছা', 'বাজারের কাজটা কাল সরাও', 'task_edit', 'বাজারের কাজটা তালিকা থেকে সরাও', 'task_delete', 'নতুন দিন থাকলে বদল; "তালিকা থেকে" থাকলে মোছা'),
  ('রিমাইন্ডার বদল বনাম নতুন', 'তুবার জন্মদিনের রিমাইন্ডার সন্ধ্যা ৭টায় সরাও', 'reminder_edit', 'কাল সন্ধ্যা ৭টায় তুবার উপহারের কথা মনে করিও', 'reminder_add', 'একই নামের রিমাইন্ডার আছে + বদল শব্দ → edit; শুধু "দিও" হলে জিজ্ঞেস'),
  ('নাম বদল বনাম দিন বদল', 'যশোর যাওয়া কাজের নাম বদলে শ্বশুর বাড়ি রাখো', 'rename', 'যশোর যাওয়ার তারিখ বদলে ২৮ অক্টোবর করো', 'task_edit', '"নাম" শব্দ, বা নতুন মান তারিখ নয় → rename'),
  ('বন্ধ বনাম মোছা', 'মিটিংয়ের রিমাইন্ডার বন্ধ করো', 'reminder_stop', 'মিটিংয়ের রিমাইন্ডার মুছে দাও', 'reminder_delete', 'বন্ধ = থাকবে, বাজবে না'),
  ('অভিযোগ বনাম সংশোধন', 'তুমি ভুল বুঝেছো', 'complain_help', 'না, কাল', 'correct', 'নতুন মান থাকলে সংশোধন'),
]

OUT_OF_SCOPE = {
  'replies': [
    'এটা আমি পারি না — আমি আপনার কাজ, রিমাইন্ডার, টাকার হিসাব, নোট আর কাগজপত্র সামলাই। যেমন বলতে পারেন “কাল সকাল ৯টায় ব্যাংকের কথা মনে করিও”।',
    'এ প্রশ্নের উত্তর দেওয়া আমার কাজের বাইরে। আমি পারি: কাজের তালিকা, রিমাইন্ডার, ধার-দেনা, আয়-ব্যয়, নোট। যেমন “রহিমকে ৫০০ টাকা দিলাম”।',
    'দুঃখিত, পরামর্শ বা সাধারণ প্রশ্নের উত্তর আমি দিই না। আপনার নিজের তথ্য রাখা আর খোঁজায় সাহায্য করতে পারি — যেমন “আজ কী কী কাজ আছে?”।',
    'এটা এখনো কথায় করা যায় না। পাতায় গিয়ে করতে পারেন, বা অন্য কিছু বলুন — যেমন “এই মাসে কত খরচ হলো?”।',
  ],
  'button': 'কী কী পারি',
}

DECISIONS = [
  ('ধারের দিক আলাদা intent নয়', '`ledger_add` একটা intent, দিক `ledger_kind` তথ্য। বাক্যের গঠন একই, শুধু ক্রিয়ার দিক আলাদা; আলাদা intent করলে প্রতিটার ডেটা ছোট হয়। দিক নিয়ে মডেল অনিশ্চিত হলে টাকার নিয়মে (≥৯৯%) কার্ড বা এক লাইনের প্রশ্ন।'),
  ('আয় আর খরচ একটা intent', '`cash_add` + `cash_kind` — একই কারণে।'),
  ('মেনু: এক মেনু এক intent', '`menu_<domain>`; কী করা হবে (`op`) তথ্য, voiceCaps-এর বন্ধ তালিকা থেকে। ~৪০টা op আলাদা intent হলে প্রতিটার উদাহরণ খুব কম হতো।'),
  ('একসাথে অনেকগুলো (bulk) আলাদা intent নয়', 'মোছা, শেষ, সরানো একই intent; কোনগুলো তা `list_ref`/`filter_year`/`filter_month` তথ্য। পুরনো `BulkAction` এদের থেকেই বানানো হবে।'),
  ('রিমাইন্ডার মোছা আর বন্ধ আলাদা', '`reminder_delete` আর `reminder_stop` — ফল আলাদা (মুছে যায় বনাম থাকে), আর মোছার নির্ভুলতার লক্ষ্য আলাদা।'),
  ('রিমাইন্ডার বদল নতুন intent', '`reminder_edit` — আজকের route টুলে নেই (এখন নিয়ম ManageItem(edit) দিয়ে করে)। ক্লাউড টুলে যোগ হবে।'),
  ('গোপন জিনিস শুধু ফোনে', '`phone_only` চিহ্নিত intent (ভল্ট, কন্টাক্ট, স্বাস্থ্য, ওষুধ, প্রোফাইল) কখনো ক্লাউডে যায় না; ফোনের মডেল সন্দেহ করলে ফোনের পুরনো পথ।'),
  ('খোলা প্রশ্ন নেই', 'আজকের `chat` action-এর জায়গায় `smalltalk` (সালাম/ধন্যবাদ) আর `out_of_scope` (বাকি সব), নির্দিষ্ট ছোট উত্তরসহ।'),
]


def md():
    L = ['# My Assistant — বোঝার সংজ্ঞা (NLU spec)', '',
         '> ধাপ B, ২১ অক্টোবর ২০২৬-এর নির্দেশনা। উৎস: `tool/nlu/spec/build_spec.py` (এই ফাইল আর `tool/nlu/spec/*.json` সেখান থেকে তৈরি — হাতে বদলাবেন না)।', '',
         '## সারাংশ', '']
    groups = Counter(i['group'] for i in INTENTS)
    L += [f'- মোট intent: **{len(INTENTS)}** ({", ".join(f"{g} {n}" for g, n in groups.items())})',
          f'- শুধু ফোনে (কখনো ক্লাউডে নয়): {", ".join(i["id"] for i in INTENTS if i["phone_only"])}',
          f'- তথ্যের ধরন (slot): {len(SLOTS)}; কথোপকথনের অবস্থা: {len(STATES)}; গুলিয়ে যাওয়া জোড়া: {len(PAIRS)}',
          f'- উদাহরণ: প্রতিটা intent-এ ১০টা ঠিক আর ৫টা দেখতে-একই-কিন্তু-অন্য। এগুলো **সংজ্ঞার জন্য**, যাচাই-সেট নয়; যাচাই-সেটের বাক্য বা কাছাকাছি রূপ শেখানোর ডেটায় যাবে না।', '',
          '## সিদ্ধান্ত (আপনার অনুমোদনের জন্য)', '']
    for a, b in DECISIONS:
        L.append(f'- **{a}.** {b}')
    L += ['', '## Intent-এর তালিকা', '', '| intent | দল | এখনকার Command | আবশ্যিক তথ্য | শুধু ফোনে |', '|---|---|---|---|---|']
    for i in INTENTS:
        L.append(f"| `{i['id']}` | {i['group']} | {i['maps_to']} | {', '.join(i['required']) or '—'} | {'হ্যাঁ' if i['phone_only'] else ''} |")
    L += ['', '## প্রতিটা intent', '']
    for i in INTENTS:
        L += [f"### `{i['id']}` — {i['group']}", '', f"**কখন:** {i['when']}", '', f"**কখন না:** {i['not_when']}", '']
        if i['confusable']:
            L.append('**যার সাথে গুলিয়ে যায়:**')
            for c in i['confusable']:
                L.append(f"- `{c['intent']}` — {c['difference']}")
            L.append('')
        L.append(f"**তথ্য:** আবশ্যিক {', '.join(i['required']) or '—'}; ঐচ্ছিক {', '.join(i['optional']) or '—'}" + (' · **শুধু ফোনে**' if i['phone_only'] else ''))
        if i['note']:
            L.append(f"\n{i['note']}")
        L += ['', '**ঠিক উদাহরণ:** ' + ' · '.join(f'“{x}”' for x in i['examples']), '',
              '**দেখতে একই, কিন্তু অন্য:** ' + ' · '.join(f'“{n["text"]}” → `{n["intent"]}`' for n in i['negatives']), '']
    L += ['## গুলিয়ে যাওয়া জোড়া', '', '| জোড়া | ক | intent | খ | intent | নিয়ম |', '|---|---|---|---|---|---|']
    for p in PAIRS:
        L.append('| ' + ' | '.join([p[0], f'“{p[1]}”', f'`{p[2]}`', f'“{p[3]}”', f'`{p[4]}`', p[5]]) + ' |')
    L += ['', '## তথ্যের ধরন (slot)', '', '| slot | মানে |', '|---|---|']
    for k, v in SLOTS.items():
        L.append(f'| `{k}` | {v} |')
    L += ['', '## কথোপকথনের অবস্থা', '', '| অবস্থা | কী জিজ্ঞেস | কোন intent চলে | কীভাবে বের হয় |', '|---|---|---|---|']
    for s in STATES:
        L.append('| ' + ' | '.join([f'`{s[0]}`', s[1], s[2], s[3]]) + ' |')
    L += ['', 'সব অবস্থা থেকে সবসময় বের হওয়া যায়: বাতিল, প্রশ্ন, অভিযোগ, নতুন বিষয়, বা সময় পেরোলে। বের হলে কিছু রাখা বা মোছা হয় না।', '',
          '## ফলাফলের ফরম্যাট', '',
          'ফোনের মডেল আর ক্লাউড একই JSON দেবে, তারপর এক জায়গায় এখনকার `Command`-এ রূপান্তর (আজকের `ai_map.dart`-এর `commandsFromAi` সাধারণ করে):', '',
          '```json', '{"items": [{"intent": "reminder_edit", "confidence": 0.93,', '  "slots": {"title": "তুবার জন্মদিন", "time": "19:00"},', '  "spans": {"title": [0, 13], "time": [27, 37]}}],', ' "reply": ""}', '```', '',
          'অঙ্ক, যোগফল, বাকি — সবসময় অ্যাপ হিসাব করে। মডেল শুধু স্প্যান দেয়; মান বের করে নিয়ম (`values.dart`)।', '',
          '## অ্যাপের পরিধির বাইরের কথা', '']
    for r in OUT_OF_SCOPE['replies']:
        L.append(f'- “{r}”')
    L += ['', f'সাথে একটা বোতাম: “{OUT_OF_SCOPE["button"]}”।', '']
    return '\n'.join(L)


def main():
    ids = [i['id'] for i in INTENTS]
    assert len(ids) == len(set(ids)), 'duplicate intent ids'
    known = set(ids)
    bad = sorted({n['intent'] for i in INTENTS for n in i['negatives'] if n['intent'] not in known} | {c['intent'] for i in INTENTS for c in i['confusable'] if c['intent'] not in known})
    assert not bad, f'unknown intents named: {bad}'
    for i in INTENTS:
        for n in i['negatives']:
            assert n['intent'] != i['id'], (i['id'], n['text'])
        for s in i['required'] + i['optional']:
            for part in s.split('|'):
                assert part in SLOTS, (i['id'], part)
    dump = lambda name, x: json.dump(x, open(os.path.join(HERE, name), 'w'), ensure_ascii=False, indent=1)
    dump('intents.json', INTENTS)
    dump('slots.json', SLOTS)
    dump('states.json', [dict(state=a, asks=b, accepts=c, exits=d) for a, b, c, d in STATES])
    dump('pairs.json', [dict(pair=a, a=b, a_intent=c, b=d, b_intent=e, rule=f) for a, b, c, d, e, f in PAIRS])
    dump('out_of_scope.json', OUT_OF_SCOPE)
    open(os.path.join(ROOT, 'docs', 'nlu-spec.md'), 'w').write(md())
    print(f'{len(INTENTS)} intents, {sum(len(i["examples"]) for i in INTENTS)} examples, {sum(len(i["negatives"]) for i in INTENTS)} look-alikes, {len(SLOTS)} slots, {len(STATES)} states, {len(PAIRS)} pairs')


if __name__ == '__main__':
    main()
