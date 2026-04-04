import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AdminDashboard extends StatefulWidget {
  final User user;

  const AdminDashboard({super.key, required this.user});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late DatabaseReference _usersRef;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _usersRef = FirebaseDatabase.instance.ref('users');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _approveUser(String uid, String role) async {
    try {
      await _usersRef.child(uid).update({'status': 'active'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('User approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejectUser(String uid) async {
    try {
      await _usersRef.child(uid).update({'status': 'rejected'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('User rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deactivateUser(String uid) async {
    try {
      await _usersRef.child(uid).update({'status': 'inactive'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('User deactivated'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showLogoutDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.logout, color: Colors.red.shade600),
            const SizedBox(width: 12),
            const Text('Logout'),
          ],
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.blue.shade600,
        elevation: 4,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                'Admin: ${widget.user.email}',
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _showLogoutDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.hourglass_empty), text: 'Pending'),
            Tab(icon: Icon(Icons.people), text: 'Reporters'),
            Tab(icon: Icon(Icons.shield), text: 'Supervisors'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Statistics'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PendingUsersTab(
            usersRef: _usersRef,
            onApprove: _approveUser,
            onReject: _rejectUser,
          ),
          _ReportersTab(usersRef: _usersRef, onDeactivate: _deactivateUser),
          _SupervisorsTab(usersRef: _usersRef, onDeactivate: _deactivateUser),
          _StatisticsTab(usersRef: _usersRef),
        ],
      ),
    );
  }
}

class _PendingUsersTab extends StatelessWidget {
  final DatabaseReference usersRef;
  final Function(String, String) onApprove;
  final Function(String) onReject;

  const _PendingUsersTab({
    required this.usersRef,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: usersRef.onValue,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _AdminDataError(
            message:
                'Unable to load users. Check Realtime Database rules for admin read access on /users.',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return const Center(child: Text('No users found'));
        }

        final users = <MapEntry<String, Map<String, dynamic>>>[];
        final data = Map<String, dynamic>.from(
          snapshot.data!.snapshot.value as Map,
        );

        data.forEach((uid, userData) {
          final user = Map<String, dynamic>.from(userData as Map);
          final status = user['status'] as String? ?? 'pending_approval';
          if (status == 'pending_approval') {
            users.add(MapEntry(uid, user));
          }
        });

        if (users.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 80, color: Colors.green),
                SizedBox(height: 20),
                Text('No pending approvals'),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final uid = users[index].key;
            final userData = users[index].value;

            return Card(
              margin: const EdgeInsets.all(12),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Icon(
                            Icons.hourglass_empty,
                            color: Colors.orange.shade700,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${userData['firstName']} ${userData['lastName']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                userData['email'] ?? 'No email',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Chip(
                      label: Text(
                        userData['role'].toString().toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor: userData['role'] == 'supervisor'
                          ? Colors.purple
                          : Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Applied: ${userData['createdAt'] ?? 'Unknown date'}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _showRejectDialog(context, uid),
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Reject'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => onApprove(uid, userData['role']),
                          icon: const Icon(Icons.check_circle, size: 18),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showRejectDialog(BuildContext context, String uid) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject User'),
        content: const Text(
          'Are you sure you want to reject this user request?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              onReject(uid);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}

class _ReportersTab extends StatelessWidget {
  final DatabaseReference usersRef;
  final Function(String) onDeactivate;

  const _ReportersTab({required this.usersRef, required this.onDeactivate});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: usersRef.onValue,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _AdminDataError(
            message:
                'Unable to load reporters. Check Realtime Database rules for admin read access on /users.',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return const Center(child: Text('No reporters found'));
        }

        final reporters = <MapEntry<String, Map<String, dynamic>>>[];
        final data = Map<String, dynamic>.from(
          snapshot.data!.snapshot.value as Map,
        );

        data.forEach((uid, userData) {
          final user = Map<String, dynamic>.from(userData as Map);
          if (user['role'] == 'reporter' && user['status'] == 'active') {
            reporters.add(MapEntry(uid, user));
          }
        });

        if (reporters.isEmpty) {
          return const Center(child: Text('No active reporters'));
        }

        return ListView.builder(
          itemCount: reporters.length,
          itemBuilder: (context, index) {
            final uid = reporters[index].key;
            final userData = reporters[index].value;

            return Card(
              margin: const EdgeInsets.all(12),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Icon(Icons.person, color: Colors.blue.shade700),
                ),
                title: Text('${userData['firstName']} ${userData['lastName']}'),
                subtitle: Text(userData['email'] ?? 'No email'),
                trailing: PopupMenuButton(
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: const Text('Deactivate'),
                      onTap: () => onDeactivate(uid),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SupervisorsTab extends StatelessWidget {
  final DatabaseReference usersRef;
  final Function(String) onDeactivate;

  const _SupervisorsTab({required this.usersRef, required this.onDeactivate});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: usersRef.onValue,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _AdminDataError(
            message:
                'Unable to load supervisors. Check Realtime Database rules for admin read access on /users.',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return const Center(child: Text('No supervisors found'));
        }

        final supervisors = <MapEntry<String, Map<String, dynamic>>>[];
        final data = Map<String, dynamic>.from(
          snapshot.data!.snapshot.value as Map,
        );

        data.forEach((uid, userData) {
          final user = Map<String, dynamic>.from(userData as Map);
          if (user['role'] == 'supervisor' && user['status'] == 'active') {
            supervisors.add(MapEntry(uid, user));
          }
        });

        if (supervisors.isEmpty) {
          return const Center(child: Text('No active supervisors'));
        }

        return ListView.builder(
          itemCount: supervisors.length,
          itemBuilder: (context, index) {
            final uid = supervisors[index].key;
            final userData = supervisors[index].value;

            return Card(
              margin: const EdgeInsets.all(12),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Icon(Icons.shield, color: Colors.purple.shade700),
                ),
                title: Text('${userData['firstName']} ${userData['lastName']}'),
                subtitle: Text(userData['email'] ?? 'No email'),
                trailing: PopupMenuButton(
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: const Text('Deactivate'),
                      onTap: () => onDeactivate(uid),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _StatisticsTab extends StatelessWidget {
  final DatabaseReference usersRef;

  const _StatisticsTab({required this.usersRef});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: usersRef.onValue,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _AdminDataError(
            message:
                'Unable to load statistics. Check Realtime Database rules for admin read access on /users.',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return const Center(child: Text('No data available'));
        }

        final data = Map<String, dynamic>.from(
          snapshot.data!.snapshot.value as Map,
        );
        int totalUsers = 0;
        int activeReporters = 0;
        int activeSupervisors = 0;
        int pendingApprovals = 0;
        int rejectedUsers = 0;

        data.forEach((uid, userData) {
          final user = Map<String, dynamic>.from(userData as Map);
          totalUsers++;

          final status = user['status'] as String? ?? 'pending_approval';
          final role = user['role'] as String?;

          if (status == 'active') {
            if (role == 'reporter') {
              activeReporters++;
            } else if (role == 'supervisor') {
              activeSupervisors++;
            }
          } else if (status == 'pending_approval') {
            pendingApprovals++;
          } else if (status == 'rejected') {
            rejectedUsers++;
          }
        });

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _StatCard(
                title: 'Total Users',
                count: totalUsers,
                icon: Icons.people,
                color: Colors.blue,
              ),
              const SizedBox(height: 12),
              _StatCard(
                title: 'Active Reporters',
                count: activeReporters,
                icon: Icons.person,
                color: Colors.green,
              ),
              const SizedBox(height: 12),
              _StatCard(
                title: 'Active Supervisors',
                count: activeSupervisors,
                icon: Icons.shield,
                color: Colors.purple,
              ),
              const SizedBox(height: 12),
              _StatCard(
                title: 'Pending Approvals',
                count: pendingApprovals,
                icon: Icons.hourglass_empty,
                color: Colors.orange,
              ),
              const SizedBox(height: 12),
              _StatCard(
                title: 'Rejected Users',
                count: rejectedUsers,
                icon: Icons.block,
                color: Colors.red,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(width: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 8),
                Text(
                  count.toString(),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminDataError extends StatelessWidget {
  final String message;

  const _AdminDataError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
