import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';
import '../providers/system_providers.dart';
import '../services/session_manager.dart';

class WorkshopSelector extends ConsumerWidget {
  final bool isDark;
  
  const WorkshopSelector({super.key, this.isDark = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionManagerProvider);
    final workshops = session.availableWorkshops;
    final activeWorkshopId = session.activeWorkshopId;
    
    // Find active workshop name
    final activeWorkshop = workshops.firstWhere(
      (w) => w.id == activeWorkshopId,
      orElse: () => workshops.isNotEmpty ? workshops.first : const WorkshopInfo(id: '', name: 'Pilih Bengkel', ownerId: ''),
    );

    if (workshops.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => _showWorkshopPicker(context, ref, workshops, activeWorkshopId ?? ''),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark 
              ? Colors.white.withValues(alpha: 0.1) 
              : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark 
                ? Colors.white.withValues(alpha: 0.1) 
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              SolarIconsOutline.shop,
              size: 16,
              color: isDark ? Colors.white : Colors.black87,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                activeWorkshop.name,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              SolarIconsOutline.altArrowDown,
              size: 14,
              color: (isDark ? Colors.white : Colors.black87).withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  void _showWorkshopPicker(
    BuildContext context, 
    WidgetRef ref, 
    List<WorkshopInfo> workshops,
    String activeId,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _WorkshopPickerSheet(
        workshops: workshops,
        activeId: activeId,
        onSelected: (id) {
          ref.read(sessionManagerProvider).selectWorkshop(id);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _WorkshopPickerSheet extends StatelessWidget {
  final List<WorkshopInfo> workshops;
  final String activeId;
  final ValueChanged<String> onSelected;

  const _WorkshopPickerSheet({
    required this.workshops,
    required this.activeId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Ganti Bengkel',
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            'Pilih bengkel yang ingin Anda kelola saat ini',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: workshops.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final w = workshops[index];
                final isSelected = w.id == activeId;

                return InkWell(
                  onTap: () => onSelected(w.id),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected 
                            ? Theme.of(context).primaryColor 
                            : Colors.grey.withValues(alpha: 0.1),
                        width: isSelected ? 2 : 1,
                      ),
                      color: isSelected 
                          ? Theme.of(context).primaryColor.withValues(alpha: 0.05)
                          : Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? Theme.of(context).primaryColor 
                                : Colors.grey.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            SolarIconsOutline.shop,
                            size: 20,
                            color: isSelected ? Colors.white : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                w.name,
                                style: GoogleFonts.manrope(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                w.ownerId == activeId ? 'Pemilik' : 'Staff',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            SolarIconsBold.checkCircle,
                            color: Theme.of(context).primaryColor,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
