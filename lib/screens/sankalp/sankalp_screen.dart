import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nitya_sadhana/models/sankalp.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../models/mantra.dart';
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

    return SafeArea(
      child: sankalp.isLoading
          ? const Center(child: CircularProgressIndicator())
          : sankalp.engine != null
          ? _SankalpProgress(
              engine: sankalp.engine!,
              isDark: isDark,
              mantraName:
                  japa.mantras
                      .where((m) => m.id == sankalp.engine!.sankalp.mantraId)
                      .map((m) => m.name)
                      .firstOrNull ??
                  'Mantra',
            )
          : _CreateSankalpForm(
              mantras: japa.mantras,
              activeMantra: japa.activeMantra,
              onAddMantra: (name, {String? actualMantra}) async {
                final ok = await japa.addMantra(
                  name,
                  actualMantra: actualMantra,
                );
                return ok ? japa.mantras.last : null;
              },
              onSubmit: (mantraId, goal, start, end, mode) {
                ref
                    .read(sankalpProvider)
                    .createSankalp(
                      mantraId: mantraId,
                      totalGoal: goal,
                      startDate: start,
                      endDate: end,
                      mode: mode,
                    );
              },
            ),
    );
  }
}

class _SankalpProgress extends StatefulWidget {
  final SankalpEngine engine;
  final bool isDark;
  final String mantraName;

  const _SankalpProgress({
    required this.engine,
    required this.isDark,
    required this.mantraName,
  });

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
      final boundary =
          _shareKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
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
          text:
              'I completed my Sankalp of ${NumberFormat('#,##,###').format(engine.sankalp.totalGoal)} chants! 🙏',
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
        const SizedBox(height: 16),

