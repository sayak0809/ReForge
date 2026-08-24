import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/food_log.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/level_up_dialog.dart';
import 'food_detail_screen.dart';
import 'manual_food_entry_screen.dart';

enum _LogMethod { camera, gallery, manual }

class FoodScreen extends StatefulWidget {
  const FoodScreen({super.key});

  @override
  State<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends State<FoodScreen> {
  final _api = ApiService();
  final _picker = ImagePicker();

  List<FoodLog> _logs = [];
  bool _loading = true;
  bool _analyzing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final logs = await _api.getFoodHistory();
      setState(() {
        _logs = logs;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _onFabTapped() async {
    final method = await _showLogMethodSheet();
    if (method == null || !mounted) return;

    if (method == _LogMethod.manual) {
      await _openManualEntry();
      return;
    }

    final source = method == _LogMethod.camera ? ImageSource.camera : ImageSource.gallery;
    final xfile = await _picker.pickImage(source: source, imageQuality: 80);
    if (xfile == null || !mounted) return;

    setState(() => _analyzing = true);
    try {
      final bytes = await xfile.readAsBytes();
      final filename = xfile.name.isNotEmpty ? xfile.name : 'meal_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final result = await _api.logFood(bytes, filename);
      setState(() => _analyzing = false);
      if (!mounted) return;

      final needsMore = result['needs_better_photo'] == true;
      if (needsMore) {
        await _showNeedsMorePhotosDialog(result['food_log']['id'] as int);
      } else {
        await _showResultBottomSheet(result);
      }
    } catch (e) {
      setState(() => _analyzing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _openManualEntry() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const ManualFoodEntryScreen()),
    );
    if (result == null || !mounted) return;
    await _showResultBottomSheet(result);
  }

  Future<_LogMethod?> _showLogMethodSheet() {
    return showModalBottomSheet<_LogMethod>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text('Camera (AI analysis)', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(ctx, _LogMethod.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Photo Library (AI analysis)', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(ctx, _LogMethod.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.edit_note, color: AppColors.primary),
              title: const Text('Enter manually', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(ctx, _LogMethod.manual),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showNeedsMorePhotosDialog(int foodLogId) async {
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('AI Needs Another Angle', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'The confidence is too low to accurately log this meal. Add another photo from a different angle, or accept the current estimate.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              if (!mounted) return;
              final xfile = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
              if (xfile == null || !mounted) return;
              setState(() => _analyzing = true);
              try {
                final bytes = await xfile.readAsBytes();
                final filename = xfile.name.isNotEmpty ? xfile.name : 'meal_${DateTime.now().millisecondsSinceEpoch}.jpg';
                final result = await _api.addFoodPhoto(foodLogId, bytes, filename);
                setState(() => _analyzing = false);
                if (!mounted) return;
                await _showResultBottomSheet(result);
              } catch (e) {
                setState(() => _analyzing = false);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                );
              }
            },
            child: const Text('Add Another Photo', style: TextStyle(color: AppColors.primary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _loadData();
            },
            child: const Text('Accept Estimate Anyway', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Future<void> _showResultBottomSheet(Map<String, dynamic> result) async {
    final foodLog = (result['food_log'] as Map<String, dynamic>?) ?? const {};
    final items = List<String>.from((foodLog['items'] as List?) ?? []);
    final calories = (foodLog['estimated_calories'] as num?)?.toInt() ?? 0;
    final protein = (foodLog['estimated_protein'] as num?)?.toDouble() ?? 0.0;
    final fat = (foodLog['estimated_fat'] as num?)?.toDouble() ?? 0.0;
    final carbs = (foodLog['estimated_carbs'] as num?)?.toDouble() ?? 0.0;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'MEAL LOGGED',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    fontSize: 16,
                  ),
                ),
                const Text(
                  '+20 XP earned',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (items.isNotEmpty) ...[
              Text(
                items.join(', '),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
              ),
              const SizedBox(height: 14),
            ],
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _statChip('$calories', 'kcal'),
                _statChip('${protein.toStringAsFixed(1)}g', 'protein'),
                _statChip('${fat.toStringAsFixed(1)}g', 'fat'),
                _statChip('${carbs.toStringAsFixed(1)}g', 'carbs'),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(sheetCtx);
                  _loadData();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'DONE',
                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    final leveledUp = result['leveled_up'] as bool? ?? false;
    final newLevel = result['new_level'] as int?;
    final newTitle = result['new_title'] as String?;
    if (leveledUp && newLevel != null && newTitle != null) {
      await showLevelUpDialog(context, newLevel: newLevel, newTitle: newTitle);
    }
  }

  Widget _statChip(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text(
          'FOOD',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
          ),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _analyzing ? null : _onFabTapped,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        child: _analyzing
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: AppColors.onPrimary, strokeWidth: 2.5),
              )
            : const Icon(Icons.camera_alt),
      ),
      body: _analyzing
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text(
                    'Analyzing your meal...',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                  ),
                ],
              ),
            )
          : _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _error != null
                  ? _buildError()
                  : _buildList(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
              child: const Text('RETRY'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_logs.isEmpty) {
      return const Center(
        child: Text(
          'No meals logged yet.\nTap the camera to log your first meal.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: _logs.length,
      itemBuilder: (_, i) => _buildLogCard(_logs[i]),
    );
  }

  Widget _buildLogCard(FoodLog log) {
    final pct = (log.confidence * 100).round();
    final confidenceColor = pct >= 80 ? AppColors.primary : AppColors.warning;

    return Dismissible(
      key: ValueKey(log.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.onPrimary),
      ),
      confirmDismiss: (_) => _confirmDeleteLog(log),
      onDismissed: (_) => _deleteLog(log),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => FoodDetailScreen(log: log)),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        log.items.isEmpty ? 'Unknown meal' : log.items.join(', '),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(log.loggedAt),
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      '${log.calories} kcal',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    Text(
                      '${log.protein.toStringAsFixed(1)}g protein',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    Text(
                      '${log.fat.toStringAsFixed(1)}g fat',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    Text(
                      '${log.carbs.toStringAsFixed(1)}g carbs',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$pct% confidence',
                    style: TextStyle(color: confidenceColor, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDeleteLog(FoodLog log) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete meal?', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          log.items.isEmpty ? 'This meal log will be deleted.' : 'Delete "${log.items.join(', ')}"?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _deleteLog(FoodLog log) async {
    setState(() => _logs.removeWhere((l) => l.id == log.id));
    try {
      await _api.deleteFoodLog(log.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _logs.add(log));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return isToday ? '$h:$m' : '${dt.month}/${dt.day} $h:$m';
  }
}
