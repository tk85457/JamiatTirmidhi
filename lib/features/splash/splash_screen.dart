import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _iconController;
  late Animation<double> _iconScale;
  late Animation<double> _iconOpacity;
  late Animation<double> _circleScale;
  late Animation<double> _circleOpacity;
  late Animation<double> _glowOpacity;
  Color _themeColor = AppTheme.primaryGreen; // Default to green

  @override
  void initState() {
    super.initState();

    // Load saved UI color
    _loadThemeColor();

    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Icon starts tiny (like an app icon) and zooms up to full size
    _iconScale = Tween<double>(begin: 0.15, end: 1.0).animate(
      CurvedAnimation(parent: _iconController, curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack)),
    );

    _iconOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _iconController, curve: const Interval(0.0, 0.3, curve: Curves.easeIn)),
    );

    // Circle border appears after icon arrives
    _circleScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _iconController, curve: const Interval(0.4, 0.8, curve: Curves.elasticOut)),
    );

    _circleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _iconController, curve: const Interval(0.35, 0.6, curve: Curves.easeIn)),
    );

    // Glow pulse after icon lands
    _glowOpacity = Tween<double>(begin: 0.0, end: 0.25).animate(
      CurvedAnimation(parent: _iconController, curve: const Interval(0.6, 1.0, curve: Curves.easeInOut)),
    );

    // Start animation after a tiny delay for native splash transition
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _iconController.forward();
    });

    _navigateToHome();
  }

  void _loadThemeColor() async {
    final prefs = await SharedPreferences.getInstance();
    final colorName = prefs.getString('uiColor') ?? 'Green';
    if (mounted) {
      setState(() {
        _themeColor = AppTheme.getPrimaryColor(colorName);
      });
    }
  }

  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

  void _navigateToHome() async {
    await Future.delayed(const Duration(milliseconds: 3500));
    if (mounted) {
      final prefs = await SharedPreferences.getInstance();
      final onboardingDone = prefs.getBool('onboarding_done') ?? false;
      if (mounted) {
        context.go(onboardingDone ? '/home' : '/onboarding');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final HSLColor hsl = HSLColor.fromColor(_themeColor);
    final darkest = hsl.withLightness((hsl.lightness * 0.35).clamp(0.0, 1.0)).toColor();
    final mid = hsl.withLightness((hsl.lightness * 0.5).clamp(0.0, 1.0)).toColor();
    final lighter = hsl.withLightness((hsl.lightness * 0.65).clamp(0.0, 1.0)).toColor();

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [darkest, mid, lighter],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 60),

              // Animated Icon — flies from 'above/forward' (simulated by scale + Y offset)
              AnimatedBuilder(
                animation: _iconController,
                builder: (context, child) {
                  // Simulate 3D forward flight with scale and Y offset
                  final yOffset = (1.0 - _iconScale.value) * -100;
                  return Opacity(
                    opacity: _iconOpacity.value,
                    child: Transform.translate(
                      offset: Offset(0, yOffset),
                      child: Transform.scale(
                        scale: _iconScale.value,
                        child: Container(
                          width: 170,
                          height: 170,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: _glowOpacity.value),
                                blurRadius: 30,
                                spreadRadius: 10,
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Decorative pulse rings for premium feel
                              if (_circleScale.value > 0.1)
                                Container(
                                  width: 170,
                                  height: 170,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.2 * _circleOpacity.value),
                                      width: 2,
                                    ),
                                  ),
                                ).animate(onPlay: (controller) => controller.repeat())
                                 .scale(duration: 2.seconds, begin: const Offset(1, 1), end: const Offset(1.2, 1.2))
                                 .fadeOut(duration: 2.seconds),

                              // Main Landing Circle
                              Opacity(
                                opacity: _circleOpacity.value,
                                child: Transform.scale(
                                  scale: _circleScale.value,
                                  child: Container(
                                    width: 165,
                                    height: 165,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          Colors.white.withValues(alpha: 0.15),
                                          Colors.transparent,
                                        ],
                                      ),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.45),
                                        width: 3,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // The app icon — perfectly circular, no square edges
                              ClipOval(
                                child: Container(
                                  width: 152,
                                  height: 152,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    // Removed white background to support new circular image with transparency
                                  ),
                                  child: Image.asset(
                                    'assets/icon/icon.png',
                                    width: 152,
                                    height: 152,
                                    fit: BoxFit.contain, // Changed to contain for perfect fit
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),

              // Bismillah
              Text(
                'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                style: GoogleFonts.amiri(
                  fontSize: 22,
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w400,
                ),
                textDirection: TextDirection.rtl,
              )
              .animate()
              .fade(delay: 800.ms, duration: 800.ms)
              .slideY(begin: 0.3, end: 0, curve: Curves.easeOut),

              const SizedBox(height: 20),

              // App Name
              Text(
                'سنن ابن ماجہ',
                style: GoogleFonts.amiri(
                  fontSize: 36,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textDirection: TextDirection.rtl,
              )
              .animate()
              .fade(delay: 1100.ms, duration: 800.ms)
              .slideY(begin: 0.5, end: 0, curve: Curves.easeOut),

              const SizedBox(height: 8),

              Text(
                'Sunan Ibn Majah',
                style: GoogleFonts.rubik(
                  fontSize: 18,
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2,
                ),
              )
              .animate()
              .fade(delay: 1400.ms, duration: 800.ms)
              .slideY(begin: 0.5, end: 0, curve: Curves.easeOut),

              const SizedBox(height: 6),

              Text(
                'A Major Collection of Hadith',
                style: GoogleFonts.rubik(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.6),
                  letterSpacing: 1,
                ),
              )
              .animate()
              .fade(delay: 1700.ms, duration: 600.ms),

              const SizedBox(height: 40),

              // Loading indicator
              SizedBox(
                width: 180,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withValues(alpha: 0.6)),
                  minHeight: 2.5,
                  borderRadius: BorderRadius.circular(2),
                ),
              )
              .animate()
              .fade(delay: 2000.ms, duration: 500.ms),

              const SizedBox(height: 12),

              Text(
                'Loading...',
                style: GoogleFonts.rubik(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              )
              .animate()
              .fade(delay: 2200.ms, duration: 400.ms),

              const SizedBox(height: 20),

              // Version
              Text(
                'v1.0.0',
                style: GoogleFonts.rubik(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              )
              .animate()
              .fade(delay: 2400.ms, duration: 400.ms),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ),
  );
}
}
