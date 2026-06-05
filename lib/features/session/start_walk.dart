import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import 'walking_screen.dart';

/// Starts a walking session and opens the full-screen Walking flow.
///
/// Shared by the Home start-ring and the floating-nav centre button so the
/// behaviour is identical from anywhere. (Mock sensors auto-connect; the real
/// flow will route to Connect-sensors first if none are connected — M2+.)
Future<void> startWalk(BuildContext context, WidgetRef ref) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  await ref.read(sessionControllerProvider.notifier).startSession(bpm: 108);
  if (!context.mounted) return;
  navigator.push(MaterialPageRoute(builder: (_) => const WalkingScreen()));
}
