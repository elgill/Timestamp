import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timestamp/providers/shared_pref_provider.dart';

final exportAccuracyProvider = NotifierProvider<ExportAccuracyNotifier, bool>(ExportAccuracyNotifier.new);

class ExportAccuracyNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(sharedUtilityProvider).getExportAccuracy();

  void setExportAccuracy(bool value) {
    ref.read(sharedUtilityProvider).setExportAccuracy(value);
    state = value;
  }
}
