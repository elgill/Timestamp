import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timestamp/providers/shared_pref_provider.dart';

final exportAccuracyProvider = StateNotifierProvider<ExportAccuracyNotifier, bool>((ref) {
  return ExportAccuracyNotifier(ref: ref);
});

class ExportAccuracyNotifier extends StateNotifier<bool> {
  ExportAccuracyNotifier({required this.ref}) : super(false) {
    state = ref.watch(sharedUtilityProvider).getExportAccuracy();
  }
  Ref ref;

  void setExportAccuracy(bool value) {
    ref.watch(sharedUtilityProvider).setExportAccuracy(value);
    state = value;
  }
}
