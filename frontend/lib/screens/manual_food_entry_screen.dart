import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class ManualFoodEntryScreen extends StatefulWidget {
  const ManualFoodEntryScreen({super.key});

  @override
  State<ManualFoodEntryScreen> createState() => _ManualFoodEntryScreenState();
}

class _ManualFoodEntryScreenState extends State<ManualFoodEntryScreen> {
  final _api = ApiService();
  final _picker = ImagePicker();
  final _nameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _fatController = TextEditingController();
  final _carbsController = TextEditingController();

  Uint8List? _photoBytes;
  String? _photoFilename;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    _carbsController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
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
              title: const Text('Camera', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Photo Library', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final xfile = await _picker.pickImage(source: source, imageQuality: 80);
    if (xfile == null || !mounted) return;

    final bytes = await xfile.readAsBytes();
    setState(() {
      _photoBytes = bytes;
      _photoFilename = xfile.name.isNotEmpty ? xfile.name : 'meal_${DateTime.now().millisecondsSinceEpoch}.jpg';
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final calories = double.tryParse(_caloriesController.text.trim());

    if (name.isEmpty || calories == null || calories <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a meal name and a valid calorie amount.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final proteinText = _proteinController.text.trim();
    final fatText = _fatController.text.trim();
    final carbsText = _carbsController.text.trim();
    final protein = proteinText.isEmpty ? null : double.tryParse(proteinText);
    final fat = fatText.isEmpty ? null : double.tryParse(fatText);
    final carbs = carbsText.isEmpty ? null : double.tryParse(carbsText);

    if ((proteinText.isNotEmpty && protein == null) ||
        (fatText.isNotEmpty && fat == null) ||
        (carbsText.isNotEmpty && carbs == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Protein, fat, and carbs must be valid numbers (or left blank).'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final result = await _api.logFoodManual(
        name: name,
        calories: calories,
        proteinG: protein,
        fatG: fat,
        carbsG: carbs,
        imageBytes: _photoBytes,
        filename: _photoFilename,
      );
      if (!mounted) return;
      Navigator.pop(context, result);
    } catch (e) {
      setState(() => _saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to log meal: $e'), backgroundColor: AppColors.error),
      );
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
          'ADD MEAL',
          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GestureDetector(
            onTap: _pickPhoto,
            child: Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: _photoBytes == null
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_a_photo_outlined, color: AppColors.textMuted, size: 36),
                          SizedBox(height: 8),
                          Text('Add photo (optional)', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                        ],
                      ),
                    )
                  : Image.memory(_photoBytes!, fit: BoxFit.cover, width: double.infinity),
            ),
          ),
          const SizedBox(height: 24),
          _buildField('Meal name', _nameController, TextInputType.text),
          const SizedBox(height: 16),
          _buildField('Calories', _caloriesController, const TextInputType.numberWithOptions(decimal: true)),
          const SizedBox(height: 24),
          const Text(
            'MACROS (OPTIONAL)',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildField('Protein (g)', _proteinController, const TextInputType.numberWithOptions(decimal: true)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildField('Fat (g)', _fatController, const TextInputType.numberWithOptions(decimal: true)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildField('Carbs (g)', _carbsController, const TextInputType.numberWithOptions(decimal: true)),
              ),
            ],
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: AppColors.onPrimary, strokeWidth: 2.5),
                    )
                  : const Text('LOG MEAL', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ),
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
}
