import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/japa_provider.dart';
import '../../providers/sankalp_provider.dart';
import '../../services/sankalp_engine.dart';
import '../../widgets/section_card.dart';

class SankalpScreen extends ConsumerStatefulWidget {
  const SankalpScreen({super.key});

  @override
  ConsumerState<SankalpScreen> createState() => _SankalpScreenState();
}

class _SankalpScreenState extends ConsumerState<SankalpScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mantra = ref.read(japaProvider).activeMantra;
      if (mantra != null) {
        ref.read(sankalpProvider).loadForMantra(mantra.id!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final japa = ref.watch(japaProvider);
    final sankalp = ref.watch(sankalpProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Sankalp (Vow)')),
      body: SafeArea(
        child: sankalp.isLoading
            ? const Center(child: CircularProgressIndicator())
            : sankalp.engine != null
                ? _SankalpProgress(engine: sankalp.engine!, isDark: isDark)
                : _CreateSankalpForm(
                    mantraName: japa.activeMantra?.name ?? 'Mantra',
                    onSubmit: (goal, start, end) {
                      if (japa.activeMantra != null) {
                        ref.read(sankalpProvider).createSankalp(
                              mantraId: japa.activeMantra!.id!,
                              totalGoal: goal,
                              startDate: start,
                              endDate: end,
                            );
                      }
                    },
                  ),
      ),
    );
  }
}

class _SankalpProgress extends StatefulWidget {
  final SankalpEngine engine;
  final bool isDark;

  const _SankalpProgress({required this.engine, required this.isDark});

  @override
  State<StatefulWidget> createState() => _SankalpProgressState();
}

class _SankalpProgressState extends State<_SankalpProgress> {
  final _shareKey = GlobalKey();
  bool _isSharing = false;

  SankalpEngine get engine => widget.engine;
  bool get isDark => widget.isDark;

