import 'dart:async';

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'offline_incident_queue_service.dart';
import 'reporter.dart';
import 'reporter_identity.dart';

class OfflineReporterHome extends StatefulWidget {
  final ReporterIdentity reporter;

  const OfflineReporterHome({super.key, required this.reporter});

  @override
  State<OfflineReporterHome> createState() => _OfflineReporterHomeState();
}

class _OfflineReporterHomeState extends State<OfflineReporterHome> {
  final OfflineIncidentQueueService _offlineQueueService =
      OfflineIncidentQueueService();
  StreamSubscription<bool>? _onlineSubscription;
  StreamSubscription<int>? _pendingSubscription;
  bool _isOnline = false;
  bool _syncing = false;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _onlineSubscription?.cancel();
    _pendingSubscription?.cancel();
    _offlineQueueService.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _refreshStatus();
    if (mounted) {
      setState(() {});
    }

    _pendingSubscription = _offlineQueueService
        .watchPendingCount(widget.reporter.uid)
        .listen((count) {
          if (!mounted) return;
          setState(() => _pendingCount = count);
        });

    _onlineSubscription = _offlineQueueService.onlineStatusStream.listen((
      isOnline,
    ) {
      if (!mounted) return;
      setState(() => _isOnline = isOnline);
      if (isOnline) {
        unawaited(_syncPendingReports(silent: true));
      }
    });
  }

  Future<void> _refreshStatus() async {
    _isOnline = await _offlineQueueService.isOnline();
    _pendingCount = await _offlineQueueService.getPendingCount(
      widget.reporter.uid,
    );
  }

  Future<void> _syncPendingReports({bool silent = false}) async {
    if (_syncing) return;

    setState(() => _syncing = true);
    try {
      final synced = await _offlineQueueService.syncPendingReportsForUser(
        widget.reporter.uid,
      );
      final pending = await _offlineQueueService.getPendingCount(widget.reporter.uid);
      if (!mounted) return;
      setState(() => _pendingCount = pending);

      if (!silent && synced > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              synced == 1
                  ? '1 offline report synced successfully.'
                  : '$synced offline reports synced successfully.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Offline Reporting')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: AppRadii.large,
              boxShadow: AppShadows.soft(AppColors.primary),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, ${widget.reporter.displayName}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You are using offline reporter mode. You can create reports on this device and sync them later.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (_isOnline ? AppColors.success : AppColors.warning)
                  .withValues(alpha: 0.12),
              borderRadius: AppRadii.large,
              border: Border.all(
                color: (_isOnline ? AppColors.success : AppColors.warning)
                    .withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isOnline
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_off_outlined,
                  color: _isOnline ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isOnline
                        ? 'Internet is back. Pending offline reports can sync now.'
                        : 'No internet connection. New reports will be stored locally.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadii.large,
              boxShadow: AppShadows.subtle,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.12),
                    borderRadius: AppRadii.medium,
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: AppColors.info,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pending offline reports',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _pendingCount == 0
                            ? 'No locally queued reports yet.'
                            : '$_pendingCount report${_pendingCount == 1 ? '' : 's'} waiting to sync.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: (!_isOnline || _syncing || _pendingCount == 0)
                      ? null
                      : () => _syncPendingReports(),
                  icon: _syncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: Text(_syncing ? 'Syncing' : 'Sync'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      ReportIncidentForm(
                        reporter: widget.reporter,
                        forceOffline: true,
                      ),
                ),
              ).then((_) async {
                await _refreshStatus();
                if (mounted) {
                  setState(() {});
                }
              });
            },
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Create Offline Report'),
          ),
          const SizedBox(height: 12),
          Text(
            'Live dashboards, notifications, and online report history will return after internet connectivity is restored.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
