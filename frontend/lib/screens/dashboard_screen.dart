import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/quest.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/trophy_badge.dart';
import '../widgets/level_up_dialog.dart';
import 'settings_screen.dart';
import 'trophy_tiers_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _api = ApiService();

  User? _user;
  List<UserQuest> _quests = [];
  bool _loading = true;
  String? _error;
  int _avatarCacheBust = 0;

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
      final results = await Future.wait([_api.getUser(), _api.getTodayQuests()]);
      setState(() {
        _user = results[0] as User;
        _quests = results[1] as List<UserQuest>;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _completeQuest(UserQuest quest) async {
    try {
      final result = await _api.completeQuest(quest.id);
      final leveledUp = result['leveled_up'] as bool? ?? false;
      final newLevel = result['new_level'] as int?;
      final newTitle = result['new_title'] as String?;

      await _loadData();

      if (!mounted) return;

      if (leveledUp && newLevel != null && newTitle != null) {
        await showLevelUpDialog(context, newLevel: newLevel, newTitle: newTitle);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('+${quest.xpReward} XP earned!'),
            backgroundColor: AppColors.primaryDark,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _uncompleteQuest(UserQuest quest) async {
    try {
      final result = await _api.uncompleteQuest(quest.id);
      final xpRevoked = result['xp_revoked'] as int? ?? quest.xpReward;

      await _loadData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Quest undone — -$xpRevoked XP'),
          backgroundColor: AppColors.primaryDark,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  List<String>? _categories;

  static const Map<String, IconData> _categoryIcons = {
    'walking': Icons.directions_walk,
    'running': Icons.directions_run,
    'swimming': Icons.pool,
    'diet': Icons.restaurant,
    'hiking': Icons.terrain,
  };

  Future<void> _openReplaceSheet(UserQuest quest) async {
    _categories ??= await _api.getQuestCategories().catchError((_) => <String>[]);
    if (!mounted) return;

    final options = (_categories ?? []).where((c) => c != quest.questType).toList();

    final selected = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'REPLACE QUEST',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 13),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome, color: AppColors.primary),
                title: const Text('Surprise me', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () => Navigator.pop(sheetCtx, ''),
              ),
              for (final category in options)
                ListTile(
                  leading: Icon(_categoryIcons[category] ?? Icons.fitness_center, color: AppColors.primary),
                  title: Text(_categoryLabel(category), style: const TextStyle(color: AppColors.textPrimary)),
                  onTap: () => Navigator.pop(sheetCtx, category),
                ),
            ],
          ),
        ),
      ),
    );

    if (selected == null || !mounted) return;
    await _replaceQuest(quest, selected.isEmpty ? null : selected);
  }

  String _categoryLabel(String category) {
    if (category.isEmpty) return category;
    return category[0].toUpperCase() + category.substring(1);
  }

  Future<void> _replaceQuest(UserQuest quest, String? preferredCategory) async {
    try {
      final updated = await _api.replaceQuest(quest.id, preferredCategory: preferredCategory);
      setState(() {
        _quests = [
          for (final q in _quests) q.id == quest.id ? updated : q,
        ];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to replace quest: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Color _rarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'rare':
        return AppColors.rarityRare;
      case 'epic':
        return AppColors.rarityEpic;
      case 'legendary':
        return AppColors.rarityLegendary;
      default:
        return AppColors.rarityCommon;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0.5,
        title: const Text(
          'REFORGE',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              if (!mounted) return;
              setState(() => _avatarCacheBust++);
              _loadData();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
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
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  onRefresh: _loadData,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _buildHeader()),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                          child: Text(
                            "TODAY'S QUESTS",
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildQuestCard(_quests[index]),
                          childCount: _quests.length,
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader() {
    final user = _user!;
    final xpPerLevel = user.level * 100;
    final xpIntoLevel = user.xp % xpPerLevel;
    final progress = (xpIntoLevel / xpPerLevel).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildAvatar(user),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Level ${user.level} · ${user.title}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TrophyTiersScreen(currentLevel: user.level)),
                ),
                child: TrophyBadge(title: user.title, size: 64),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('XP', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              Text(
                '${user.xp} XP',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.surfaceAlt,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(User user) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        '${ApiService.userPhotoUrl(user.id)}?v=$_avatarCacheBust',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.person, color: AppColors.primary, size: 26),
      ),
    );
  }

  Widget _buildQuestCard(UserQuest quest) {
    final rarityColor = _rarityColor(quest.rarity);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: rarityColor, width: 4)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            quest.title,
                            style: TextStyle(
                              color: quest.completed ? AppColors.textFaint : AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              decoration: quest.completed
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                        ),
                        if (quest.completed && quest.autoCompleted) ...[
                          const SizedBox(width: 6),
                          const Tooltip(
                            message: 'Auto-completed from your logged food',
                            child: Icon(Icons.auto_awesome, color: AppColors.textFaint, size: 14),
                          ),
                        ],
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: rarityColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: rarityColor.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            quest.rarity.toUpperCase(),
                            style: TextStyle(
                              color: rarityColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      quest.description,
                      style: TextStyle(
                        color: quest.completed ? AppColors.textFaint : AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '+${quest.xpReward} XP',
                      style: TextStyle(
                        color: quest.completed ? AppColors.textFaint : AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              quest.completed
                  ? GestureDetector(
                      onTap: () => _uncompleteQuest(quest),
                      child: const Icon(Icons.check_circle, color: AppColors.primary, size: 32),
                    )
                  : Column(
                      children: [
                        GestureDetector(
                          onTap: () => _completeQuest(quest),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.textFaint, width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => _openReplaceSheet(quest),
                          child: const Icon(Icons.swap_horiz, color: AppColors.textMuted, size: 20),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
