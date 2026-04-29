import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF0F5D75);
  static const Color primaryDark = Color(0xFF0A4659);
  static const Color secondary = Color(0xFF2F7E79);
  static const Color accent = Color(0xFFE29B2D);

  static const Color background = Color(0xFFF4F7F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFE8EEF1);
  static const Color surfaceRaised = Color(0xFFFBFCFD);

  static const Color textPrimary = Color(0xFF1B2A34);
  static const Color textSecondary = Color(0xFF5F6F7A);
  static const Color outline = Color(0xFFD7E0E5);

  static const Color success = Color(0xFF2E8B57);
  static const Color warning = Color(0xFFD98A1E);
  static const Color error = Color(0xFFC44536);
  static const Color info = Color(0xFF2F7DD1);
  static const Color critical = Color(0xFFB45348);
  static const Color highPriority = Color(0xFFD98A1E);
  static const Color mediumPriority = Color(0xFFB88C37);
  static const Color lowPriority = Color(0xFF4C86C6);

  static const Color statusOpen = warning;
  static const Color statusActive = info;
  static const Color statusClosed = success;

  static const Color admin = Color(0xFF5B4DB1);
  static const Color reporter = primary;
  static const Color supervisor = secondary;

  static const Color overlay = Color(0x990E1E29);

  static const LinearGradient authGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDark, primary, secondary],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, secondary],
  );

  static const LinearGradient analyticsGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondary, primary],
  );
}

class AppRadii {
  static final BorderRadius small = BorderRadius.circular(10);
  static final BorderRadius medium = BorderRadius.circular(14);
  static final BorderRadius large = BorderRadius.circular(18);
  static final BorderRadius xl = BorderRadius.circular(22);
  static final BorderRadius pill = BorderRadius.circular(999);
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double section = 28;
}

class AppShadows {
  static List<BoxShadow> soft(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.10),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> subtle = [
    BoxShadow(
      color: AppColors.textPrimary.withValues(alpha: 0.06),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];
}

class AppStatusStyle {
  final Color color;
  final IconData icon;
  final String label;

  const AppStatusStyle({
    required this.color,
    required this.icon,
    required this.label,
  });
}

class AppStatus {
  static AppStatusStyle resolve(String? rawStatus) {
    switch ((rawStatus ?? '').toLowerCase()) {
      case 'closed':
      case 'resolved':
      case 'approved':
      case 'completed':
        return const AppStatusStyle(
          color: AppColors.statusClosed,
          icon: Icons.check_circle,
          label: 'Resolved',
        );
      case 'active':
      case 'processing':
      case 'in_progress':
      case 'pending_approval':
        return const AppStatusStyle(
          color: AppColors.statusActive,
          icon: Icons.autorenew_rounded,
          label: 'In Progress',
        );
      case 'open':
      case 'pending':
      case 'awaiting_review':
        return const AppStatusStyle(
          color: AppColors.statusOpen,
          icon: Icons.hourglass_top_rounded,
          label: 'Pending',
        );
      case 'rejected':
      case 'failed':
      case 'inactive':
      case 'disabled':
        return const AppStatusStyle(
          color: AppColors.error,
          icon: Icons.cancel_rounded,
          label: 'Attention',
        );
      default:
        return const AppStatusStyle(
          color: AppColors.textSecondary,
          icon: Icons.info_outline_rounded,
          label: 'Unknown',
        );
    }
  }
}

class AppPriorityStyle {
  final Color color;
  final IconData icon;
  final String label;

  const AppPriorityStyle({
    required this.color,
    required this.icon,
    required this.label,
  });
}

class AppPriority {
  static AppPriorityStyle resolve(String? rawPriority) {
    switch ((rawPriority ?? '').toLowerCase()) {
      case 'critical':
        return const AppPriorityStyle(
          color: AppColors.critical,
          icon: Icons.priority_high_rounded,
          label: 'Critical',
        );
      case 'high':
        return const AppPriorityStyle(
          color: AppColors.highPriority,
          icon: Icons.warning_amber_rounded,
          label: 'High',
        );
      case 'medium':
        return const AppPriorityStyle(
          color: AppColors.mediumPriority,
          icon: Icons.remove_moderator_outlined,
          label: 'Medium',
        );
      case 'low':
        return const AppPriorityStyle(
          color: AppColors.lowPriority,
          icon: Icons.low_priority_rounded,
          label: 'Low',
        );
      default:
        return const AppPriorityStyle(
          color: AppColors.textSecondary,
          icon: Icons.label_outline_rounded,
          label: 'Not set',
        );
    }
  }
}

class AppTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      error: AppColors.error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.textPrimary,
      onError: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.large),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.45),
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.medium),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.medium),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.outline),
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.medium),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceRaised,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadii.medium,
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.medium,
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.medium,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.medium,
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadii.medium,
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceMuted,
        selectedColor: AppColors.primary.withValues(alpha: 0.12),
        disabledColor: AppColors.surfaceMuted,
        deleteIconColor: AppColors.textSecondary,
        labelStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.pill),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.xl),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.medium),
      ),
      dividerColor: AppColors.outline,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          height: 1.15,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          height: 1.2,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        titleSmall: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: AppColors.textPrimary,
          height: 1.45,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: AppColors.textPrimary,
          height: 1.45,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
          height: 1.4,
        ),
      ),
    );
  }
}
