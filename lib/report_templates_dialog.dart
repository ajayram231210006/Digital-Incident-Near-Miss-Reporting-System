import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'reporter.dart' show ReportIncidentForm;
import 'reporter_identity.dart';
import 'ui_components.dart';

class ReportTemplatesDialog extends StatefulWidget {
  final User user;

  const ReportTemplatesDialog({super.key, required this.user});

  @override
  State<ReportTemplatesDialog> createState() => _ReportTemplatesDialogState();
}

class _ReportTemplatesDialogState extends State<ReportTemplatesDialog> {
  late final List<_ReportTemplate> templates = [
    _ReportTemplate(
      id: 'safety_hazard',
      name: 'Safety Hazard',
      icon: Icons.warning_amber_rounded,
      color: AppColors.warning,
      description: 'Unsafe conditions, exposed risks, or damaged equipment.',
    ),
    _ReportTemplate(
      id: 'near_miss',
      name: 'Near Miss',
      icon: Icons.shield_outlined,
      color: AppColors.info,
      description: 'An event that could have caused harm but did not.',
    ),
    _ReportTemplate(
      id: 'accident',
      name: 'Accident / Injury',
      icon: Icons.medical_services_outlined,
      color: AppColors.error,
      description: 'Injuries, accidents, or emergency medical situations.',
    ),
    _ReportTemplate(
      id: 'property_damage',
      name: 'Property Damage',
      icon: Icons.home_repair_service_rounded,
      color: AppColors.secondary,
      description: 'Damage to vehicles, tools, equipment, or facilities.',
    ),
    _ReportTemplate(
      id: 'environmental',
      name: 'Environmental',
      icon: Icons.eco_rounded,
      color: AppColors.success,
      description: 'Spills, emissions, or environment-related incidents.',
    ),
    _ReportTemplate(
      id: 'other',
      name: 'Other',
      icon: Icons.description_outlined,
      color: AppColors.textSecondary,
      description: 'A general template for anything outside standard types.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 900 ? 3 : 2;
    final aspectRatio = switch (width) {
      < 380 => 0.66,
      < 520 => 0.74,
      < 900 => 0.84,
      _ => 0.94,
    };

    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      shape: RoundedRectangleBorder(borderRadius: AppRadii.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick report templates',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Choose a starting point to speed up report entry.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: GridView.builder(
                  itemCount: templates.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                    childAspectRatio: aspectRatio,
                  ),
                  itemBuilder: (context, index) {
                    final template = templates[index];
                    return _TemplateCard(
                      template: template,
                      onTap: () async {
                        Navigator.of(context).pop();
                        await Future<void>.delayed(
                          const Duration(milliseconds: 180),
                        );
                        if (context.mounted) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  ReportIncidentForm(
                                    reporter: ReporterIdentity.fromFirebaseUser(
                                      widget.user,
                                    ),
                                  ),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateCard extends StatefulWidget {
  final _ReportTemplate template;
  final VoidCallback onTap;

  const _TemplateCard({required this.template, required this.onTap});

  @override
  State<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<_TemplateCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.template.color;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 170;
        final cardPadding = compact ? 12.0 : AppSpacing.lg;
        final iconPadding = compact ? 10.0 : AppSpacing.md;
        final descriptionLines = compact ? 4 : 3;

        return ScaleTransition(
          scale: Tween<double>(begin: 1, end: 0.97).animate(_controller),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              onTapDown: (_) => _controller.forward(),
              onTapUp: (_) => _controller.reverse(),
              onTapCancel: _controller.reverse,
              borderRadius: AppRadii.large,
              child: AppSectionCard(
                padding: EdgeInsets.all(cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(iconPadding),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: AppRadii.medium,
                      ),
                      child: Icon(
                        widget.template.icon,
                        color: color,
                        size: compact ? 22 : 26,
                      ),
                    ),
                    SizedBox(height: compact ? 12 : AppSpacing.lg),
                    Text(
                      widget.template.name,
                      maxLines: compact ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        widget.template.description,
                        maxLines: descriptionLines,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Use template',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(
                              context,
                            ).textTheme.labelLarge?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: color,
                          size: 18,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ReportTemplate {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final String description;

  const _ReportTemplate({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.description,
  });
}
