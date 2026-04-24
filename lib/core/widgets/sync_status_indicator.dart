import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/sync_provider.dart';
import '../services/sync_worker.dart';

class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(syncStatusProvider);
    final summary = ref.watch(syncQueueSummaryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget icon;
    Color color;
    String tooltip;

    switch (state.state) {
      case SyncWorkerState.syncing:
        icon = const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF7C3AED),
          ),
        );
        color = const Color(0xFF7C3AED);
        tooltip = 'Menyinkronkan data... (${summary['syncing']} aktif)';
        break;
      case SyncWorkerState.success:
        icon = const Icon(
          SolarIconsBold.checkCircle,
          size: 16,
          color: Color(0xFF10B981),
        );
        color = const Color(0xFF10B981);
        tooltip = 'Data tersinkronisasi';
        break;
      case SyncWorkerState.warning:
        icon = const Icon(
          SolarIconsBold.infoCircle,
          size: 16,
          color: Colors.amber,
        );
        color = Colors.amber;
        tooltip = '${summary['pending']} item menunggu antrean';
        break;
      case SyncWorkerState.error:
        icon = const Icon(
          SolarIconsBold.dangerCircle,
          size: 16,
          color: Colors.redAccent,
        );
        color = Colors.redAccent;
        tooltip = '${summary['failed']} item gagal sinkronisasi';
        break;
      case SyncWorkerState.idle:
        icon = Icon(
          SolarIconsOutline.cloud,
          size: 16,
          color: isDark ? Colors.white54 : Colors.black54,
        );
        color = isDark ? Colors.white24 : Colors.black12;
        tooltip = 'Siap (Idle)';
        break;
    }

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            if (state.state == SyncWorkerState.syncing) ...[
              const SizedBox(width: 6),
              Text(
                'Syncing',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
