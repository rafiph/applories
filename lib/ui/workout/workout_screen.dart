import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../home/profile_viewmodel.dart';
import '../../data/service/exercise_library.dart';
import '../../data/service/workout_generator.dart';
import '../../domain/model/user_profile.dart';
import '../../domain/model/workout_plan.dart';
import 'workout_viewmodel.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkoutViewModel>().loadActivePlan(_uid);
    });
  }

  UserProfile _profileOrFallback() {
    final p = context.read<ProfileViewModel>().profile;
    return p ??
        const UserProfile(
          name: '',
          age: 30,
          gender: 'Male',
          weight: 70,
          height: 170,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Planner'),
        actions: [
          Consumer<WorkoutViewModel>(
            builder: (context, vm, _) {
              if (!vm.hasActivePlan) return const SizedBox.shrink();
              return PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'regenerate') {
                    await _confirmRegenerate(vm);
                  } else if (value == 'clear') {
                    await _confirmClear(vm);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'regenerate',
                    child: ListTile(
                      leading: Icon(Icons.refresh),
                      title: Text('Regenerate plan'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'clear',
                    child: ListTile(
                      leading: Icon(Icons.delete_forever, color: Colors.red),
                      title: Text('Clear plan'),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<WorkoutViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!vm.hasActivePlan) {
            return _EmptyState(onCreate: (weeks) => _create(vm, weeks));
          }
          return _PlanView(plan: vm.activePlan!, uid: _uid);
        },
      ),
    );
  }


  Future<void> _create(WorkoutViewModel vm, int weeks) async {
    final ok = await vm.generateAndSave(
      uid: _uid,
      profile: _profileOrFallback(),
      goal: WorkoutGoal.weightLoss,
      weeks: weeks,
    );
    if (!mounted) return;
    _snack(ok ? 'Your plan is ready!' : 'Could not generate. Try again.', ok);
  }

  Future<void> _confirmRegenerate(WorkoutViewModel vm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Regenerate plan?'),
        content: const Text(
            'This will replace your current plan with a new one.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await vm.regeneratePlan(
      uid: _uid,
      profile: _profileOrFallback(),
      goal: WorkoutGoal.weightLoss,
    );
    if (!mounted) return;
    _snack(ok ? 'Plan regenerated!' : 'Failed to regenerate.', ok);
  }

  Future<void> _confirmClear(WorkoutViewModel vm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear entire plan?'),
        content: const Text(
            'This deletes your active workout plan. You can generate a new one afterwards.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await vm.deletePlan(_uid);
    if (!mounted) return;
    _snack(ok ? 'Plan cleared.' : 'Failed to clear.', ok);
  }

  void _snack(String msg, bool ok) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? Colors.green : Colors.red,
    ));
  }
}

