# Values for the app_help templates (templates_help.py): a feature of the app
# (tool/nlu/spec/app_features.py) and what the asker wants with it, said by
# many kinds of people (owner, 7 Nov: "ইউজারের উচ্চারণ, বয়স, লিংগ,
# প্রোফেশনাল, স্বভাব ইত্যাদি … প্রাধান্য দেওয়া উচিত"). The regional forms
# and hearing slips are added later by noise.py, as for every other row.
import os, random, sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'spec'))
from app_features import F  # noqa: E402

# Run-ups and endings by the kind of person speaking. Empty is the most common.
OPEN = {
    'বয়স্ক': ['বাবা, একটু বলো তো,', 'মা, শোনো,', 'আমি বয়স্ক মানুষ, এত বুঝি না —', 'বাবারে,', 'চোখে কম দেখি, তাই জিজ্ঞেস করি,', 'নাতি অ্যাপটা দিয়ে গেছে,'],
    'তরুণ': ['ভাই,', 'আরে,', 'ব্রো,', 'আচ্ছা শোনো,', 'ইয়ে,', 'জাস্ট জানতে চাই,'],
    'ভদ্র': ['দয়া করে বলবেন,', 'একটা কথা জানতে চাই,', 'যদি বলতেন,', 'আপনার কাছে জানতে চাই,', 'জানতে চাচ্ছিলাম,'],
    'অধৈর্য': ['জলদি বলো,', 'তাড়াতাড়ি বলো,', 'এক কথায় বলো,', 'আরে বাবা,'],
    'দুশ্চিন্তা': ['একটু ভয় লাগছে,', 'ঠিকমতো বুঝতে চাই,', 'ভুল করে কিছু মুছে যাবে না তো,'],
    'গৃহিণী': ['সংসারের হিসাবের জন্য জানতে চাই,', 'আমার স্বামী বলল অ্যাপটা ভালো,', 'বাচ্চাদের স্কুলের কাজে লাগবে,'],
    'দোকানদার': ['দোকান চালাই,', 'বেচাকেনার হিসাব রাখি,', 'আমি ব্যবসা করি,'],
    'ছাত্র': ['পরীক্ষার পড়ার জন্য,', 'কোচিংয়ের জন্য দরকার,', 'হোস্টেলে থাকি,'],
    'প্রবাসী': ['বিদেশে থাকি,', 'দেশে টাকা পাঠাই,', 'সৌদি থেকে বলছি,'],
    'চাকরিজীবী': ['অফিসের কাজের জন্য,', 'মিটিং অনেক থাকে,', 'বেতনের হিসাব রাখি,'],
    'কৃষক': ['ধান বেচার টাকার হিসাব রাখি,', 'গ্রামে থাকি,', 'সার কেনার হিসাব রাখতে চাই,'],
}
CLOSE = ['', '', '', '', ' একটু বুঝিয়ে বলো', ' বলবেন?', ' জানাও তো', ' প্লিজ', ' ভাই', ' আপু', ' বাবা', ' জলদি', ' ঠিক বুঝতেছি না', ' কেউ শিখিয়ে দেয়নি']


def _feature(ctx):
    return ctx.once('hp_feature', lambda: random.choice(F))


def value(ctx, name, var):
    """(words, slot, value) for an hp_ placeholder, or None when it is not one."""
    if not name.startswith('hp_'):
        return None
    f = _feature(ctx)
    pick = lambda key, xs: ctx.once(key, lambda: random.choice(xs))
    if name == 'hp_f':
        return pick('hp_f', f['bn']), 'page', f['id']
    if name == 'hp_bl':
        return pick('hp_bl', f['bl']), 'page', f['id']
    if name == 'hp_en':
        return pick('hp_en', f['en']), 'page', f['id']
    if name == 'hp_act':
        # "রিমাইন্ডার দিতে" → as said: "রিমাইন্ডার দিতে" (var 'bare': "রিমাইন্ডার দেওয়া"-less form kept as is)
        return pick('hp_act', f['acts']), None, None
    if name == 'hp_actbl':
        return pick('hp_actbl', f['acts_bl'] or [f['bl'][0] + ' use korte']), None, None
    if name == 'hp_acten':
        return pick('hp_acten', f['acts_en'] or ['use ' + f['en'][0]]), None, None
    if name == 'hp_can':
        return pick('hp_can', f['can'] or [f['bn'][0] + ' ব্যবহার করা']), None, None
    if name == 'hp_open':
        if random.random() < 0.7:
            return None, None, None
        kind = random.choice(list(OPEN))
        return random.choice(OPEN[kind]), None, None
    if name == 'hp_close':
        w = random.choice(CLOSE).strip()
        return (w or None), None, None
    return None
