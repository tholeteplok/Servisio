import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../../core/constants/app_theme_extension.dart';
import '../../../core/providers/pengaturan_provider.dart';
import '../../../core/providers/system_providers.dart';
import '../../../core/utils/phone_formatter.dart';
import '../../../core/widgets/atelier_header.dart';
import '../../auth/screens/login_screen.dart';
import '../../../core/constants/app_strings.dart';

class ProfilScreen extends ConsumerStatefulWidget {
  const ProfilScreen({super.key});

  @override
  ConsumerState<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends ConsumerState<ProfilScreen> {
  late TextEditingController _namaBengkelCtrl;
  late TextEditingController _alamatBengkelCtrl;
  late TextEditingController _waBengkelCtrl;
  late TextEditingController _namaOwnerCtrl;
  late TextEditingController _phoneOwnerCtrl;

  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  String? _workshopLogoPath;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _namaBengkelCtrl = TextEditingController(text: settings.workshopName);
    _alamatBengkelCtrl = TextEditingController(text: settings.workshopAddress);
    _waBengkelCtrl = TextEditingController(text: settings.workshopWhatsapp);
    _namaOwnerCtrl = TextEditingController(text: settings.ownerName);
    _phoneOwnerCtrl = TextEditingController(text: settings.ownerPhone);
    _workshopLogoPath = settings.workshopLogoPath;
  }

  @override
  void dispose() {
    _namaBengkelCtrl.dispose();
    _alamatBengkelCtrl.dispose();
    _waBengkelCtrl.dispose();
    _namaOwnerCtrl.dispose();
    _phoneOwnerCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final notifier = ref.read(settingsProvider.notifier);
    await notifier.updateWorkshopInfo(
      name: _namaBengkelCtrl.text.trim(),
      address: _alamatBengkelCtrl.text.trim(),
      whatsapp: _waBengkelCtrl.text.trim(),
    );
    await notifier.updateOwnerInfo(
      name: _namaOwnerCtrl.text.trim(),
      phone: _phoneOwnerCtrl.text.trim(),
    );

    await notifier.updateWorkshopLogo(_workshopLogoPath);
    
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.profile.saveSuccess),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (image != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'workshop_logo_${DateTime.now().millisecondsSinceEpoch}${path.extension(image.path)}';
      final savedImage = await File(image.path).copy('${appDir.path}/$fileName');
      
      // Clean up old logo if it exists locally
      if (_workshopLogoPath != null && _workshopLogoPath!.startsWith(appDir.path)) {
        try {
          final oldFile = File(_workshopLogoPath!);
          if (await oldFile.exists()) await oldFile.delete();
        } catch (_) {}
      }

      setState(() => _workshopLogoPath = savedImage.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAtelierHeaderSub(
            title: AppStrings.profile.title,
            subtitle: AppStrings.profile.subtitle,
            showBackButton: true,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppStrings.profile.workshopInfo, style: theme.sectionLabelStyle),
                    const SizedBox(height: 16),
                    
                    // Logo Picker UI
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                  width: 2,
                                ),
                                image: _workshopLogoPath != null
                                    ? DecorationImage(
                                        image: FileImage(File(_workshopLogoPath!)),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: _workshopLogoPath == null
                                  ? Icon(
                                      SolarIconsOutline.camera,
                                      color: theme.colorScheme.primary,
                                      size: 32,
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(SolarIconsOutline.upload, size: 16),
                            label: const Text('Ganti Logo Bengkel'),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    TextFormField(
                      controller: _namaBengkelCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: AppStrings.profile.workshopName,
                        prefixIcon: const Icon(Icons.storefront),
                      ),
                      validator: (v) => v == null || v.isEmpty
                          ? 'Nama bengkel wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _alamatBengkelCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: AppStrings.profile.workshopAddress,
                        prefixIcon: const Icon(Icons.location_on_outlined),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _waBengkelCtrl,
                      decoration: InputDecoration(
                        labelText: AppStrings.profile.workshopWA,
                        prefixIcon: const Icon(Icons.phone),
                        hintText: '62812...',
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [IndonesianPhoneFormatter()],
                    ),

                    const SizedBox(height: 32),
                    Text(AppStrings.profile.ownerInfo, style: theme.sectionLabelStyle),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _namaOwnerCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: AppStrings.profile.ownerName,
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      validator: (v) => v == null || v.isEmpty
                          ? 'Nama owner wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneOwnerCtrl,
                      decoration: InputDecoration(
                        labelText: AppStrings.profile.ownerPhone,
                        prefixIcon: const Icon(Icons.phone_android),
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [IndonesianPhoneFormatter()],
                    ),

                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: _isSaving ? null : _save,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(AppStrings.common.saveChanges),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton.icon(
                        onPressed: () => _showLogoutDialog(context),
                        icon: const Icon(
                          SolarIconsOutline.logout,
                          color: Colors.red,
                        ),
                        label: Text(AppStrings.common.logoutAccount),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Future<void> _showLogoutDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.common.logoutAccount),
        content: const Text(
          'Apakah Anda yakin ingin keluar? Semua data lokal akan dibersihkan demi keamanan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.common.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.common.logout),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(logoutProvider)();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }
}

