import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/session/session_state.dart';
import 'choose_beat_screen.dart';

/// Opens the session flow: Choose-beat → Walking → Summary.
///
/// Hardwired to [WalkMode.cadenceOnly] on this branch — no FoG model.
Future<void> startWalk(BuildContext context, WidgetRef ref) async {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      builder: (_) => const ChooseBeatScreen(mode: WalkMode.cadenceOnly),
    ),
  );
}
