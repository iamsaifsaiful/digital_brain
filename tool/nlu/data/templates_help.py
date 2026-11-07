# app_help: questions about the app itself — what a feature is, how to use
# it, where it is, whether the app can do something, whether it is free
# (owner, 7 Nov 2026). Values from help_values.py (the app's feature map),
# said with the run-ups of many kinds of people ({hp_open}/{hp_close}).
# The held-out set (tool/nlu/gold/app_help.jsonl) is written apart, in other
# sentence shapes; generate.py drops anything near it. One line, one family
# (so some go to the dev split that sets the model's sure-threshold).
T = {}

T['app_help'] = '''
{hp_open} {hp_f} [জিনিসটা|টা|] কী[?| বলো তো?| আসলে?] {hp_close}

{hp_open} {hp_f:gen} কাজ কী[?|] {hp_close}

{hp_open} {hp_f} দিয়ে কী [হয়|করা যায়|করে][?|] {hp_close}

{hp_open} {hp_f} [কী কাজে লাগে|কোন কাজে লাগে|কেন দরকার|রেখে লাভ কী][?|] {hp_close}

{hp_open} {hp_f} [বিষয়টা|ব্যাপারটা|অপশনটা] একটু [বুঝিয়ে বলো|বুঝাও|খুলে বলো|বুঝাইয়া কও] {hp_close}

{hp_open} [কিভাবে|কীভাবে|কেমনে|কেমন করে|কিভাবে যে] {hp_act} হয়[?|] {hp_close}

{hp_open} {hp_act} কী করতে হবে[?|] {hp_close}

{hp_open} {hp_act} [চাই|চাচ্ছি|চাইছিলাম], [কীভাবে করব|কোথায় চাপব|কী করতে হবে][?|] {hp_close}

{hp_open} {hp_act} [কোথায় চাপ দিতে হয়|কোন বোতাম চাপব|কী বলতে হবে][?|] {hp_close}

{hp_open} আমাকে [শিখিয়ে দাও|দেখিয়ে দাও|বলে দাও] [কিভাবে|কীভাবে] {hp_act} হয় {hp_close}

{hp_open} {hp_f:gen} [নিয়ম|ব্যবহার|চালানোর নিয়ম] [কী|কেমন][?|] {hp_close}

{hp_open} {hp_f} কোথায় [পাব|আছে|খুঁজে পাব|থাকে][?|] {hp_close}

{hp_open} {hp_f} কোন [মেনুতে|পাতায়|জায়গায়|অপশনে] [আছে|পাব|থাকে][?|] {hp_close}

{hp_open} {hp_f} [খুঁজে পাচ্ছি না|পাচ্ছি না|দেখছি না][, কোথায়|, কোথায় গেল|][?|] {hp_close}

{hp_open} [এই অ্যাপে|অ্যাপে|তোমাকে দিয়ে|এটা দিয়ে] কি {hp_can} [যায়|সম্ভব|হয়][?|] {hp_close}

{hp_open} {hp_can} [যায়|যাবে|হবে] [নাকি|কি][?|] {hp_close}

{hp_open} তুমি কি {hp_can}[ও|] [পারো|পারবা|পারবে][?|] {hp_close}

{hp_open} {hp_f} কি [ফ্রি|ফ্রিতে আছে|ফ্রিতে পাওয়া যায়|সবার জন্য][?|] {hp_close}

{hp_open} {hp_f:gen} জন্য কি [টাকা লাগবে|প্রিমিয়াম লাগবে|টাকা দিতে হয়][?|] {hp_close}

{hp_open} তুমি [কী কী|কি কি|কী কী কাজ] [পারো|করতে পারো|জানো][?|] {hp_close}

{hp_open} এই [অ্যাপ|অ্যাপটা] দিয়ে [কী কী|কি কি] [করা যায়|হয়|কাজ হয়][?|] {hp_close}

{hp_open} [অ্যাপটা|তোমাকে] [কিভাবে|কীভাবে|কেমনে] [চালাব|ব্যবহার করব|কাজে লাগাব][?|] {hp_close}

{hp_open} [নতুন এসেছি|প্রথমবার চালাচ্ছি|আজই নামালাম], [কোথা থেকে শুরু করব|কী কী আছে বলো|একটু চিনিয়ে দাও] {hp_close}

{hp_bl} [ki|ki jinish|mane ki][?|]

{hp_bl} [ki kaje lage|diye ki hoy|er kaj ki][?|]

[kivabe|kemne|kibhabe] {hp_actbl}[?| hoy?| hobe?]

{hp_bl} [kothay pabo|kothay|kon menu te][?|]

{hp_bl} ki [free|free te ache][?|]

tumi [ki ki|kiki] [paro|korte paro][?|]

[what is|what's|what does] {hp_en} [do|for|]?

how do i {hp_acten}[?| in this app?]

[where is|where can i find|where do i find] {hp_en}[?|]

[can this app|is it possible to|is there a way to] {hp_acten}[?| here?]

is {hp_en} free[?| or premium?]

[what can you do|what can this app do|how do i use this app][?|]

{hp_f} [কিভাবে|কীভাবে] use [করে|করব][?|]

{hp_f} feature টা [কী|কি] [করে|কাজে লাগে][?|]

how to {hp_acten}[?|]
'''
