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
  String currentFile = '';
  int currentLF = 0;
  int currentLH = 0;

  print('${'File'.padRight(60)} | ${'Coverage'.padLeft(10)} | ${'LH/LF'.padLeft(10)}');
  print('-' * 85);

  for (var line in lines) {
    if (line.startsWith('SF:')) {
      currentFile = line.substring(3);
      currentLF = 0;
      currentLH = 0;
    } else if (line.startsWith('LF:')) {
      currentLF = int.parse(line.substring(3));
      totalLF += currentLF;
    } else if (line.startsWith('LH:')) {
      currentLH = int.parse(line.substring(3));
      totalLH += currentLH;
    } else if (line == 'end_of_record') {
      double coverage = currentLF > 0 ? (currentLH / currentLF * 100) : 0.0;
      if (coverage < 50.0) { // Highlight low coverage
        print('${currentFile.padRight(60)} | ${coverage.toStringAsFixed(2).padLeft(9)}% | ${currentLH.toString().padLeft(4)}/${currentLF.toString().padRight(4)}');
      }
    }
  }

  print('-' * 85);
  print('Total LF: $totalLF');
  print('Total LH: $totalLH');
  if (totalLF > 0) {
    print('Total Coverage: ${(totalLH / totalLF * 100).toStringAsFixed(2)}%');
  }
}