  Future<void> _shareCertificate() async {
    setState(() => _isSharing = true);
    try {
      final boundary = _shareKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/sankalp_certificate.png');
      await file.writeAsBytes(byteData.buffer.asInt8List());
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Sankalp Complete - Nitya Sadhana',
          text: 'I completed my Sankalp of ${NumberFormat('#,##,###').format(engine.sankalp.totalGoal)} chants! 🙏',
        ),
      );
    } catch (e) {
      debugPrint('Share error: $e');
    } finally {
      setState(() => _isSharing = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final numberFormat = NumberFormat('#,##,###');
    final dateFormat = DateFormat('d MMM yyyy');

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        const SizedBox(height: 24),

        // Progress ring
        Center(
          child: SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: CircularProgressIndicator(
                    value: engine.progressFraction,
                    strokeWidth: 12,
                    strokeCap: StrokeCap.round,
                    backgroundColor: isDark ? AppColors.darkDivider : AppColors.divider,
                    valueColor: AlwaysStoppedAnimation(
                      engine.isComplete ? AppColors.teal : AppColors.saffron,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(engine.progressFraction * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      engine.statusLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: engine.isComplete
                            ? AppColors.teal
                            : engine.isOnTrack
                                ? AppColors.saffron
                                : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        if (engine.isComplete) ...[
          RepaintBoundary(
            key: _shareKey,
            child: Container(
              color: isDark ? AppColors.darkBg : AppColors.cream,
              child: SectionCard(
                child: Column(
                  children: [
                    const Icon(Icons.celebration_rounded, size: 48, color: AppColors.gold),
                    const SizedBox(height: 12),
                    Text(
                      'Sankalp Complete!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You have fulfilled your vow. May your devotion bring blessings.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${numberFormat.format(engine.sankalp.totalGoal)} chants Complete',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:  FontWeight.w600,
                        color: AppColors.saffron,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${dateFormat.format(engine.sankalp.startDate)} - ${dateFormat.format(engine.sankalp.endDate)}',
                      style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              label: Text(_isSharing ? 'Preparing...' : 'Shared Achievement'),
                onPressed: _isSharing ? null : _shareCertificate,
              icon: _isSharing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.share_rounded),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.saffron,
                side: const BorderSide(color: AppColors.saffron),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          )
        ],

        if (!engine.isComplete) ...[
          // Daily target card
          SectionCard(
            title: 'Daily Target',
            child: Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Rounds Today',
                    value: '${engine.dailyRequiredRounds}',
                    sub: '${numberFormat.format(engine.dailyRequired)} japs',
                    color: AppColors.saffron,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    label: 'Days Left',
                    value: '${engine.remainingDays}',
                    sub: 'of ${engine.sankalp.totalDays}',
                    color: AppColors.teal,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
        ],

        // Progress stats
        SectionCard(
          title: 'Progress',
          child: Column(
            children: [
              _ProgressRow(label: 'Completed', value: numberFormat.format(engine.completedCount), isDark: isDark),
              const Divider(height: 16),
              _ProgressRow(label: 'Remaining', value: numberFormat.format(engine.remainingChants), isDark: isDark),
              const Divider(height: 16),
              _ProgressRow(label: 'Total Goal', value: numberFormat.format(engine.sankalp.totalGoal), isDark: isDark),
            ],
          ),
        ),

        // Dates
        SectionCard(
          title: 'Duration',
          child: Column(
            children: [
              _ProgressRow(label: 'Start', value: dateFormat.format(engine.sankalp.startDate), isDark: isDark),
              const Divider(height: 16),
              _ProgressRow(label: 'End', value: dateFormat.format(engine.sankalp.endDate), isDark: isDark),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;
  final bool isDark;

  const _StatTile({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: color)),
          Text(sub, style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _ProgressRow({required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
      ],
    );
  }
}

class _CreateSankalpForm extends StatefulWidget {
  final String mantraName;
  final void Function(int goal, DateTime start, DateTime end) onSubmit;

  const _CreateSankalpForm({required this.mantraName, required this.onSubmit});

  @override
  State<_CreateSankalpForm> createState() => _CreateSankalpFormState();
}

class _CreateSankalpFormState extends State<_CreateSankalpForm> {
  final _goalController = TextEditingController(text: '125000');
  int _durationDays = 40;
  final _presets = [
    (label: '1.25 Lakh', value: 125000),
    (label: '1 Lakh', value: 100000),
    (label: '50,000', value: 50000),
    (label: '10,000', value: 10000),
  ];

  @override
  void initState() {
    super.initState();
    _goalController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 16),
        Icon(Icons.auto_awesome_rounded, size: 48, color: AppColors.gold),
        const SizedBox(height: 12),
        Text(
          'Take a Sankalp',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Commit to a japa goal for "${widget.mantraName}"',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 32),

        // Goal presets
        Text('Total Chants', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _presets.map((p) {
            final selected = _goalController.text == p.value.toString();
            return ChoiceChip(
              label: Text(p.label),
              selected: selected,
              onSelected: (_) => setState(() => _goalController.text = p.value.toString()),
              selectedColor: AppColors.saffronLight,
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _goalController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Custom goal',
            hintText: 'e.g. 125000',
          ),
        ),

        const SizedBox(height: 24),
        Text('Duration (days)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
        const SizedBox(height: 8),
        Slider(
          value: _durationDays.toDouble(),
          min: 7,
          max: 120,
          divisions: 113,
          label: '$_durationDays days',
          activeColor: AppColors.saffron,
          onChanged: (v) => setState(() => _durationDays = v.round()),
        ),
        Text(
          '$_durationDays days',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
        ),

        const SizedBox(height: 8),
        Builder(builder: (_) {
          final goal = int.tryParse(_goalController.text) ?? 0;
          final dailyNeeded = goal > 0 ? (goal / _durationDays).ceil() : 0;
          final roundsNeeded = (dailyNeeded / 108).ceil();
          return Text(
            'You will need ~$roundsNeeded rounds ($dailyNeeded japs) per day',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
          );
        }),

        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () {
            final goal = int.tryParse(_goalController.text);
            if (goal == null || goal <= 0) return;
            final start = DateTime.now();
            final end = start.add(Duration(days: max(1, _durationDays - 1)));
            widget.onSubmit(goal, start, end);
          },
          child: const Text('Begin Sankalp'),
        ),
      ],
    );
  }
}
