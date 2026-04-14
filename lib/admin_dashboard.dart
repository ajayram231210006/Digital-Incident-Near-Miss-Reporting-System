import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'ui_components.dart';

class AdminDashboard extends StatefulWidget {
  final User user;

  const AdminDashboard({super.key, required this.user});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final DatabaseReference _usersRef;
  late final DatabaseReference _rootRef;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _rootRef = FirebaseDatabase.instance.ref();
    _usersRef = _rootRef.child('users');
    _backfillRoleDirectory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _syncRoleDirectory({
    required String uid,
    required String role,
    required String status,
  }) async {
    final normalizedRole = role.toLowerCase();
    final normalizedStatus = status.toLowerCase();
    final updates = <String, Object?>{};

    if (normalizedRole == 'reporter') {
      updates['roleDirectory/reporters/$uid'] = normalizedStatus == 'active'
          ? true
          : null;
    } else if (normalizedRole == 'supervisor') {
      updates['roleDirectory/supervisors/$uid'] = normalizedStatus == 'active'
          ? true
          : null;
    }

    if (updates.isNotEmpty) {
      await _rootRef.update(updates);
    }
  }

  Future<void> _backfillRoleDirectory() async {
    try {
      final snapshot = await _usersRef.get();
      if (!snapshot.exists || snapshot.value is! Map) return;

      final updates = <String, Object?>{};
      final users = snapshot.value as Map;
      for (final entry in users.entries) {
        final uid = entry.key.toString();
        final rawUser = entry.value;
        if (rawUser is! Map) continue;

        final role = rawUser['role']?.toString().toLowerCase() ?? '';
        final status = rawUser['status']?.toString().toLowerCase() ?? '';

        if (role == 'reporter') {
          updates['roleDirectory/reporters/$uid'] = status == 'active'
              ? true
              : null;
        } else if (role == 'supervisor') {
          updates['roleDirectory/supervisors/$uid'] = status == 'active'
              ? true
              : null;
        }
      }

      if (updates.isNotEmpty) {
        await _rootRef.update(updates);
      }
    } catch (_) {}
  }

  Future<void> _approveUser(String uid, String role) async {
    try {
      await _usersRef.child(uid).update({'status': 'active'});
      await _syncRoleDirectory(uid: uid, role: role, status: 'active');
      if (mounted) {
        showAppSnackBar(
          context,
          'User approved successfully.',
          type: AppSnackBarType.success,
        );
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'We could not approve that user right now.',
          type: AppSnackBarType.error,
        );
      }
    }
  }

  Future<void> _rejectUser(String uid, String role) async {
    try {
      await _usersRef.child(uid).update({'status': 'rejected'});
      await _syncRoleDirectory(uid: uid, role: role, status: 'rejected');
      if (mounted) {
        showAppSnackBar(context, 'User rejected.', type: AppSnackBarType.info);
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'We could not update that user right now.',
          type: AppSnackBarType.error,
        );
      }
    }
  }

  Future<void> _deactivateUser(String uid, String role) async {
    try {
      await _usersRef.child(uid).update({'status': 'inactive'});
      await _syncRoleDirectory(uid: uid, role: role, status: 'inactive');
      if (mounted) {
        showAppSnackBar(
          context,
          'User deactivated.',
          type: AppSnackBarType.info,
        );
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'We could not deactivate that user right now.',
          type: AppSnackBarType.error,
        );
      }
    }
  }

  Future<void> _restoreUser(String uid, String role) async {
    try {
      await _usersRef.child(uid).update({'status': 'active'});
      await _syncRoleDirectory(uid: uid, role: role, status: 'active');
      if (mounted) {
        showAppSnackBar(
          context,
          'User restored successfully.',
          type: AppSnackBarType.success,
        );
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'We could not restore that user right now.',
          type: AppSnackBarType.error,
        );
      }
    }
  }

  Future<void> _showLogoutDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        toolbarHeight: 82,
        titleSpacing: AppSpacing.lg,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Admin Dashboard',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.user.email ?? 'Admin',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _showLogoutDialog,
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: AppRadii.large,
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: AppRadii.large,
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                labelPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(height: 48, text: 'Pending'),
                  Tab(height: 48, text: 'Reporters'),
                  Tab(height: 48, text: 'Supervisors'),
                  Tab(height: 48, text: 'Stats'),
                ],
              ),
            ),
          ),
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
          _ActiveUsersTab(
            usersRef: _usersRef,
            role: 'reporter',
            title: 'No reporters found',
            icon: Icons.people_outline_rounded,
            accent: AppColors.primary,
            onDeactivate: _deactivateUser,
            onRestore: _restoreUser,
          ),
          _ActiveUsersTab(
            usersRef: _usersRef,
            role: 'supervisor',
            title: 'No supervisors found',
            icon: Icons.shield_outlined,
            accent: AppColors.secondary,
            onDeactivate: _deactivateUser,
            onRestore: _restoreUser,
          ),
          _StatisticsTab(usersRef: _usersRef),
        ],
      ),
    );
  }
}

