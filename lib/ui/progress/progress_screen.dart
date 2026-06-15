import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../domain/model/health_metric.dart';
import 'progress_viewmodel.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      context.read<ProgressViewModel>().loadMetrics(uid);
    });
  }

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  Future<void> _addWaterCups(int cups) async {
    final viewModel = context.read<ProgressViewModel>();
    final success = await viewModel.addWaterCups(_uid, cups);
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(viewModel.errorMessage ?? 'Failed to log water'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showLogWeightModal() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Log Weight', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Weight',
                suffixText: 'kg',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                final weight = double.tryParse(controller.text.trim());
                if (weight == null || weight <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a valid weight'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                final viewModel = context.read<ProgressViewModel>();
                Navigator.pop(context);
                final success = await viewModel.logWeight(_uid, weight);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'Weight logged!' : 'Failed to log weight',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditEntryDialog(HealthMetric metric) {
    final weightController =
        TextEditingController(text: metric.weight?.toStringAsFixed(1) ?? '');
    final waterController =
        TextEditingController(text: metric.waterIntakeMl.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Entry'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Weight (kg)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: waterController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Water Intake (ml)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final viewModel = context.read<ProgressViewModel>();
              final weight = double.tryParse(weightController.text.trim());
              final water = int.tryParse(waterController.text.trim());
              Navigator.pop(context);
              final success = await viewModel.updateMetric(
                _uid,
                metric.id,
                weight: weight,
                waterIntakeMl: water,
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(success ? 'Entry updated' : 'Update failed'),
                  backgroundColor: success ? Colors.green : Colors.red,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteEntry(HealthMetric metric) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final viewModel = context.read<ProgressViewModel>();
              Navigator.pop(context);
              final success = await viewModel.deleteMetric(_uid, metric.id);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(success ? 'Entry deleted' : 'Delete failed'),
                  backgroundColor: success ? Colors.green : Colors.red,
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hydration & Progress'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showLogWeightModal,
        icon: const Icon(Icons.monitor_weight_outlined),
        label: const Text('Log Weight'),
      ),
      body: Consumer<ProgressViewModel>(
        builder: (context, viewModel, _) {
          if (viewModel.isLoading && viewModel.metrics.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () => viewModel.loadMetrics(_uid),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                _WaterSection(
                  intakeMl: viewModel.todayWaterIntakeMl,
                  goalMl: ProgressViewModel.waterGoalMl,
                  intakeCups: viewModel.todayWaterIntakeCups,
                  goalCups: viewModel.waterGoalCups,
                  colorScheme: colorScheme,
                  onAddCups: _addWaterCups,
                ),
                const SizedBox(height: 24),
                _CaloriesSection(
                  calories: viewModel.todayCalories,
                  colorScheme: colorScheme,
                ),
                const SizedBox(height: 24),
                _WeightChartSection(
                  history: viewModel.weightHistory,
                  colorScheme: colorScheme,
                ),
                const SizedBox(height: 24),
                Text(
                  'History',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (viewModel.metrics.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'No entries yet',
                        style: TextStyle(color: colorScheme.outline),
                      ),
                    ),
                  )
                else
                  ...viewModel.metrics.map(
                    (metric) => Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(
                          '${metric.date.year}-${metric.date.month.toString().padLeft(2, '0')}-${metric.date.day.toString().padLeft(2, '0')}',
                        ),
                        subtitle: Text(
                          '${metric.weight != null ? '${metric.weight!.toStringAsFixed(1)} kg  ·  ' : ''}${metric.waterIntakeMl} ml water',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _showEditEntryDialog(metric),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _confirmDeleteEntry(metric),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WaterSection extends StatefulWidget {
  const _WaterSection({
    required this.intakeMl,
    required this.goalMl,
    required this.intakeCups,
    required this.goalCups,
    required this.colorScheme,
    required this.onAddCups,
  });

  final int intakeMl;
  final int goalMl;
  final double intakeCups;
  final int goalCups;
  final ColorScheme colorScheme;
  final void Function(int cups) onAddCups;

  @override
  State<_WaterSection> createState() => _WaterSectionState();
}

class _WaterSectionState extends State<_WaterSection> {
  int _cupsToAdd = 1;

  @override
  Widget build(BuildContext context) {
    final progress = (widget.intakeMl / widget.goalMl).clamp(0.0, 1.0);
    final colorScheme = widget.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Hydration', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 10,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      color: colorScheme.primary,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${widget.intakeCups.toStringAsFixed(1)} cups',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        'of ${widget.goalCups} cups',
                        style: TextStyle(color: colorScheme.outline),
                      ),
                      Text(
                        '${widget.intakeMl} / ${widget.goalMl} ml',
                        style: TextStyle(
                          color: colorScheme.outline,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _cupsToAdd > 1
                      ? () => setState(() => _cupsToAdd--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  '$_cupsToAdd cup${_cupsToAdd > 1 ? 's' : ''}'
                  ' (${_cupsToAdd * ProgressViewModel.cupSizeMl} ml)',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                IconButton(
                  onPressed: _cupsToAdd < 10
                      ? () => setState(() => _cupsToAdd++)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => widget.onAddCups(_cupsToAdd),
                icon: const Icon(Icons.water_drop_outlined),
                label: Text(
                  'Add $_cupsToAdd cup${_cupsToAdd > 1 ? 's' : ''} of water',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaloriesSection extends StatelessWidget {
  const _CaloriesSection({required this.calories, required this.colorScheme});

  final int calories;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.local_fire_department,
                color: Colors.orange,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Today\'s Calories',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$calories kcal',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeightChartSection extends StatelessWidget {
  const _WeightChartSection({required this.history, required this.colorScheme});

  final List<HealthMetric> history;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Weight Trend', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: history.length < 2
                  ? Center(
                      child: Text(
                        'Log your weight on at least 2 days to see a trend',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colorScheme.outline),
                      ),
                    )
                  : LineChart(_buildChartData()),
            ),
          ],
        ),
      ),
    );
  }

  LineChartData _buildChartData() {
    final spots = <FlSpot>[
      for (var i = 0; i < history.length; i++)
        FlSpot(i.toDouble(), history[i].weight!),
    ];

    final weights = history.map((m) => m.weight!).toList();
    final minWeight = weights.reduce((a, b) => a < b ? a : b);
    final maxWeight = weights.reduce((a, b) => a > b ? a : b);
    final padding = (maxWeight - minWeight).abs() < 1 ? 1.0 : (maxWeight - minWeight) * 0.2;

    return LineChartData(
      minY: minWeight - padding,
      maxY: maxWeight + padding,
      gridData: const FlGridData(show: true),
      titlesData: FlTitlesData(
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= history.length) return const SizedBox.shrink();
              final date = history[index].date;
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${date.month}/${date.day}',
                  style: const TextStyle(fontSize: 10),
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: true, reservedSize: 40),
        ),
      ),
      borderData: FlBorderData(show: true),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: colorScheme.primary,
          barWidth: 3,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            color: colorScheme.primary.withValues(alpha: 0.15),
          ),
        ),
      ],
    );
  }
}
