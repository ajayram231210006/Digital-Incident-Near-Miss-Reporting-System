import 'package:flutter/material.dart';
import 'image_viewer.dart';

class ReporterReportDetail extends StatelessWidget {
  final String reportId;
  final Map<String, dynamic> report;

  const ReporterReportDetail({
    super.key,
    required this.reportId,
    required this.report,
  });

  @override
  Widget build(BuildContext context) {
    final status = (report['status'] ?? 'open').toString().toLowerCase();
    final statusColor = status == 'closed'
        ? Colors.green
        : status == 'active'
            ? Colors.orange
            : Colors.amber;

    // Convert Firebase Map to List (Firebase stores lists as Maps with numeric keys)
    final imageParams = report['imageUrls'];
    final imageUrlsList = imageParams is List 
      ? List<String>.from(imageParams.whereType<String>())
      : imageParams is Map 
        ? imageParams.values.whereType<String>().toList()
        : <String>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incident Details'),
        elevation: 2,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                statusColor,
                statusColor.withValues(alpha: 0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Incident Type and Location
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.category_outlined, color: Colors.blueAccent),
                        const SizedBox(width: 8),
                        Text(
                          'Incident Details',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Incident Type',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report['type'] ?? 'Unknown',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Location',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report['location'] ?? 'Unknown',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Incident Date
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_month_outlined, color: Colors.orangeAccent),
                        const SizedBox(width: 8),
                        Text(
                          'Incident Date',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatDate(report['date']),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Submission Time
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.access_time_outlined, color: Colors.blueAccent),
                        const SizedBox(width: 8),
                        Text(
                          'Report Submitted',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatDate(report['createdAt']),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Description
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.description_outlined, color: Colors.greenAccent),
                        const SizedBox(width: 8),
                        Text(
                          'Description',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      report['description'] ?? 'No description',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Image (if available)
            if (imageUrlsList.isNotEmpty)
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.image_outlined, color: Colors.purpleAccent),
                          const SizedBox(width: 8),
                          Text(
                            'Incident Images (${imageUrlsList.length})',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: imageUrlsList.length,
                        itemBuilder: (context, index) {
                          final imageUrl = imageUrlsList[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => ImageViewer(
                                    imageUrl: imageUrl,
                                    title: 'Incident Image ${index + 1}',
                                  ),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey[300],
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Center(
                                          child: Icon(Icons.error),
                                        ),
                                      );
                                    },
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(8),
                                        ),
                                      ),
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              )
            else if (report['imageUrl'] != null &&
                (report['imageUrl'] as String).isNotEmpty)
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.image_outlined, color: Colors.purpleAccent),
                          const SizedBox(width: 8),
                          Text(
                            'Incident Image',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ImageViewer(
                                imageUrl: report['imageUrl'],
                                title: 'Incident Image',
                              ),
                            ),
                          );
                        },
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              report['imageUrl'],
                              height: 250,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 250,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Center(
                                    child: Text('Failed to load image'),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Video (if available)
            if (report['videoUrl'] != null &&
                (report['videoUrl'] as String).isNotEmpty)
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.video_library_outlined, color: Colors.orangeAccent),
                          const SizedBox(width: 8),
                          Text(
                            'Incident Video',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ImageViewer(
                                imageUrl: report['videoUrl'],
                                title: 'Incident Video',
                                isVideo: true,
                              ),
                            ),
                          );
                        },
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              height: 250,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    Icons.video_library,
                                    size: 64,
                                    color: Colors.orange.shade300,
                                  ),
                                  Positioned(
                                    right: 12,
                                    bottom: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.fiber_manual_record,
                                            color: Colors.white,
                                            size: 8,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Tap to play',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Status
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.assignment_outlined, color: Colors.redAccent),
                        const SizedBox(width: 8),
                        Text(
                          'Status',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: statusColor,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${status[0].toUpperCase()}${status.substring(1)}',
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Supervisor Notes
            if (report['notes'] != null && (report['notes'] as String).isNotEmpty)
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.note_outlined, color: Colors.tealAccent),
                          const SizedBox(width: 8),
                          Text(
                            'Supervisor Notes',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          report['notes'],
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic dateString) {
    if (dateString == null || dateString.toString().isEmpty) {
      return 'Unknown';
    }
    try {
      final date = DateTime.parse(dateString.toString());
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }
}
