import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ExpenseCategoryChart extends StatelessWidget {
  final Map<String, int> data;

  const ExpenseCategoryChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final List<Color> colors = [
      theme.colorScheme.primary,
      theme.colorScheme.tertiary,
      theme.colorScheme.secondary,
      theme.colorScheme.error,
      Colors.orange,
      Colors.teal,
      Colors.purple,
    ];

    final total = data.values.fold(0, (sum, val) => sum + val);

    return Row(
      children: [
        Expanded(
          flex: 4,
          child: PieChart(
            PieChartData(
              sectionsSpace: 4,
              centerSpaceRadius: 35,
              sections: data.entries.toList().asMap().entries.map((entry) {
                final idx = entry.key;
                final val = entry.value;

                return PieChartSectionData(
                  color: colors[idx % colors.length],
                  value: val.value.toDouble(),
                  title: '', // No title in the pie itself, using legend
                  radius: 35,
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: data.entries.toList().asMap().entries.map((entry) {
                final idx = entry.key;
                final val = entry.value;
                final percentage = (val.value / total) * 100;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colors[idx % colors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          val.key.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.onSurfaceVariant,
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${percentage.toStringAsFixed(0)}%',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: colors[idx % colors.length],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

