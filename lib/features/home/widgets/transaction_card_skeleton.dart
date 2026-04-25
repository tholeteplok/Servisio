import 'package:flutter/material.dart';
import '../../../core/widgets/shimmer_widget.dart';

class TransactionCardSkeleton extends StatelessWidget {
  const TransactionCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          // Icon/Photo Circle
          const ShimmerWidget.circular(width: 48, height: 48),
          
          const SizedBox(width: 16),
          
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Plate Number
                ShimmerWidget.rectangular(
                  height: 16,
                  width: MediaQuery.of(context).size.width * 0.3,
                ),
                const SizedBox(height: 8),
                // Customer Name
                ShimmerWidget.rectangular(
                  height: 12,
                  width: MediaQuery.of(context).size.width * 0.5,
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Status Badge
          const ShimmerWidget.rectangular(
            height: 24,
            width: 60,
          ),
        ],
      ),
    );
  }
}

