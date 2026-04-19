import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_theme_extension.dart';
import '../../../core/providers/master_providers.dart';
import '../../../core/utils/phone_formatter.dart';
import '../../../domain/entities/staff.dart';
import '../../../core/widgets/atelier_header.dart';

class TeknisiScreen extends ConsumerWidget {
  const TeknisiScreen({super.key});

  void _showForm(BuildContext context, WidgetRef ref, [Staff? staff]) {
    final nameCtrl = TextEditingController(text: staff?.name);
    final phoneCtrl = TextEditingController(text: staff?.phoneNumber);
    final roleCtrl = TextEditingController(text: staff?.role ?? 'Teknisi');
    final commissionCtrl = TextEditingController(
      text: ((staff?.commissionRate ?? 0.0) * 100).toStringAsFixed(0),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          top: 24,
          left: 24,
          right: 24,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                staff == null ? 'Tambah Teknisi' : 'Edit Teknisi',
                style: Theme.of(context).sectionLabelStyle,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama Lengkap',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nomor HP',
                  prefixIcon: Icon(Icons.phone),
                  hintText: '628...',
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [IndonesianPhoneFormatter()],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commissionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Komisi Default (%)',
                  prefixIcon: Icon(Icons.percent),
                  hintText: 'Misal: 10',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: () {
                    if (nameCtrl.text.isEmpty) return;
                    final commission =
                        (double.tryParse(commissionCtrl.text) ?? 0.0) / 100.0;

                    if (staff == null) {
                      ref.read(staffListProvider.notifier).add(
                            Staff(
                              name: nameCtrl.text.trim(),
                              phoneNumber: phoneCtrl.text.trim(),
                              role: roleCtrl.text.trim(),
                            )..commissionRate = commission,
                          );
                    } else {
                      staff.name = nameCtrl.text.trim();
                      staff.phoneNumber = phoneCtrl.text.trim();
                      staff.role = roleCtrl.text.trim();
                      staff.commissionRate = commission;
                      ref.read(staffListProvider.notifier).updateStaff(staff);
                    }
                    Navigator.pop(context);
                  },
                  child: Text(staff == null ? 'Tambah' : 'Simpan'),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final staffList = ref.watch(staffListProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          const SliverAtelierHeaderSub(
            title: 'Teknisi',
            subtitle: 'Kelola tim dan kru yang bekerja di bengkel.',
            showBackButton: true,
          ),
          SliverFillRemaining(
            hasScrollBody: true,
            child: Container(
              color: theme.colorScheme.surface,
              child: (staffList.valueOrNull ?? []).isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Colors.grey.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Belum ada teknisi',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: (staffList.valueOrNull ?? []).length,
                      itemBuilder: (context, index) {
                        final s = (staffList.valueOrNull ?? [])[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.primary
                                  .withValues(alpha: 0.1),
                              child: Text(
                                s.name[0].toUpperCase(),
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              s.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(s.phoneNumber ?? 'No Phone'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 20,
                                  ),
                                  tooltip: 'Ubah',
                                  style: IconButton.styleFrom(
                                    minimumSize: const Size(48, 48),
                                  ),
                                  onPressed: () => _showForm(context, ref, s),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                    color: Colors.red,
                                  ),
                                  tooltip: 'Hapus',
                                  style: IconButton.styleFrom(
                                    minimumSize: const Size(48, 48),
                                  ),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Hapus Teknisi?'),
                                        content: Text(
                                          'Apakah Anda yakin ingin menghapus ${s.name}?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('Batal'),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              ref
                                                  .read(
                                                    staffListProvider.notifier,
                                                  )
                                                  .delete(s.id);
                                              Navigator.pop(context);
                                            },
                                            child: const Text(
                                              'Hapus',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}