class _PendingUsersTab extends StatelessWidget {
  final DatabaseReference usersRef;
  final void Function(String uid, String role) onApprove;
  final void Function(String uid, String role) onReject;

  const _PendingUsersTab({
    required this.usersRef,
    required this.onApprove,
    required this.onReject,
  });

  String _formatRequestedAt(BuildContext context, dynamic rawCreatedAt) {
    final createdAt = rawCreatedAt?.toString().trim();
    if (createdAt == null || createdAt.isEmpty) {
      return 'Requested on an unknown date';
    }

    final parsed = DateTime.tryParse(createdAt);
    if (parsed == null) {
      return 'Requested on $createdAt';
    }

    final localizations = MaterialLocalizations.of(context);
    final localTime = parsed.toLocal();
    final dateLabel = localizations.formatMediumDate(localTime);
    final timeLabel = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(localTime),
      alwaysUse24HourFormat: false,
    );

    return 'Requested on $dateLabel at $timeLabel';
  }

  String _formatRoleLabel(String role) {
    final normalized = role.trim().toLowerCase();
    if (normalized.isEmpty) return 'User';
    return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: usersRef.onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data?.snapshot.value as Map?;
        if (data == null) {
          return const AppEmptyState(
            icon: Icons.manage_accounts_outlined,
            title: 'No users found',
            description: 'New account requests will show up here.',
          );
        }

        final users = <MapEntry<String, Map<String, dynamic>>>[];
        data.forEach((uid, value) {
          final user = Map<String, dynamic>.from(value as Map);
          if ((user['status'] as String? ?? 'pending_approval') ==
              'pending_approval') {
            users.add(MapEntry(uid, user));
          }
        });

        if (users.isEmpty) {
          return AppEmptyState(
            icon: Icons.check_circle_outline_rounded,
            title: 'No pending approvals',
            description:
                'All registration requests have been reviewed. Check back later for new users.',
            actionLabel: 'Refresh',
            onAction: () {},
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final uid = users[index].key;
            final user = users[index].value;
            final role = user['role']?.toString() ?? 'user';
            final accent = role == 'supervisor'
                ? AppColors.secondary
                : AppColors.primary;

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: AppSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: AppRadii.medium,
                          ),
                          child: Icon(
                            role == 'supervisor'
                                ? Icons.shield_outlined
                                : Icons.person_outline_rounded,
                            color: accent,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'
                                    .trim(),
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user['email']?.toString() ?? 'No email',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.12),
                                  borderRadius: AppRadii.pill,
                                ),
                                child: Text(
                                  _formatRoleLabel(role),
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: accent,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _formatRequestedAt(context, user['createdAt']),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: [
                        SizedBox(
                          width: 156,
                          child: OutlinedButton.icon(
                            onPressed: () => onReject(uid, role),
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('Reject'),
                          ),
                        ),
                        SizedBox(
                          width: 156,
                          child: ElevatedButton.icon(
                            onPressed: () => onApprove(uid, role),
                            icon: const Icon(
                              Icons.check_circle_outline_rounded,
                            ),
                            label: const Text('Approve'),
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
}

class _ActiveUsersTab extends StatelessWidget {
  final DatabaseReference usersRef;
  final String role;
  final String title;
  final IconData icon;
  final Color accent;
  final void Function(String uid, String role) onDeactivate;
  final void Function(String uid, String role) onRestore;

  const _ActiveUsersTab({
    required this.usersRef,
    required this.role,
    required this.title,
    required this.icon,
    required this.accent,
    required this.onDeactivate,
    required this.onRestore,
  });

  String _formatStatusLabel(String? status) {
    final normalized = (status ?? '').trim().toLowerCase();
    if (normalized.isEmpty) return 'Unknown';
    return normalized
        .split('_')
        .map(
          (segment) => segment.isEmpty
              ? segment
              : '${segment[0].toUpperCase()}${segment.substring(1)}',
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: usersRef.onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data?.snapshot.value as Map?;
        if (data == null) {
          return AppEmptyState(
            icon: icon,
            title: title,
            description: 'No users are available in this section yet.',
          );
        }

        final users = <MapEntry<String, Map<String, dynamic>>>[];
        data.forEach((uid, value) {
          final user = Map<String, dynamic>.from(value as Map);
          final status = user['status']?.toString().toLowerCase();
          if (user['role'] == role &&
              (status == 'active' || status == 'inactive')) {
            users.add(MapEntry(uid, user));
          }
        });

        if (users.isEmpty) {
          return AppEmptyState(
            icon: icon,
            title: title,
            description: 'Users in this role will appear here.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final uid = users[index].key;
            final user = users[index].value;
            final status = user['status']?.toString() ?? '';
            final isInactive = status.toLowerCase() == 'inactive';
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: AppSectionCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: AppRadii.medium,
                    ),
                    child: Icon(icon, color: accent),
                  ),
                  title: Text(
                    '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'
                        .trim(),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(user['email']?.toString() ?? 'No email'),
                      const SizedBox(height: 8),
                      AppStatusBadge(status: _formatStatusLabel(status)),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'deactivate') {
                        onDeactivate(uid, role);
                      }
                      if (value == 'restore') {
                        onRestore(uid, role);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        value: isInactive ? 'restore' : 'deactivate',
                        child: Text(isInactive ? 'Restore' : 'Deactivate'),
                      ),
                    ],
                  ),
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data?.snapshot.value as Map?;
        if (data == null) {
          return const AppEmptyState(
            icon: Icons.bar_chart_rounded,
            title: 'No data available',
            description: 'Statistics will appear when users are added.',
          );
        }

        var totalUsers = 0;
        var activeReporters = 0;
        var activeSupervisors = 0;
        var pendingApprovals = 0;
        var rejectedUsers = 0;
        var inactiveUsers = 0;

        data.forEach((key, value) {
          final user = Map<String, dynamic>.from(value as Map);
          totalUsers++;
          final status = user['status']?.toString() ?? 'pending_approval';
          final role = user['role']?.toString();

          if (status == 'active' && role == 'reporter') activeReporters++;
          if (status == 'active' && role == 'supervisor') activeSupervisors++;
          if (status == 'pending_approval') pendingApprovals++;
          if (status == 'rejected') rejectedUsers++;
          if (status == 'inactive') inactiveUsers++;
        });

        final cards = <(String, int, IconData, Color)>[
          (
            'Total Users',
            totalUsers,
            Icons.people_outline_rounded,
            AppColors.primary,
          ),
          (
            'Active Reporters',
            activeReporters,
            Icons.person_outline_rounded,
            AppColors.success,
          ),
          (
            'Active Supervisors',
            activeSupervisors,
            Icons.shield_outlined,
            AppColors.secondary,
          ),
          (
            'Pending Approvals',
            pendingApprovals,
            Icons.hourglass_top_rounded,
            AppColors.warning,
          ),
          (
            'Rejected Users',
            rejectedUsers,
            Icons.block_outlined,
            AppColors.error,
          ),
          (
            'Inactive Users',
            inactiveUsers,
            Icons.pause_circle_outline_rounded,
            AppColors.textSecondary,
          ),
        ];

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: cards.length,
          itemBuilder: (context, index) {
            final card = cards[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: AppSectionCard(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: card.$4.withValues(alpha: 0.12),
                        borderRadius: AppRadii.medium,
                      ),
                      child: Icon(card.$3, color: card.$4),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        card.$1,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      '${card.$2}',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(color: card.$4),
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
