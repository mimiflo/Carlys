import 'package:flutter/material.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/feedback/server_gesture.dart';

/// Exécute un geste communautaire et en rend compte dans la barre de message.
///
/// La mécanique vit désormais au cœur (`core/feedback/server_gesture.dart`) :
/// la règle — tout geste qui part sur le réseau dit ce qu'il advient de lui —
/// n'a rien de propre à la communauté, et trois autres écrans en avaient
/// besoin. Ce nom reste parce que les appelants le lisent bien : ici, on
/// parle de gestes communautaires.
Future<void> runCommunityGesture(
  BuildContext context,
  Future<String?> Function() gesture,
) {
  return runServerGesture(context, gesture, scope: 'CommunityFeedback');
}

/// Le mot juste pour un geste qui n'a pas abouti, hors ligne ou pas.
String communityFailureMessage(AppException? exception) =>
    serverFailureMessage(exception);
