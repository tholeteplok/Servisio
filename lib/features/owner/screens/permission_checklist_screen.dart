import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/utils/permission_constants.dart';
import '../widgets/permission_category_card.dart';

/// Screen untuk mengatur permission checklist untuk staff atau role template
class PermissionChecklistScreen extends ConsumerStatefulWidget {
  final String bengkelId;
  final String? staffId;
  final String? roleTemplateId;
  final String? title;

  const PermissionChecklistScreen({
    super.key,
    required this.bengkelId,
    this.staffId,
    this.roleTemplateId,
    this.title,
  });

  @override
  ConsumerState<PermissionChecklistScreen> createState() =>
      _PermissionChecklistScreenState();
}

class _PermissionChecklistScreenState
    extends ConsumerState<PermissionChecklistScreen> {
  late Map<String, bool> _permissions;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _permissions = {
      for (var key in PermissionConstants.allPermissions) key: false
    };
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    setState(() => _isLoading = true);

    try {
      final permissionService = ref.read(permissionServiceProvider);

      if (widget.staffId != null) {
        // Load staff permissions
        final staffPermissions = await permissionService.getStaffPermissions(
          widget.bengkelId,
          widget.staffId!,
        );
        for (final key in staffPermissions) {
          _permissions[key] = true;
        }
      } else if (widget.roleTemplateId != null) {
        // Load role template permissions
        final roleTemplates = await permissionService.getRoleTemplates(widget.bengkelId);
        final roleTemplate = roleTemplates.firstWhere(
          (r) => r.id == widget.roleTemplateId,
          orElse: () => throw Exception('Role template not found'),
        );
        for (final entry in roleTemplate.permissions.entries) {
          if (entry.value) {
            _permissions[entry.key] = true;
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat permission: $e')),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _savePermissions() async {
    setState(() => _isSaving = true);
    final permissionService = ref.read(permissionServiceProvider);

    try {
      if (widget.staffId != null) {
        await permissionService.updateStaffPermissions(
          widget.bengkelId,
          widget.staffId!,
          Map<String, bool>.from(_permissions),
        );
      } else if (widget.roleTemplateId != null) {
        await permissionService.updateRoleTemplatePermissions(
          widget.bengkelId,
          widget.roleTemplateId!,
          Map<String, bool>.from(_permissions),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission berhasil disimpan')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e')),
        );
      }
    }

    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  void _selectAll() {
    setState(() {
      for (var key in _permissions.keys) {
        _permissions[key] = true;
      }
    });
  }

  void _deselectAll() {
    setState(() {
      for (var key in _permissions.keys) {
        _permissions[key] = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final categories = PermissionConstants.categories.values.toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ??
            (widget.staffId != null ? 'Atur Permission Staff' : 'Buat Role Template')),
        actions: [
          IconButton(icon: const Icon(Icons.select_all), onPressed: _selectAll),
          IconButton(icon: const Icon(Icons.deselect), onPressed: _deselectAll),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Centang permission yang ingin diberikan. '
                    'Permission dengan icon 🔴 memiliki risiko tinggi.',
                    style: TextStyle(color: Colors.blue.shade700),
                  ),
                ),
              ],
            ),
          ),

          // Permission categories
          Expanded(
            child: ListView(
              children: categories.map((category) => PermissionCategoryCard(
                category: category,
                permissions: _permissions,
                onPermissionChanged: (key, value) {
                  setState(() {
                    _permissions[key] = value;
                  });
                },
              )).toList(),
            ),
          ),

          // Save button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _savePermissions,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Menyimpan...' : 'SIMPAN PERMISSION'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
