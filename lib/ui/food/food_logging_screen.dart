import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../domain/model/food_log.dart';
import 'food_logging_viewmodel.dart';

class FoodLoggingScreen extends StatefulWidget {
  const FoodLoggingScreen({super.key});

  @override
  State<FoodLoggingScreen> createState() => _FoodLoggingScreenState();
}

class _FoodLoggingScreenState extends State<FoodLoggingScreen> {
  Uint8List? _selectedImageBytes;
  bool _analyzing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      context.read<FoodLoggingViewModel>().loadFoodLogs(uid);
    });
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Image Source'),
        content: const Text('Choose where to get the food image'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final imageBytes =
                  await context.read<FoodLoggingViewModel>().captureFromCamera();
              if (imageBytes != null) {
                setState(() => _selectedImageBytes = imageBytes);
                await _analyzeFood(imageBytes);
              }
            },
            child: const Text('Camera'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final imageBytes =
                  await context.read<FoodLoggingViewModel>().pickFromGallery();
              if (imageBytes != null) {
                setState(() => _selectedImageBytes = imageBytes);
                await _analyzeFood(imageBytes);
              }
            },
            child: const Text('Gallery'),
          ),
        ],
      ),
    );
  }

  Future<void> _analyzeFood(Uint8List imageBytes) async {
    setState(() => _analyzing = true);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final success = await context
        .read<FoodLoggingViewModel>()
        .analyzeFoodImageAndSave(imageBytes, uid);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Food logged successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        _selectedImageBytes = null;
        _analyzing = false;
      });
    } else {
      setState(() => _analyzing = false);
      final errorMsg = context.read<FoodLoggingViewModel>().errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg ?? 'Failed to analyze food'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showEditSheet(FoodLog log) {
    final vm = context.read<FoodLoggingViewModel>();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _EditFoodLogSheet(
        log: log,
        userId: uid,
        viewModel: vm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Food'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outline),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _selectedImageBytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(_selectedImageBytes!),
                    )
                  : Container(
                      height: 300,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            size: 64,
                            color: colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No image selected',
                            style: TextStyle(color: colorScheme.outline),
                          ),
                        ],
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _analyzing ? null : _showImageSourceDialog,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Select Image'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Consumer<FoodLoggingViewModel>(
              builder: (context, viewModel, _) => Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s Total',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${viewModel.totalCaloriesToday} kcal',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: colorScheme.primary,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Today\'s Meals',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Consumer<FoodLoggingViewModel>(
              builder: (context, viewModel, _) {
                if (viewModel.isLoading) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  );
                }

                if (viewModel.foodLogs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No meals logged yet',
                      style: TextStyle(color: colorScheme.outline),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: viewModel.foodLogs.length,
                  itemBuilder: (context, index) {
                    final log = viewModel.foodLogs[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        title: Text(log.foodName),
                        subtitle: Text(
                          '${log.timestamp.hour}:${log.timestamp.minute.toString().padLeft(2, '0')}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Chip(
                              label: Text('${log.calories} kcal'),
                              backgroundColor: colorScheme.secondaryContainer,
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _showEditSheet(log),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Meal'),
                                    content: const Text(
                                      'Are you sure you want to delete this meal?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          Navigator.pop(context);
                                          final uid = FirebaseAuth
                                              .instance.currentUser!.uid;
                                          final success = await viewModel
                                              .deleteFoodLog(uid, log.id);
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                success
                                                    ? 'Meal deleted'
                                                    : 'Failed to delete meal',
                                              ),
                                              backgroundColor: success
                                                  ? Colors.green
                                                  : Colors.red,
                                            ),
                                          );
                                        },
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _EditFoodLogSheet extends StatefulWidget {
  final FoodLog log;
  final String userId;
  final FoodLoggingViewModel viewModel;

  const _EditFoodLogSheet({
    required this.log,
    required this.userId,
    required this.viewModel,
  });

  @override
  State<_EditFoodLogSheet> createState() => _EditFoodLogSheetState();
}

class _EditFoodLogSheetState extends State<_EditFoodLogSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _caloriesController;
  Uint8List? _previewImageBytes;
  bool _analyzing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.log.foodName);
    _caloriesController =
        TextEditingController(text: widget.log.calories.toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  Future<void> _reanalyze() async {
    // 1. Pick image source
    final source = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Image Source'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'camera'),
            child: const Text('Camera'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'gallery'),
            child: const Text('Gallery'),
          ),
        ],
      ),
    );

    if (source == null || !mounted) return;

    // 2. Pick image
    final imageBytes = source == 'camera'
        ? await widget.viewModel.captureFromCamera()
        : await widget.viewModel.pickFromGallery();

    if (imageBytes == null || !mounted) return;

    setState(() {
      _analyzing = true;
      _previewImageBytes = imageBytes;
    });

    // 3. Analyze
    final result = await widget.viewModel.reanalyzeImage(imageBytes);

    if (!mounted) return;
    setState(() => _analyzing = false);

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to analyze image'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final newName = result['foodName'] as String;
    final newCalories = result['calories'] as int;

    // 4. Ask about name update
    final updateName = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AI Analysis Result'),
        content: Text(
          'Identified: "$newName"\nCalories: $newCalories kcal\n\nUpdate food name too?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No, keep current'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, update'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    // 5. Apply results — calories always updated, name conditionally
    setState(() {
      _caloriesController.text = newCalories.toString();
      if (updateName == true) _nameController.text = newName;
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final calories = int.tryParse(_caloriesController.text.trim());

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Food name cannot be empty')),
      );
      return;
    }
    if (calories == null || calories < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid calorie amount')),
      );
      return;
    }

    setState(() => _saving = true);

    final success = await widget.viewModel.updateFoodLog(
      widget.userId,
      widget.log.id,
      foodName: name,
      calories: calories,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.viewModel.errorMessage ?? 'Failed to save'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final busy = _analyzing || _saving;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Text('Edit Meal', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: busy ? null : () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // New image preview (only shown after re-analysis)
          if (_previewImageBytes != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                _previewImageBytes!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Food name
          TextField(
            controller: _nameController,
            enabled: !busy,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Food name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          // Calories
          TextField(
            controller: _caloriesController,
            enabled: !busy,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Calories (kcal)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Re-analyze button
          OutlinedButton.icon(
            onPressed: busy ? null : _reanalyze,
            icon: _analyzing
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(_analyzing ? 'Analyzing…' : 'Re-analyze with new image'),
          ),
          const SizedBox(height: 8),

          // Save button
          FilledButton(
            onPressed: busy ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Save changes'),
          ),
        ],
      ),
    );
  }
}