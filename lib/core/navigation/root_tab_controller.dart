import 'package:flutter/foundation.dart';

enum RootTab { today, quiz }

/// Lets routes above the retained root shell choose which root tab shows when
/// they return to it.
final class RootTabController extends ValueNotifier<RootTab> {
  RootTabController() : super(RootTab.today);
}
