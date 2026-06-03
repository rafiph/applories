import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../auth/auth_viewmodel.dart';
import 'profile_viewmodel.dart';
import '../../domain/model/user_profile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  String _gender = 'Male';
  bool _populated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      context.read<ProfileViewModel>().loadProfile(uid);
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  // Called by Consumer when profile finishes loading — fills form once.
  void _populateIfNeeded(UserProfile? profile) {
    if (_populated || profile == null) return;
    _populated = true;
    _nameCtrl.text = profile.name;
    _ageCtrl.text = profile.age > 0 ? profile.age.toString() : '';
    _weightCtrl.text = profile.weight > 0 ? profile.weight.toString() : '';
    _heightCtrl.text = profile.height > 0 ? profile.height.toString() : '';
    setState(() => _gender = profile.gender);
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final profile = UserProfile(
      name: _nameCtrl.text.trim(),
      age: int.parse(_ageCtrl.text.trim()),
      gender: _gender,
      weight: double.parse(_weightCtrl.text.trim()),
      height: double.parse(_heightCtrl.text.trim()),
    );
    final success =
        await context.read<ProfileViewModel>().saveProfile(uid, profile);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Profile saved!' : 'Failed to save. Try again.'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  void _openFeature(String name) {
    // TODO: navigate to actual feature screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name — coming soon!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Applories'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => context.read<AuthViewModel>().signOut(),
          ),
        ],
      ),
      body: Consumer<ProfileViewModel>(
        builder: (context, vm, _) {
          if (!_populated && vm.profile != null) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _populateIfNeeded(vm.profile),
            );
          }

          return vm.isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Greeting
                      Text(
                        vm.profile?.name.isNotEmpty == true
                            ? '$_greeting, ${vm.profile!.name}!'
                            : '$_greeting!',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        user?.email ?? '',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 13),
                      ),

                      const SizedBox(height: 20),

                      // ── Profile Card ──────────────────────────────
                      _SectionLabel(
                          label: 'Your Profile', icon: Icons.person_outline),
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                // Name
                                TextFormField(
                                  controller: _nameCtrl,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Name',
                                    prefixIcon: Icon(Icons.badge_outlined),
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'Required'
                                          : null,
                                ),
                                const SizedBox(height: 12),

                                // Age + Gender
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _ageCtrl,
                                        keyboardType: TextInputType.number,
                                        textInputAction: TextInputAction.next,
                                        decoration: const InputDecoration(
                                          labelText: 'Age',
                                          border: OutlineInputBorder(),
                                          suffixText: 'yr',
                                        ),
                                        validator: (v) {
                                          if (v == null || v.isEmpty) {
                                            return 'Required';
                                          }
                                          if (int.tryParse(v) == null) {
                                            return 'Invalid';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        initialValue: _gender,
                                        decoration: const InputDecoration(
                                          labelText: 'Gender',
                                          border: OutlineInputBorder(),
                                        ),
                                        items: const [
                                          DropdownMenuItem(
                                              value: 'Male',
                                              child: Text('Male')),
                                          DropdownMenuItem(
                                              value: 'Female',
                                              child: Text('Female')),
                                        ],
                                        onChanged: (v) => setState(
                                            () => _gender = v ?? 'Male'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Weight + Height
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _weightCtrl,
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        textInputAction: TextInputAction.next,
                                        decoration: const InputDecoration(
                                          labelText: 'Weight',
                                          border: OutlineInputBorder(),
                                          suffixText: 'kg',
                                        ),
                                        validator: (v) {
                                          if (v == null || v.isEmpty) {
                                            return 'Required';
                                          }
                                          if (double.tryParse(v) == null) {
                                            return 'Invalid';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _heightCtrl,
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        textInputAction: TextInputAction.done,
                                        onFieldSubmitted: (_) => _saveProfile(),
                                        decoration: const InputDecoration(
                                          labelText: 'Height',
                                          border: OutlineInputBorder(),
                                          suffixText: 'cm',
                                        ),
                                        validator: (v) {
                                          if (v == null || v.isEmpty) {
                                            return 'Required';
                                          }
                                          if (double.tryParse(v) == null) {
                                            return 'Invalid';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Save button
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed:
                                        vm.isSaving ? null : _saveProfile,
                                    icon: vm.isSaving
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white),
                                          )
                                        : const Icon(Icons.save_outlined),
                                    label: Text(
                                        vm.isSaving ? 'Saving…' : 'Save Profile'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Features ──────────────────────────────────
                      _SectionLabel(label: 'Features', icon: Icons.apps),
                      const SizedBox(height: 12),

                      _FeatureCard(
                        icon: Icons.local_fire_department,
                        color: Colors.orange,
                        title: 'AI Calorie Counter',
                        subtitle: 'Snap a photo to log your meals with AI',
                        onTap: () => _openFeature('AI Calorie Counter'),
                      ),
                      const SizedBox(height: 12),

                      _FeatureCard(
                        icon: Icons.fitness_center,
                        color: colorScheme.primary,
                        title: 'Workout Planner',
                        subtitle: 'Get a personalized weekly fitness plan',
                        onTap: () => _openFeature('Workout Planner'),
                      ),
                      const SizedBox(height: 12),

                      _FeatureCard(
                        icon: Icons.water_drop,
                        color: Colors.cyan.shade600,
                        title: 'Hydration & Progress',
                        subtitle: 'Track water intake and body metrics',
                        onTap: () => _openFeature('Hydration & Progress'),
                      ),
                    ],
                  ),
                );
        },
      ),
    );
  }
}

// ── Reusable widgets ────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Text(label,
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
