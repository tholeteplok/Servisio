import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'navigation_provider.dart';

/// Provider to toggle search mode in Home screen
final homeSearchActiveProvider = StateProvider<bool>((ref) => false);

class HomeSearchQueryNotifier extends StateNotifier<String> {
  final Ref ref;
  HomeSearchQueryNotifier(this.ref) : super('') {
    // 🔍 Listen to navigation changes to clear search
    ref.listen(navigationProvider, (previous, next) {
      if (next != 0) {
        state = '';
      }
    });
  }

  void update(String query) => state = query;
  void clear() => state = '';
}

final homeSearchQueryProvider = StateNotifierProvider<HomeSearchQueryNotifier, String>((ref) {
  return HomeSearchQueryNotifier(ref);
});

