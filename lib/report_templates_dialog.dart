import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'reporter.dart' show ReportIncidentForm;

class ReportTemplatesDialog extends StatefulWidget {
  final User user;

  const ReportTemplatesDialog({super.key, required this.user});

  @override
  State<ReportTemplatesDialog> createState() => _ReportTemplatesDialogState();
}

class _ReportTemplatesDialogState extends State<ReportTemplatesDialog> {
  final List<_ReportTemplate> templates = [
    _ReportTemplate(
      id: 'safety_hazard',
      name: 'Safety Hazard',
      icon: Icons.warning_amber_rounded,
      color: Colors.red,
      description: 'Report unsafe conditions or equipment hazards',
      prefillData: {
        'type': 'Safety Hazard',
      },
    ),
    _ReportTemplate(
      id: 'near_miss',
      name: 'Near Miss',
      icon: Icons.close_fullscreen_rounded,
      color: Colors.orange,
      description: 'Report incidents where injury could have occurred',
      prefillData: {
        'type': 'Near Miss',
      },
    ),
    _ReportTemplate(
      id: 'accident',
      name: 'Accident/Injury',
      icon: Icons.medical_information_rounded,
      color: Colors.pink,
      description: 'Report workplace accidents or injuries',
      prefillData: {
        'type': 'Accident/Injury',
      },
    ),
    _ReportTemplate(
      id: 'property_damage',
      name: 'Property Damage',
      icon: Icons.home_repair_service_rounded,
      color: Colors.amber,
      description: 'Report damage to equipment or property',
      prefillData: {
        'type': 'Property Damage',
      },
    ),
    _ReportTemplate(
      id: 'environmental',
      name: 'Environmental Issue',
      icon: Icons.eco_rounded,
      color: Colors.green,
      description: 'Report environmental or spillage incidents',
      prefillData: {
        'type': 'Environmental Issue',
      },
    ),
    _ReportTemplate(
      id: 'other',
      name: 'Other',
      icon: Icons.description_rounded,
      color: Colors.grey,
      description: 'Report other incidents or concerns',
      prefillData: {
        'type': 'Other Incident',
      },
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quick Report Templates'),
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
        ),
        body: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: templates.length,
          itemBuilder: (context, index) {
            final template = templates[index];
            return _TemplateCard(
              template: template,
              onTap: () async {
                Navigator.pop(context);
                await Future.delayed(const Duration(milliseconds: 300));
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ReportIncidentForm(user: widget.user),
                    ),
                  );
                }
              },
            );
          },
        ),
      ),
    );
  }
}

// Template Card Widget
class _TemplateCard extends StatefulWidget {
  final _ReportTemplate template;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.template,
    required this.onTap,
  });

  @override
  State<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<_TemplateCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.template.color.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Colors.grey.shade50],
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.template.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      widget.template.icon,
                      size: 32,
                      color: widget.template.color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Name
                  Text(
                    widget.template.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Description
                  Text(
                    widget.template.description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Template Model
class _ReportTemplate {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final String description;
  final Map<String, dynamic> prefillData;

  _ReportTemplate({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.description,
    required this.prefillData,
  });
}
