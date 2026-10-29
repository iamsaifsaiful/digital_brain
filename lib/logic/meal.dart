// A medicine taken before, after or with food (owner, 29 Oct).
import 'lang.dart';

/// "খাবারের আগে" … in the app's language; '' for any time.
String mealText(String meal) => switch (meal) {
      'before' => tr('খাবারের আগে'),
      'after' => tr('খাবারের পরে'),
      'with' => tr('খাবারের সাথে'),
      _ => '',
    };
