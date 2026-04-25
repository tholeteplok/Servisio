import 'package:flutter/material.dart';
import '../../../core/utils/permission_constants.dart';

/// Tile untuk menampilkan single permission dengan checkbox
class PermissionTile extends StatelessWidget {
  final PermissionItem permission;
  final bool value;
  final ValueChanged<bool> onChanged;

  const PermissionTile({
    super.key,
    required this.permission,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: value,
      onChanged: (newValue) {
        if (newValue != null) {
          onChanged(newValue);
        }
      },
      title: Text(permission.name),
      subtitle: Text(
        permission.description,
        style: TextStyle(
          fontSize: 12,
          color: permission.riskColor,
        ),
      ),
      secondary: permission.isHighRisk
          ? const Icon(Icons.warning, color: Colors.red)
          : permission.riskLevel == RiskLevel.medium
              ? const Icon(Icons.info, color: Colors.orange)
              : null,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: permission.isHighRisk ? Colors.red : Colors.blue,
    );
  }
}

