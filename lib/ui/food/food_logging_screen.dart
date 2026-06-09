import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
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
                            const SizedBox(width: 8),
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
