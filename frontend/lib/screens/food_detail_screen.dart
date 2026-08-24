import 'package:flutter/material.dart';
import '../models/food_log.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class FoodDetailScreen extends StatelessWidget {
  final FoodLog log;

  const FoodDetailScreen({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    final pct = (log.confidence * 100).round();
    final confidenceColor = pct >= 80 ? AppColors.primary : AppColors.warning;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0.5,
        title: const Text(
          'MEAL DETAILS',
          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (log.imageIds.isNotEmpty) ...[
            SizedBox(
              height: 260,
              child: PageView(
                children: log.imageIds
                    .map(
                      (id) => ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          ApiService.foodImageUrl(id),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: AppColors.surfaceAlt,
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image, color: AppColors.textMuted, size: 40),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            if (log.imageIds.length > 1) ...[
              const SizedBox(height: 8),
              Text(
                '${log.imageIds.length} photos',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
          ],
          Text(
            log.items.isEmpty ? 'Unknown meal' : log.items.join(', '),
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 20),
          ),
          const SizedBox(height: 4),
          Text(
            '$pct% confidence',
            style: TextStyle(color: confidenceColor, fontSize: 13),
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _macroTile('${log.calories}', 'kcal', AppColors.macroCalories),
              _macroTile('${log.protein.toStringAsFixed(1)}g', 'protein', AppColors.macroProtein),
              _macroTile('${log.fat.toStringAsFixed(1)}g', 'fat', AppColors.macroFat),
              _macroTile('${log.carbs.toStringAsFixed(1)}g', 'carbs', AppColors.macroCarbs),
            ],
          ),
        ],
      ),
    );
  }

  Widget _macroTile(String value, String label, Color accent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: accent, width: 3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 22)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}
