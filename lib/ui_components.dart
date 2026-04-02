import 'package:flutter/material.dart';

/// Modern AppBar with gradient background and custom styling
class ModernAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Color> gradientColors;
  final VoidCallback? onBackPressed;
  final List<Widget>? actions;

  const ModernAppBar({
    super.key,
    required this.title,
    required this.gradientColors,
    this.onBackPressed,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        leading: onBackPressed != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: onBackPressed,
              )
            : null,
        actions: actions,
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// Modern TextField with custom styling and animations
class ModernTextField extends StatefulWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final String? Function(String?)? validator;
  final int maxLines;
  final int minLines;
  final TextInputType keyboardType;
  final VoidCallback? onSuffixIconPressed;
  final bool obscureText;

  const ModernTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.maxLines = 1,
    this.minLines = 1,
    this.keyboardType = TextInputType.text,
    this.onSuffixIconPressed,
    this.obscureText = false,
  });

  @override
  State<ModernTextField> createState() => _ModernTextFieldState();
}

class _ModernTextFieldState extends State<ModernTextField>
    with SingleTickerProviderStateMixin {
  late FocusNode _focusNode;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.95, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        obscureText: widget.obscureText,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        keyboardType: widget.keyboardType,
        validator: widget.validator,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          prefixIcon: widget.prefixIcon != null
              ? Icon(widget.prefixIcon, color: Colors.grey.shade600)
              : null,
          suffixIcon: widget.suffixIcon != null
              ? IconButton(
                  icon: Icon(widget.suffixIcon, color: Colors.grey.shade600),
                  onPressed: widget.onSuffixIconPressed,
                )
              : null,
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.blue.shade500,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red.shade500, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red.shade500, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          labelStyle: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

/// Modern Card with shadow and border radius
class ModernCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double elevation;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  const ModernCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.elevation = 4,
    this.backgroundColor,
    this.onTap,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: elevation,
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      color: backgroundColor ?? Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// Modern Button with gradient and loading state
class ModernButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;
  final IconData? icon;
  final double width;
  final double height;
  final List<Color>? gradientColors;
  final Color? backgroundColor;

  const ModernButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width = double.infinity,
    this.height = 56,
    this.gradientColors,
    this.backgroundColor,
  });

  @override
  State<ModernButton> createState() => _ModernButtonState();
}

class _ModernButtonState extends State<ModernButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _animationController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _animationController.reverse();
  }

  void _onTapCancel() {
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final defaultGradient = [
      Colors.blue.shade400,
      Colors.blue.shade600,
    ];

    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 0.95).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
      ),
      child: GestureDetector(
        onTapDown: widget.isLoading ? null : _onTapDown,
        onTapUp: widget.isLoading ? null : _onTapUp,
        onTapCancel: widget.isLoading ? null : _onTapCancel,
        onTap: widget.isLoading ? null : widget.onPressed,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: widget.gradientColors != null
                ? LinearGradient(
                    colors: widget.gradientColors!,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: defaultGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: widget.isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withOpacity(0.9),
                        ),
                        strokeWidth: 2.5,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null)
                          Icon(
                            widget.icon,
                            color: Colors.white,
                            size: 20,
                          ),
                        if (widget.icon != null) const SizedBox(width: 8),
                        Text(
                          widget.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
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

/// Modern Chip widget for tags/badges
class ModernChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final Color? backgroundColor;
  final Color? textColor;

  const ModernChip({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.onDelete,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: (backgroundColor ?? Colors.blue).withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null)
                Icon(
                  icon,
                  size: 16,
                  color: textColor ?? (backgroundColor ?? Colors.blue),
                ),
              if (icon != null) const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: textColor ?? (backgroundColor ?? Colors.blue),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              if (onDelete != null) const SizedBox(width: 6),
              if (onDelete != null)
                InkWell(
                  onTap: onDelete,
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: textColor ?? (backgroundColor ?? Colors.blue),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
