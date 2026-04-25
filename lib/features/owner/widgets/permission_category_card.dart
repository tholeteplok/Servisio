import 'package:flutter/material.dart';
import '../../../core/utils/permission_constants.dart';
import 'permission_tile.dart';

/// Card untuk menampilkan kategori permission dengan expand/collapse
class PermissionCategoryCard extends StatefulWidget {
  final PermissionCategory category;
  final Map<String, bool> permissions;
  final Function(String key, bool value) onPermissionChanged;

  const PermissionCategoryCard({
    super.key,
    required this.category,
    required this.permissions,
    required this.onPermissionChanged,
  });

  @override
  State<PermissionCategoryCard> createState() => _PermissionCategoryCardState();
}

class _PermissionCategoryCardState extends State<PermissionCategoryCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          ListTile(
            leading: Icon(widget.category.icon, color: Colors.blue),
            title: Text(
              widget.category.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${widget.category.permissions.length} permission'),
            trailing: IconButton(
              icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
              onPressed: () => setState(() => _isExpanded = !_isExpanded),
            ),
            onTap: () => setState(() => _isExpanded = !_isExpanded),
          ),
          if (_isExpanded)
            Column(
              children: widget.category.permissions.map((permission) {
                return PermissionTile(
                  permission: permission,
                  value: widget.permissions[permission.key] ?? false,
                  onChanged: (value) =>
                      widget.onPermissionChanged(permission.key, value),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

