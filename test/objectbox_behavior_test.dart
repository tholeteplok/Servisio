import 'package:flutter_test/flutter_test.dart';
import 'package:servislog_core/domain/entities/stok.dart';
import 'package:servislog_core/objectbox.g.dart';
import 'mocks/manual_mocks.dart';

void main() {
  test('Case-insensitive equals query might trigger native load', () {
    final box = FakeBox<Stok>();
    try {
      box.query(Stok_.nama.equals('test', caseSensitive: false)).build();
    } catch (_) {
      // Ignored for behavior testing
    }
  });

  test('Complex AND query might trigger native load', () {
    final box = FakeBox<Stok>();
    try {
      box.query(Stok_.nama.equals('a').and(Stok_.sku.equals('b'))).build();
    } catch (_) {
      // Ignored for behavior testing
    }
  });
}
