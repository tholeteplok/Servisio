import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String> stepLabels;

  const StepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.stepLabels,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        children: [
          Row(
            children: List.generate(totalSteps * 2 - 1, (index) {
              if (index.isEven) {
                final stepNum = index ~/ 2;
                final isActive = stepNum <= currentStep;
                final isCompleted = stepNum < currentStep;

                return _buildStepCircle(
                  stepNum + 1,
                  isActive,
                  isCompleted,
                  isDark,
                  theme,
                );
              } else {
                final stepNum = index ~/ 2;
                final isCompleted = stepNum < currentStep;
                return Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? theme.colorScheme.primary
                          : (isDark ? Colors.white10 : Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }
            }),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(totalSteps, (index) {
              final isActive = index == currentStep;
              return Expanded(
                child: Text(
                  stepLabels[index],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
                    color: isActive
                        ? theme.colorScheme.primary
                        : (isDark ? Colors.white30 : Colors.grey.shade400),
                    letterSpacing: 0.5,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCircle(
    int number,
    bool isActive,
    bool isCompleted,
    bool isDark,
    ThemeData theme,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: isCompleted
            ? theme.colorScheme.primary
            : (isActive
                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100)),
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive || isCompleted
              ? theme.colorScheme.primary
              : (isDark ? Colors.white10 : Colors.grey.shade300),
          width: 2,
        ),
      ),
      child: Center(
        child: isCompleted
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : Text(
                number.toString(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isActive
                      ? theme.colorScheme.primary
                      : (isDark ? Colors.white30 : Colors.grey.shade400),
                ),
              ),
      ),
    );
  }
}

