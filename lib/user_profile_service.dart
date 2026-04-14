import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'reporter_identity.dart';

class UserProfile {
  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final String role;
  final String status;
  final Map<String, dynamic> raw;

  const UserProfile({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.status,
    required this.raw,
  });

  String get displayName {
    final fullName = '$firstName $lastName'.trim();
    if (fullName.isNotEmpty) {
      return fullName;
    }
    if (email.isNotEmpty) {
      return email;
    }
    return uid;
  }

  bool get isPendingApproval => status == 'pending_approval';
  bool get isRejected => status == 'rejected';
  bool get isInactive => status == 'inactive';

  factory UserProfile.fromMap(String uid, Map<Object?, Object?> data) {
    final mapped = Map<String, dynamic>.from(data);
    return UserProfile(
      uid: uid,
      email: mapped['email']?.toString() ?? '',
      firstName: mapped['firstName']?.toString() ?? '',
      lastName: mapped['lastName']?.toString() ?? '',
      role: mapped['role']?.toString().toLowerCase() ?? '',
      status: mapped['status']?.toString().toLowerCase() ?? 'pending_approval',
      raw: mapped,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> data) {
    return UserProfile(
      uid: data['uid']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      firstName: data['firstName']?.toString() ?? '',
      lastName: data['lastName']?.toString() ?? '',
      role: data['role']?.toString().toLowerCase() ?? '',
      status: data['status']?.toString().toLowerCase() ?? 'pending_approval',
      raw: Map<String, dynamic>.from(data['raw'] as Map? ?? const {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'role': role,
      'status': status,
      'raw': raw,
    };
  }
}

class UserProfileService {
  UserProfileService({DatabaseReference? rootRef, SharedPreferences? preferences})
      : _rootRef = rootRef,
        _preferencesFuture = preferences != null
            ? Future.value(preferences)
            : SharedPreferences.getInstance();

  final DatabaseReference? _rootRef;
  final Future<SharedPreferences> _preferencesFuture;
  static const String _cachePrefix = 'cached_user_profile_';
  static const String _offlineReporterSessionKey = 'offline_reporter_session_v1';

  DatabaseReference get _databaseRoot => _rootRef ?? FirebaseDatabase.instance.ref();

  Future<UserProfile?> fetchProfile(String uid) async {
    final snapshot = await _databaseRoot.child('users').child(uid).get();
    if (!snapshot.exists || snapshot.value == null) {
      return null;
    }

    final rawValue = snapshot.value;
    if (rawValue is! Map<Object?, Object?>) {
      throw const FormatException('User profile has an invalid structure.');
    }

    final profile = UserProfile.fromMap(uid, rawValue);
    if (profile.role.isEmpty) {
      throw const FormatException('User profile is missing a role.');
    }

    await _cacheProfile(profile);

    return profile;
  }

  Future<String?> fetchRole(String uid) async {
    final profile = await fetchProfile(uid);
    return profile?.role;
  }

  Future<UserProfile?> getCachedProfile(String uid) async {
    final preferences = await _preferencesFuture;
    final raw = preferences.getString('$_cachePrefix$uid');
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final profile = UserProfile.fromJson(decoded);
      return profile.role.isEmpty ? null : profile;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCachedProfile(String uid) async {
    final preferences = await _preferencesFuture;
    await preferences.remove('$_cachePrefix$uid');
  }

  Future<void> cacheOfflineReporterSession({
    required UserProfile profile,
    required User user,
  }) async {
    if (profile.role != 'reporter' ||
        profile.isInactive ||
        profile.isPendingApproval ||
        profile.isRejected) {
      await clearOfflineReporterSession();
      return;
    }

    final identity = ReporterIdentity(
      uid: user.uid,
      email: user.email,
      displayName: profile.displayName,
    );

    final preferences = await _preferencesFuture;
    await preferences.setString(
      _offlineReporterSessionKey,
      jsonEncode(identity.toJson()),
    );
  }

  Future<ReporterIdentity?> getOfflineReporterSession() async {
    final preferences = await _preferencesFuture;
    final raw = preferences.getString(_offlineReporterSessionKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      return ReporterIdentity.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clearOfflineReporterSession() async {
    final preferences = await _preferencesFuture;
    await preferences.remove(_offlineReporterSessionKey);
  }

  Future<void> _cacheProfile(UserProfile profile) async {
    final preferences = await _preferencesFuture;
    await preferences.setString(
      '$_cachePrefix${profile.uid}',
      jsonEncode(profile.toJson()),
    );
  }
}
