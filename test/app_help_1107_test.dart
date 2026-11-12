// 7 Nov: questions about the app itself ("যাকাত জিনিসটা কী?", "ভল্ট কোথায়
// পাব?") answered from the app's own map, with where it is and a link.
import 'package:digital_brain/logic/app_map.dart';
import 'package:digital_brain/logic/parser.dart';
import 'package:digital_brain/nlu/reader.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show start;

void main() {
  test('the answer names the part, what it does and where it is', () {
    final vault = appHelpAnswer(null, 'ভল্টে কী রাখা যায়');
    expect(vault, startsWith('পাসওয়ার্ড:'));
    expect(vault, contains('“আমার তথ্য” মেনুতে'));
    expect(appHelpAnswer('zakat', 'এটা কী'), startsWith('যাকাত:'));
    expect(appHelpAnswer(null, 'ব্যবসায়ী মোড চালু করলে কী হয়'), contains('আলাদা'));
    expect(appHelpAnswer('biz_stock', 'stock ki'), startsWith('স্টক:'));
    expect(appHelpAnswer(null, 'তুমি কী কী পারো'), contains('অনেক কিছু পারি'));
  });

  testWidgets('a sure model reading of app_help answers about the app, never a search', (t) async {
    final rig = await start(t);
    final b = rig.brain..nluMode = 'on';
    final (c, _) = await b.understandAll('যাকাতের অংশটা আসলে কী হিসাব করে', model: Future.value(const [NluPiece('app_help', 0.9, true, [], {})]));
    expect((c.single as SmallTalk).kind, Talk.appHelp);
    // A request the rules understood stays as it is.
    final (r, _) = await b.understandAll('কাল সকাল ৯টায় ব্যাংকে যাওয়ার কথা মনে করাও', model: Future.value(const [NluPiece('app_help', 0.9, true, [], {})]));
    expect(r.single, isNot(isA<SmallTalk>()));
  });
}