class _EmptyState extends StatefulWidget {
  const _EmptyState({required this.onCreate});
  final void Function(int weeks) onCreate;

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState> {
  int _weeks = 4;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WorkoutViewModel>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Icon(Icons.fitness_center,
              size: 72, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text('No active plan yet',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Generate a personalized plan based on your profile.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Goal',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Weight Loss', style: TextStyle(fontSize: 16)),
                  const Divider(),
                  const Text('Plan length (Week/s)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 1, label: Text('1')),
                      ButtonSegment(value: 2, label: Text('2')),
                      ButtonSegment(value: 4, label: Text('4')),
                    ],
                    selected: {_weeks},
                    onSelectionChanged: (s) =>
                        setState(() => _weeks = s.first),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  vm.isSaving ? null : () => widget.onCreate(_weeks),
              icon: vm.isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.health_and_safety_outlined),
              label: Text(vm.isSaving ? 'Generating…' : 'Generate Plan'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanView extends StatelessWidget {
  const _PlanView({required this.plan, required this.uid});
  final WorkoutPlan plan;
  final String uid;

  @override
  Widget build(BuildContext context) {
    // Group days into weeks for readability.
    final weeks = <int, List<WorkoutDay>>{};
    for (final d in plan.workoutDays) {
      final weekIndex = (d.dayNumber - 1) ~/ 7;
      weeks.putIfAbsent(weekIndex, () => []).add(d);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _ProgressHeader(plan: plan),
        const SizedBox(height: 16),
        for (final entry in weeks.entries) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Week ${entry.key + 1}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          ...entry.value.map((d) => _DayCard(day: d, uid: uid)),
        ],
      ],
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.plan});
  final WorkoutPlan plan;

  @override
  Widget build(BuildContext context) {
    final pct = (plan.progress * 100).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(plan.goal,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                Text('${plan.durationWeeks}-week plan',
                    style: const TextStyle(color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: plan.progress,
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 6),
            Text(
                '$pct% complete · ${plan.completedExercises}/${plan.totalExercises} exercises',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.uid});
  final WorkoutDay day;
  final String uid;

  @override
  Widget build(BuildContext context) {
    final vm = context.read<WorkoutViewModel>();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        shape: const Border(), // remove the default divider lines
        leading: CircleAvatar(
          backgroundColor: day.isCompleted
              ? Colors.green
              : Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
          child: day.isCompleted
              ? const Icon(Icons.check, color: Colors.white)
              : Text('${day.dayNumber}',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold)),
        ),
        title: Text('Day ${day.dayNumber} · ${day.focus}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(day.isRestDay
            ? 'Rest day'
            : '${day.completedExercisesCount}/${day.exercises.length} done'),
        children: [
          if (day.isRestDay)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Recovery day — take it easy.',
                    style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ...day.exercises.map((e) => _ExerciseTile(
                  day: day,
                  exercise: e,
                  uid: uid,
                )),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _showAddExercise(context, vm),
                icon: const Icon(Icons.add),
                label: const Text('Add exercise'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddExercise(BuildContext context, WorkoutViewModel vm) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddExerciseSheet(
        onAdd: (name, exerciseGroup, sets, reps) {
          vm.addCustomExercise(
            uid: uid,
            dayNumber: day.dayNumber,
            name: name,
            exerciseGroup: exerciseGroup,
            sets: sets,
            reps: reps,
          );
        },
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({
    required this.day,
    required this.exercise,
    required this.uid,
  });
  final WorkoutDay day;
  final Exercise exercise;
  final String uid;

  @override
  Widget build(BuildContext context) {
    final vm = context.read<WorkoutViewModel>();
    return Dismissible(
      key: ValueKey('${day.dayNumber}_${exercise.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => vm.deleteExercise(
        uid: uid,
        dayNumber: day.dayNumber,
        exerciseId: exercise.id,
      ),
      child: CheckboxListTile(
        controlAffinity: ListTileControlAffinity.leading,
        value: exercise.completed,
        onChanged: (v) => vm.setExerciseCompleted(
          uid: uid,
          dayNumber: day.dayNumber,
          exerciseId: exercise.id,
          completed: v ?? false,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                exercise.name,
                style: TextStyle(
                  decoration:
                      exercise.completed ? TextDecoration.lineThrough : null,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (exercise.isCustom)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('custom',
                    style: TextStyle(fontSize: 10, color: Colors.purple)),
              ),
          ],
        ),
        subtitle: Text(
            '${exercise.exerciseGroup} · ${exercise.sets} sets × ${exercise.reps} reps'),
        secondary: IconButton(
          icon: const Icon(Icons.edit, size: 20),
          tooltip: 'Edit sets/reps',
          onPressed: () => _showEdit(context, vm),
        ),
      ),
    );
  }

  void _showEdit(BuildContext context, WorkoutViewModel vm) {
    final setsCtrl = TextEditingController(text: exercise.sets.toString());
    final repsCtrl = TextEditingController(text: exercise.reps.toString());
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Edit ${exercise.name}'),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: setsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Sets', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: repsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Reps', border: OutlineInputBorder()),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              vm.editExercise(
                uid: uid,
                dayNumber: day.dayNumber,
                exerciseId: exercise.id,
                sets: int.tryParse(setsCtrl.text),
                reps: int.tryParse(repsCtrl.text),
              );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _AddExerciseSheet extends StatefulWidget {
  const _AddExerciseSheet({required this.onAdd});
  final void Function(String name, String exerciseGroup, int sets, int reps)
      onAdd;

  @override
  State<_AddExerciseSheet> createState() => _AddExerciseSheetState();
}

class _AddExerciseSheetState extends State<_AddExerciseSheet> {
  final _nameCtrl = TextEditingController();
  final _setsCtrl = TextEditingController(text: '3');
  final _repsCtrl = TextEditingController(text: '12');
  String _exerciseGroup = ExerciseLibrary.focuses.first;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _setsCtrl.dispose();
    _repsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Add custom exercise',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
                labelText: 'Exercise name', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _exerciseGroup,
            decoration: const InputDecoration(
                labelText: 'Exercise group', border: OutlineInputBorder()),
            items: ExerciseLibrary.focuses
                .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                .toList(),
            onChanged: (v) => setState(() => _exerciseGroup = v!),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _setsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Sets', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _repsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Reps', border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              final name = _nameCtrl.text.trim();
              if (name.isEmpty) return;
              widget.onAdd(
                name,
                _exerciseGroup,
                int.tryParse(_setsCtrl.text) ?? 3,
                int.tryParse(_repsCtrl.text) ?? 12,
              );
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}