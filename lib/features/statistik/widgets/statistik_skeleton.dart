import 'package:flutter/material.dart';
import '../../../core/widgets/shimmer_widget.dart';

class StatistikSkeleton extends StatelessWidget {
  const StatistikSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Range Selector Shimmer
          ShimmerWidget.rectangular(height: 48),
          SizedBox(height: 20),
          
          // Summary Cards
          Row(
            children: [
              Expanded(child: ShimmerWidget.rectangular(height: 120)),
              SizedBox(width: 16),
              Expanded(child: ShimmerWidget.rectangular(height: 120)),
            ],
          ),
          SizedBox(height: 20),
          
          // Cash Flow Tracker
          ShimmerWidget.rectangular(height: 200),
          SizedBox(height: 20),
          
          // Chart Card
          ShimmerWidget.rectangular(height: 250),
          SizedBox(height: 16),
          
          // Info Box
          ShimmerWidget.rectangular(height: 80),
        ],
      ),
    );
  }
}
