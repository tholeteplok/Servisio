// ignore_for_file: avoid_print
import 'dart:convert';


void main() {
  final jsonContent = jsonEncode({
    'metadata': {
      'isEncrypted': true,
      'bengkelId': 'b-1',
    },
    'pelanggan': []
  });
  
  final data = jsonDecode(jsonContent) as Map<String, dynamic>;
  final metadata = data['metadata'] as Map<String, dynamic>?;
  bool isEncrypted = metadata?['isEncrypted'] ?? false;
  String? bengkelId = metadata?['bengkelId'];
  
  print('isEncrypted: $isEncrypted');
  print('bengkelId: $bengkelId');
  
  if (isEncrypted) {
    if (bengkelId == null) {
      print('FAILED: bengkelId is null');
    } else {
      print('SUCCESS: bengkelId is $bengkelId');
    }
  }
}
