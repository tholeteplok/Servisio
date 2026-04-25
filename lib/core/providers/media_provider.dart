import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/media_service.dart';

final mediaServiceProvider = Provider<MediaService>((ref) {
  return MediaService();
});

