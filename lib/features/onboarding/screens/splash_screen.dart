import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/localization/app_localizations.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onFinish;
  const SplashScreen({super.key, required this.onFinish});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  int _currentSloganIndex = 0;
  Timer? _sloganTimer;
  final List<String> _sloganKeys = [
    'splash_slogan_1',
    'splash_slogan_2',
    'splash_slogan_3',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeIn)),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack)),
    );

    _controller.forward();

    // Her slogan 2.0 saniye ekranda kalsın (kullanıcının rahat okuyabilmesi için)
    _sloganTimer = Timer.periodic(const Duration(milliseconds: 2000), (timer) {
      if (mounted) {
        setState(() {
          if (_currentSloganIndex < _sloganKeys.length - 1) {
            _currentSloganIndex++;
          }
        });
      }
    });

    // 3 slogan x 2 saniye = 6 saniye sonra ana ekrana geç
    Future.delayed(const Duration(seconds: 6), () {
      _sloganTimer?.cancel();
      if (mounted) {
        widget.onFinish();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _sloganTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations(Localizations.localeOf(context));
    
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              const Color(0xFF1E293B),
              const Color(0xFF0F172A),
              Colors.black,
            ],
          ),
        ),
        child: Stack(
          children: [
            // Background particles simulation (static design for performance)
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.aiColor.withOpacity(0.05),
                ),
              ),
            ),
            
            Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Pai Branding
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.aiColor.withOpacity(0.2),
                                  blurRadius: 40,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            child: Hero(
                              tag: 'app_logo',
                              child: Column(
                                children: [
                                  const Text(
                                    'Pai',
                                    style: TextStyle(
                                      fontSize: 72,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: -2,
                                    ),
                                  ),
                                  Text(
                                    'PARAMETRA AI',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w300,
                                      color: Colors.white.withOpacity(0.6),
                                      letterSpacing: 4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 60),
                          
                          // Cycling Slogans
                          SizedBox(
                            height: 50,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 500),
                              transitionBuilder: (Widget child, Animation<double> animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0.0, 0.5),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              child: Text(
                                l10n.translate(_sloganKeys[_currentSloganIndex]) ?? '',
                                key: ValueKey<int>(_currentSloganIndex),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(0.8),
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 40),
                          const SizedBox(
                            width: 120,
                            child: LinearProgressIndicator(
                              backgroundColor: Colors.white10,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.aiColor),
                              minHeight: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
