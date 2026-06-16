import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../domain/model/food_log.dart';
import 'food_logging_viewmodel.dart';
import '../../data/service/storage_service.dart';

class FoodLoggingScreen extends StatefulWidget {
  const FoodLoggingScreen({super.key});

  @override
  State<FoodLoggingScreen> createState() => _FoodLoggingScreenState();
}

class _FoodLoggingScreenState extends State<FoodLoggingScreen> {
  Uint8List? _selectedImageBytes;
  bool _analyzing = false;

  String _uid() => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final vm = context.read<FoodLoggingViewModel>();
      await vm.changeDate(_uid(), DateTime.now());
    });
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final suffix = date.year != now.year ? ' ${date.year}' : '';
    return '${months[date.month - 1]} ${date.day}$suffix';
  }

  Future<void> _pickDate(FoodLoggingViewModel vm) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: vm.selectedDate,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked != null && mounted) {
      await vm.changeDate(_uid(), picked);
    }
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
    final success = await context
        .read<FoodLoggingViewModel>()
        .analyzeFoodImageAndSave(imageBytes, _uid());

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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) =>
          _EditFoodLogSheet(log: log, userId: _uid(), viewModel: vm),
    );
  }

  // ── Food log card ──────────────────────────────────────────────────────────

  Widget _buildLogCard(FoodLog log, ColorScheme colorScheme) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showEditSheet(log),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Thumbnail
              _FoodThumbnail(imageUrl: log.imageUrl, colorScheme: colorScheme),
              const SizedBox(width: 12),
              // Food info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.foodName,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${log.timestamp.hour}:${log.timestamp.minute.toString().padLeft(2, '0')}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colorScheme.outline),
                    ),
                  ],
                ),
              ),
              // Calories chip
              Chip(
                label: Text('${log.calories} kcal'),
                backgroundColor: colorScheme.secondaryContainer,
                labelStyle: TextStyle(
                  color: colorScheme.onSecondaryContainer,
                  fontSize: 12,
                ),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              // Action icons
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                visualDensity: VisualDensity.compact,
                onPressed: () => _showEditSheet(log),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                visualDensity: VisualDensity.compact,
                onPressed: () => _confirmDelete(log),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(FoodLog log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Meal'),
        content: const Text('Are you sure you want to delete this meal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final vm = context.read<FoodLoggingViewModel>();
              final success = await vm.deleteFoodLog(_uid(), log.id);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content:
                    Text(success ? 'Meal deleted' : 'Failed to delete meal'),
                backgroundColor: success ? Colors.green : Colors.red,
              ));
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Log Food'), centerTitle: true),
      body: Consumer<FoodLoggingViewModel>(
        builder: (context, vm, _) => SingleChildScrollView(
          child: Column(
            children: [
              if (vm.isViewingToday) ...[
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
                          height: 200,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt_outlined,
                                  size: 64, color: colorScheme.outline),
                              const SizedBox(height: 16),
                              Text('No image selected',
                                  style:
                                      TextStyle(color: colorScheme.outline)),
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
                          onPressed:
                              _analyzing ? null : _showImageSourceDialog,
                          icon: _analyzing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.camera_alt),
                          label: Text(_analyzing
                              ? 'Uploading & analyzing…'
                              : 'Select Image'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
              // Daily total
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vm.isViewingToday
                          ? "Today's Total"
                          : '${_formatDate(vm.selectedDate)} Total',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${vm.totalCaloriesForDate} kcal',
                      style:
                          Theme.of(context).textTheme.displaySmall?.copyWith(
                                color: colorScheme.primary,
                              ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Date navigator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => vm.goToPreviousDay(_uid()),
                    ),
                    GestureDetector(
                      onTap: () => _pickDate(vm),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatDate(vm.selectedDate),
                              style:
                                  Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.calendar_today,
                                size: 16, color: colorScheme.primary),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: vm.isViewingToday
                          ? null
                          : () => vm.goToNextDay(_uid()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (vm.isLoading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                )
              else if (vm.foodLogs.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No meals logged',
                    style: TextStyle(color: colorScheme.outline),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: vm.foodLogs.length,
                  itemBuilder: (context, index) =>
                      _buildLogCard(vm.foodLogs[index], colorScheme),
                ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reusable thumbnail widget ──────────────────────────────────────────────

class _FoodThumbnail extends StatelessWidget {
  final String? imageUrl; // This should be the object key/path now
  final ColorScheme colorScheme;
  static final StorageService _storageService = StorageService();

  const _FoodThumbnail({required this.imageUrl, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    const size = 56.0;
    const radius = BorderRadius.all(Radius.circular(8));

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return FutureBuilder<String>(
        future: _storageService.getPrivateImageUrl(imageUrl!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
            return ClipRRect(
              borderRadius: radius,
              child: CachedNetworkImage(
                imageUrl: snapshot.data!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholder: (_, __) => _placeholder(size),
                errorWidget: (_, __, ___) => _placeholder(size),
              ),
            );
          }
          return _placeholder(size);
        },
      );
    }
    return _placeholder(size);
  }

  Widget _placeholder(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: colorScheme.surfaceVariant,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
        child: Icon(Icons.fastfood_outlined,
            size: 28, color: colorScheme.onSurfaceVariant),
      );
}
// ── Edit sheet ─────────────────────────────────────────────────────────────

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

  /// Local preview bytes (shown immediately after picking a new image).
  Uint8List? _previewImageBytes;

  /// URL returned from storage after re-analyze upload — persisted on save.
  String? _newImageUrl;

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
    final source = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Image Source'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'camera'),
              child: const Text('Camera')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'gallery'),
              child: const Text('Gallery')),
        ],
      ),
    );

    if (source == null || !mounted) return;

    final imageBytes = source == 'camera'
        ? await widget.viewModel.captureFromCamera()
        : await widget.viewModel.pickFromGallery();

    if (imageBytes == null || !mounted) return;

    setState(() {
      _analyzing = true;
      _previewImageBytes = imageBytes; // show local preview while uploading
    });

    // reanalyzeImage now also uploads to iDrive e2 and returns the URL.
    final result =
        await widget.viewModel.reanalyzeImage(widget.userId, imageBytes);

    if (!mounted) return;
    setState(() => _analyzing = false);

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to analyze image'),
            backgroundColor: Colors.red),
      );
      return;
    }

    final newName = result['foodName'] as String;
    final newCalories = result['calories'] as int;
    final uploadedUrl = result['imageUrl'] as String?;

    final updateName = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AI Analysis Result'),
        content: Text(
            'Identified: "$newName"\nCalories: $newCalories kcal\n\nUpdate food name too?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No, keep current')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes, update')),
        ],
      ),
    );

    if (!mounted) return;

    setState(() {
      _caloriesController.text = newCalories.toString();
      _newImageUrl = uploadedUrl; // will be persisted on save
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
      imageUrl: _newImageUrl, // null → no change; non-null → update in Firestore
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
    final StorageService storageService = StorageService();

    // Decide which image to display in the sheet:
    // 1. Local bytes (just picked) — highest priority
    // 2. Already-stored network URL
    // 3. Nothing
    Widget? imageWidget;

    if (_previewImageBytes != null) {
      imageWidget = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          _previewImageBytes!,
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    } else if (widget.log.imageUrl != null && widget.log.imageUrl!.isNotEmpty) {
      String objectKey = widget.log.imageUrl!;
      if (objectKey.contains('/finalproject/')) {
        objectKey = objectKey.split('/finalproject/')[1];
      }

      imageWidget = FutureBuilder<String>(
        future: storageService.getPrivateImageUrl(objectKey),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: snapshot.data!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  height: 160,
                  color: colorScheme.surfaceVariant,
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (_, __, ___) => Container(
                  height: 160,
                  color: colorScheme.surfaceVariant,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }
          
          return Container(
            height: 160,
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        },
      );
    }
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
          Row(
            children: [
              Text('Edit Meal',
                  style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: busy ? null : () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (imageWidget != null) ...[
            imageWidget,
            const SizedBox(height: 16),
          ],
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
          OutlinedButton.icon(
            onPressed: busy ? null : _reanalyze,
            icon: _analyzing
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: colorScheme.primary),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(
                _analyzing ? 'Uploading & analyzing…' : 'Re-analyze with new image'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: busy ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save changes'),
          ),
        ],
      ),
    );
  }
}