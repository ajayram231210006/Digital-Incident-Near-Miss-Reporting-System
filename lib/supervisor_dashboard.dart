import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'supervisor_reports_list.dart';

class SupervisorDashboard extends StatefulWidget {
  final User user;
  const SupervisorDashboard({super.key, required this.user});

  @override
  State<SupervisorDashboard> createState() => _SupervisorDashboardState();
}

class _SupervisorDashboardState extends State<SupervisorDashboard> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  Stream<Map<String, int>> _getReportStatsStream() {
    return _dbRef.child('incidents').onValue.map((event) {
      if (!event.snapshot.exists) {
        return {'total': 0, 'open': 0, 'active': 0, 'closed': 0};
      }

      int total = 0;
      int open = 0;
      int active = 0;
      int closed = 0;

      final data = event.snapshot.value as Map?;
      if (data != null) {
        data.forEach((key, value) {
          if (value is Map) {
            total++;
            final status = (value['status'] ?? 'open').toString().toLowerCase();
            
            if (status == 'closed') {
              closed++;
            } else if (status == 'active') {
              active++;
            } else {
              // 'open' or default status
              open++;
            }
          }
        });
      }

      return {'total': total, 'open': open, 'active': active, 'closed': closed};
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supervisor Dashboard'),
        elevation: 2,
        shadowColor: Colors.grey.withOpacity(0.5),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          StreamBuilder<Map<String, int>>(
            stream: _getReportStatsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Expanded(
                  child: Center(child: Text('Error: ${snapshot.error}')),
                );
              }
              final stats = snapshot.data ?? {};
              final totalReports = stats['total'] ?? 0;
              final openReports = stats['open'] ?? 0;
              final activeReports = stats['active'] ?? 0;
              final closedReports = stats['closed'] ?? 0;
              return Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue.shade400, Colors.blue.shade600],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Welcome ',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  TextSpan(
                                    text: widget.user.displayName ?? widget.user.email?.split('@').first ?? 'Supervisor',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Here\'s your incident report overview',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Report Statistics',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        children: [
                          _StatisticCard(
                            title: 'Total Reports',
                            count: totalReports,
                            color: Colors.blue,
                            icon: Icons.assignment,
                            onTap: () => _navigateToReports(context, 'all'),
                          ),
                          _StatisticCard(
                            title: 'Awaiting Review',
                            count: openReports,
                            color: Colors.amber,
                            icon: Icons.schedule,
                            onTap: () => _navigateToReports(context, 'open'),
                          ),
                          _StatisticCard(
                            title: 'In Progress',
                            count: activeReports,
                            color: Colors.orange,
                            icon: Icons.hourglass_bottom,
                            onTap: () => _navigateToReports(context, 'active'),
                          ),
                          _StatisticCard(
                            title: 'Closed',
                            count: closedReports,
                            color: Colors.green,
                            icon: Icons.check_circle,
                            onTap: () => _navigateToReports(context, 'closed'),
                          ),
                        ],
                      ),

                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _navigateToReports(BuildContext context, String filter) {
    String filterValue = filter;
    if (filter == 'pending') {
      filterValue = 'pending'; // Pending includes both open and active reports
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SupervisorReportsList(
          user: widget.user,
          filterStatus: filterValue,
        ),
      ),
    );
  }


}

class _StatisticCard extends StatefulWidget {
  final String title;
  final int count;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _StatisticCard({
    required this.title,
    required this.count,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_StatisticCard> createState() => _StatisticCardState();
}

class _StatisticCardState extends State<_StatisticCard>
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
        child: Card(
          elevation: 6,
          shadowColor: widget.color.withOpacity(0.4),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  widget.color.withOpacity(0.1),
                  widget.color.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.color.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    widget.icon,
                    size: 32,
                    color: widget.color,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.count.toString(),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: widget.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