        // Mantra name badge
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.saffron.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 16, color: AppColors.saffron),
                const SizedBox(width: 8),
                Text(
                  widget.mantraName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.saffron,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Progress ring
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.saffron.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 16, color: AppColors.saffron),
                const SizedBox(width: 8),
                Text(
                  widget.mantraName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.saffron,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

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
                    backgroundColor: isDark
                        ? AppColors.darkDivider
                        : AppColors.divider,
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
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
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
                    const Icon(
                      Icons.celebration_rounded,
                      size: 48,
                      color: AppColors.gold,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Sankalp Complete!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You have fulfilled your vow. May your devotion bring blessings.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${numberFormat.format(engine.sankalp.totalGoal)} chants Complete',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.saffron,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${dateFormat.format(engine.sankalp.startDate)} - ${dateFormat.format(engine.sankalp.endDate)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
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
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.share_rounded),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.saffron,
                side: const BorderSide(color: AppColors.saffron),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
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

        if (!engine.isComplete) ...[
          // Mode badge
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: engine.isDaily
                    ? AppColors.teal.withValues(alpha: isDark ? 0.15 : 0.08)
                    : AppColors.saffron.withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    engine.isDaily
                        ? Icons.calendar_today_rounded
                        : Icons.bolt_rounded,
                    size: 14,
                    color: engine.isDaily ? AppColors.teal : AppColors.saffron,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    engine.modeLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: engine.isDaily
                          ? AppColors.teal
                          : AppColors.saffron,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),
          // Today's progress (daily mode)
          if (engine.isDaily) ...[
            SectionCard(
              title: "Today's Progress",
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          label: "Done Today",
                          value: numberFormat.format(engine.todayCount),
                          sub: engine.todayComplete
                              ? 'Target met!'
                              : '${numberFormat.format(engine.totalRemaining)} remaining',
                          color: engine.todayComplete
                              ? AppColors.teal
                              : AppColors.saffron,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatTile(
                          label: 'Daily Target',
                          value: '${engine.dailyRequiredRounds}',
                          sub:
                              '${numberFormat.format(engine.dailyRequired)} japs',
                          color: AppColors.saffron,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  if (engine.todayComplete) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.teal.withValues(
                          alpha: isDark ? 0.15 : 0.08,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: AppColors.teal,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Today\'s target is complete! Continue tomorrow.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.teal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Overall target card
          SectionCard(
            title: engine.isDaily ? 'Overall Target' : 'Target',
            child: Row(
              children: [
                if (!engine.isDaily) ...[
                  Expanded(
                    child: _StatTile(
                      label: 'Rounds Needed',
                      value: '${engine.dailyRequiredRounds}',
                      sub:
                          '${numberFormat.format(engine.dailyRequired)} japs/day',
                      color: AppColors.saffron,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ],
            ),
          ),
        ],

        // Progress stats
        SectionCard(
          title: 'Progress',
          child: Column(
            children: [
              _ProgressRow(
                label: 'Completed',
                value: numberFormat.format(engine.completedCount),
                isDark: isDark,
              ),
              const Divider(height: 16),
              _ProgressRow(
                label: 'Remaining',
                value: numberFormat.format(engine.remainingChants),
                isDark: isDark,
              ),
              const Divider(height: 16),
              _ProgressRow(
                label: 'Total Goal',
                value: numberFormat.format(engine.sankalp.totalGoal),
                isDark: isDark,
              ),
            ],
          ),
        ),

        // Dates
        SectionCard(
          title: 'Duration',
          child: Column(
            children: [
              _ProgressRow(
                label: 'Start',
                value: dateFormat.format(engine.sankalp.startDate),
                isDark: isDark,
              ),
              const Divider(height: 16),
              _ProgressRow(
                label: 'End',
                value: dateFormat.format(engine.sankalp.endDate),
                isDark: isDark,
              ),
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
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            sub,
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _ProgressRow({
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _CreateSankalpForm extends StatefulWidget {
  final List<Mantra> mantras;
  final Mantra? activeMantra;
  final Future<Mantra?> Function(String name, {String? actualMantra})
  onAddMantra;
  final void Function(
    int mantraId,
    int goal,
    DateTime start,
    DateTime end,
    SankalpMode mode,
  )
  onSubmit;

  const _CreateSankalpForm({
    required this.mantras,
    required this.activeMantra,
    required this.onAddMantra,
    required this.onSubmit,
  });

  @override
  State<_CreateSankalpForm> createState() => _CreateSankalpFormState();
}

class _CreateSankalpFormState extends State<_CreateSankalpForm> {
  final _goalController = TextEditingController(text: '125000');
  int _durationDays = 40;
  SankalpMode _mode = SankalpMode.daily;
  Mantra? _selectedMantra;

  final _presets = [
    (label: '1.25 Lakh', value: 125000),
    (label: '1 Lakh', value: 100000),
    (label: '50,000', value: 50000),
    (label: '10,000', value: 10000),
  ];

  @override
  void initState() {
    super.initState();
    _selectedMantra = widget.activeMantra ?? widget.mantras.firstOrNull;
    _goalController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  void _showAddMantraDialog() {
    final nameCtrl = TextEditingController();
    final mantraCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Add Naam / Mantra',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: mantraCtrl,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: 'Short Name',
                hintText: 'e.g Radha, Shani Mantra ',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: mantraCtrl,
              decoration: InputDecoration(
                labelText: 'Full Mantra Text (optional)',
                hintText: 'e.g Om Namah Shivaya',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 6),
            Text(
              'The full text is used to set the chanting pace. Longer mantra automatically get a lower tap speed.',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.black26,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  final actualMantra = mantraCtrl.text.trim().isNotEmpty
                      ? mantraCtrl.text.trim()
                      : null;
                  final mantra = await widget.onAddMantra(
                    name,
                    actualMantra: actualMantra,
                  );
                  if (mantra != null && mounted) {
                    Navigator.pop(ctx);
                    setState(() => _selectedMantra = mantra);
                  }
                },
                child: const Text('Add'),
              ),
            ),
          ],
        ),
      ),
    );
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
          'Commit to a japa goal',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),

        // Mantra / Naam selector
        Text(
          'Select Naam / Mantra',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...widget.mantras.map((m) {
              final selected = _selectedMantra?.id == m.id;
              return ChoiceChip(
                label: Text(m.name),
                selected: selected,
                onSelected: (_) => setState(() => _selectedMantra = m),
                selectedColor: isDark
                    ? AppColors.saffron.withValues(alpha: 0.2)
                    : AppColors.saffronLight,
                side: BorderSide(
                  color: selected
                      ? AppColors.saffron
                      : (isDark ? AppColors.darkDivider : AppColors.divider),
                ),
                labelStyle: TextStyle(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected
                      ? AppColors.saffron
                      : (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary),
                ),
              );
            }),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Add New'),
              onPressed: _showAddMantraDialog,
              side: BorderSide(
                color: isDark ? AppColors.darkDivider : AppColors.divider,
              ),
              labelStyle: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
        if (_selectedMantra?.actualMantra != null) ...[
          const SizedBox(height: 6),
          Text(
            _selectedMantra!.actualMantra!,
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
            ),
          ),
        ],

        const SizedBox(height: 24),

        // Goal presets
        Text(
          'Total Chants',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _presets.map((p) {
            final selected = _goalController.text == p.value.toString();
            return ChoiceChip(
              label: Text(p.label),
              selected: selected,
              onSelected: (_) =>
                  setState(() => _goalController.text = p.value.toString()),
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
        Text(
          'Duration (days)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
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
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),

        const SizedBox(height: 8),
        Builder(
          builder: (_) {
            final goal = int.tryParse(_goalController.text) ?? 0;
            final dailyNeeded = goal > 0 ? (goal / _durationDays).ceil() : 0;
            final roundsNeeded = (dailyNeeded / 108).ceil();
            return Text(
              'You will need ~$roundsNeeded rounds ($dailyNeeded japs) per day',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            );
          },
        ),

        // Mode selector
        const SizedBox(height: 24),
        Text(
          'Completion Mode',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        _ModeOption(
          title: 'Daily Target',
          subtitle:
              'Must complete a fixed amount each day. Progress is tracked daily',
          icon: Icons.calendar_today_rounded,
          selected: _mode == SankalpMode.daily,
          color: AppColors.teal,
          isDark: isDark,
          onTap: () => setState(() => _mode = SankalpMode.daily),
        ),
        const SizedBox(height: 8),
        _ModeOption(
          title: 'Flexible (One-shot OK)',
          subtitle:
              'Complete at your own pace, You can finish the entire goal in one setting.',
          icon: Icons.bolt_rounded,
          selected: _mode == SankalpMode.flexible,
          color: AppColors.saffron,
          isDark: isDark,
          onTap: () => setState(() => _mode = SankalpMode.flexible),
        ),

        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () {
            if (_selectedMantra == null) return;
            final goal = int.tryParse(_goalController.text);
            if (goal == null || goal <= 0) return;
            final start = DateTime.now();
            final end = start.add(Duration(days: max(1, _durationDays - 1)));
            widget.onSubmit(_selectedMantra!.id!, goal, start, end, _mode);
          },
          child: const Text('Begin Sankalp'),
        ),
      ],
    );
  }
}

class _ModeOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _ModeOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: isDark ? 0.15 : 0.08)
              : (isDark ? AppColors.darkCard : AppColors.cream),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? color
                : (isDark ? AppColors.darkDivider : AppColors.divider),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: selected ? color : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? color
                          : (isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, size: 20, color: color),
          ],
        ),
      ),
    );
  }
}
