import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/onboarding_service.dart';
import '../../../core/localization/app_localizations.dart';

class ModuleIntroCard extends ConsumerStatefulWidget {
  final String moduleId;
  final String title;
  final String description;
  final String imagePath;
  final Color themeColor;
  final VoidCallback onDismiss;

  const ModuleIntroCard({
    super.key,
    required this.moduleId,
    required this.title,
    required this.description,
    required this.imagePath,
    required this.themeColor,
    required this.onDismiss,
  });

  @override
  ConsumerState<ModuleIntroCard> createState() => _ModuleIntroCardState();
}

class _ModuleIntroCardState extends ConsumerState<ModuleIntroCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _dontShowAgain = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            widget.themeColor.withOpacity(0.15),
            const Color(0xFF0F172A),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.35,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: widget.themeColor.withOpacity(0.2),
                          blurRadius: 40,
                          spreadRadius: -10,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      widget.imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.white10,
                        child: Icon(Icons.image, size: 80, color: widget.themeColor),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 48),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  widget.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.7),
                    height: 1.5,
                  ),
                ),
              ),
              const Spacer(),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Checkbox(
                      value: _dontShowAgain,
                      onChanged: (val) => setState(() => _dontShowAgain = val ?? false),
                      activeColor: widget.themeColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    Text(
                      context.l10n('dont_show_again'),
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FadeTransition(
                opacity: _fadeAnimation,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_dontShowAgain) {
                      await ref.read(onboardingServiceProvider).markAsShown(widget.moduleId);
                    }
                    widget.onDismiss();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.themeColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 60),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 10,
                    shadowColor: widget.themeColor.withOpacity(0.4),
                  ),
                  child: Text(context.l10n('continue_btn'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
