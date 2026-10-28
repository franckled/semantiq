import 'package:flutter/widgets.dart';

import '../data/interview.dart';
import '../services/settings.dart';

/// Dépendances partagées par les écrans.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.settings,
    required this.store,
    required super.child,
  });

  final Settings settings;
  final InterviewStore store;

  static AppScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      settings != oldWidget.settings || store != oldWidget.store;
}
