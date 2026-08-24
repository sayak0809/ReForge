import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/trophy_badge.dart';

class _SlideData {
  final IconData? icon;
  final Widget? illustration;
  final String title;
  final String description;

  const _SlideData({this.icon, this.illustration, required this.title, required this.description});
}

const _walkthroughSlides = [
  _SlideData(
    icon: Icons.auto_awesome,
    title: 'Welcome to Reforge',
    description: 'Real life becomes a game. Log food, complete quests, and level up as you build real habits.',
  ),
  _SlideData(
    icon: Icons.checklist_rtl,
    title: 'AI Builds Your Quests',
    description:
        'Every day you get 3 quests — walking, running, swimming, diet, or hiking — tailored to your level. '
        'Not feeling one? Swap it for something else with a tap.',
  ),
  _SlideData(
    icon: Icons.camera_alt_outlined,
    title: 'Snap a Photo, Get Macros',
    description:
        'Point your camera at a meal and AI estimates calories, protein, fat, and carbs. '
        'Prefer to type it in? Manual entry works too.',
  ),
  _SlideData(
    icon: Icons.psychology_outlined,
    title: 'Talk to Coach',
    description:
        'Your AI coach can see your real data — level, meals, weight trend, quest history — '
        'and gives advice built around it, not generic tips.',
  ),
  _SlideData(
    illustration: TrophyBadge(title: 'Legend', size: 88),
    title: 'Earn XP, Collect Trophies',
    description:
        'Every quest, meal, and weigh-in earns XP. Level up through six trophy tiers, '
        'from Novice all the way to Legend.',
  ),
];

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _api = ApiService();
  final _pageController = PageController();

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _goalWeightController = TextEditingController();

  int _pageIndex = 0;
  bool _submitting = false;

  int get _totalPages => 1 + _walkthroughSlides.length;
  bool get _onFormPage => _pageIndex == 0;
  bool get _onLastPage => _pageIndex == _totalPages - 1;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _goalWeightController.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _handleNext() {
    if (_onFormPage && !_validateForm()) return;
    if (_onLastPage) {
      _finish();
      return;
    }
    _goToPage(_pageIndex + 1);
  }

  bool _validateForm() {
    final age = int.tryParse(_ageController.text.trim());
    final height = double.tryParse(_heightController.text.trim());
    final weight = double.tryParse(_weightController.text.trim());
    final goalWeight = double.tryParse(_goalWeightController.text.trim());

    if (_nameController.text.trim().isEmpty || age == null || height == null || weight == null || goalWeight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in every field with a valid value.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _finish() async {
    setState(() => _submitting = true);
    try {
      await _api.createUser(
        name: _nameController.text.trim(),
        age: int.parse(_ageController.text.trim()),
        heightCm: double.parse(_heightController.text.trim()),
        currentWeight: double.parse(_weightController.text.trim()),
        goalWeight: double.parse(_goalWeightController.text.trim()),
      );
      widget.onComplete();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to set up your profile: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _pageIndex = i),
                children: [
                  _buildFormPage(),
                  for (final slide in _walkthroughSlides) _buildSlidePage(slide),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildFormPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'REFORGE',
            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, letterSpacing: 3, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            "Let's set you up",
            style: TextStyle(color: AppColors.textPrimary, fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'A few details so quests and Coach can be built around you.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 28),
          _buildField('First name', _nameController, TextInputType.text),
          const SizedBox(height: 16),
          _buildField('Age', _ageController, TextInputType.number),
          const SizedBox(height: 16),
          _buildField('Height (cm)', _heightController, const TextInputType.numberWithOptions(decimal: true)),
          const SizedBox(height: 16),
          _buildField('Current weight (kg)', _weightController, const TextInputType.numberWithOptions(decimal: true)),
          const SizedBox(height: 16),
          _buildField('Goal weight (kg)', _goalWeightController, const TextInputType.numberWithOptions(decimal: true)),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, TextInputType keyboardType) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceAlt,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSlidePage(_SlideData slide) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (slide.illustration != null)
            slide.illustration!
          else
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(color: AppColors.surfaceAlt, shape: BoxShape.circle),
              child: Icon(slide.icon, color: AppColors.primary, size: 40),
            ),
          const SizedBox(height: 32),
          Text(
            slide.title,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            slide.description,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < _totalPages; i++)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _pageIndex ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _pageIndex ? AppColors.primary : AppColors.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (!_onFormPage)
                TextButton(
                  onPressed: _submitting ? null : () => _goToPage(_pageIndex - 1),
                  child: const Text('Back', style: TextStyle(color: AppColors.textSecondary)),
                ),
              const Spacer(),
              SizedBox(
                width: 140,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _handleNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: AppColors.onPrimary, strokeWidth: 2.5),
                        )
                      : Text(
                          _onLastPage ? 'Get Started' : (_onFormPage ? 'Continue' : 'Next'),
                          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
