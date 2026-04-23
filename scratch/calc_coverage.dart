// ignore_for_file: avoid_print
import 'dart:io';

void main() {
  final file = File('coverage/lcov.info');
  if (!file.existsSync()) {
    print('lcov.info not found');
    return;
  }

  final lines = file.readAsLinesSync();
  int totalLF = 0;
  int totalLH = 0;

  for (var line in lines) {
    if (line.startsWith('LF:')) {
      totalLF += int.parse(line.substring(3));
    } else if (line.startsWith('LH:')) {
      totalLH += int.parse(line.substring(3));
    }
  }

  print('Total LF: $totalLF');
  print('Total LH: $totalLH');
  if (totalLF > 0) {
    print('Coverage: ${(totalLH / totalLF * 100).toStringAsFixed(2)}%');
  } else {
    print('Coverage: 0%');
  }
}
