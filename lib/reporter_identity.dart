import 'package:firebase_auth/firebase_auth.dart';

class ReporterIdentity {
  final String uid;
  final String? email;
  final String displayName;

  const ReporterIdentity({
    required this.uid,
    required this.displayName,
    this.email,
  });

  factory ReporterIdentity.fromFirebaseUser(User user) {
    final fallbackName = user.email?.split('@').first ?? 'Reporter';
    return ReporterIdentity(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : fallbackName,
    );
  }

  factory ReporterIdentity.fromJson(Map<String, dynamic> json) {
    return ReporterIdentity(
      uid: json['uid']?.toString() ?? '',
      email: json['email']?.toString(),
      displayName: json['displayName']?.toString() ?? 'Reporter',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
    };
  }
}
