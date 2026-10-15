import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/ads/ad_service.dart';
import '../../core/services/in_app_review_service.dart';
import '../../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _iconController;
  late Animation<double> _iconScale;
  late Animation<double> _iconOpacity;
  late Animation<double> _circleScale;
  late Animation<double> _circleOpacity;
  late Animation<double> _glowOpacity;
  Color _themeColor = const Color(
    0xFF00382E,
  ); // Default to circular icon's darkest green

  @override
  void initState() {
    super.initState();

    // Load saved UI color
    _loadThemeColor();

    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Icon starts tiny (like an app icon) and zooms up to full size
    _iconScale = Tween<double>(begin: 0.15, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );

    _iconOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    // Circle border appears after icon arrives
    _circleScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconController,
        curve: const Interval(0.4, 0.8, curve: Curves.elasticOut),
      ),
    );

    _circleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconController,
        curve: const Interval(0.35, 0.6, curve: Curves.easeIn),
      ),
    );

    // Glow pulse after icon lands
    _glowOpacity = Tween<double>(begin: 0.0, end: 0.25).animate(
      CurvedAnimation(
        parent: _iconController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeInOut),
      ),
    );

    // Start animation after a tiny delay for native splash transition
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) _iconController.forward();
    });

    _navigateToHome();
  }

  void _loadThemeColor() async {
    final prefs = await SharedPreferences.getInstance();
    final colorName = prefs.getString('uiColor') ?? 'Rose';
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

  Future<void> _navigateToHome() async {
    // Ads consent (UMP) + MobileAds init and the app-open counter run in the
    // background. They must NEVER block start-up (this used to cost up to
    // 10 s on slow networks / low-end phones).
    _runInBackground();

    final results = await Future.wait([
      // Just long enough for the logo animation to finish (was 2.5 s).
      Future.delayed(const Duration(milliseconds: 1200)),
      SharedPreferences.getInstance(),
    ]);

    if (!mounted) return;
    final prefs = results[1] as SharedPreferences;
    final onboardingDone = prefs.getBool('onboarding_done') ?? false;
    context.go(onboardingDone ? '/home' : '/language-select');
  }

  Future<void> _runInBackground() async {
    try {
      await AdService.gatherConsentAndInitialize();
    } catch (e) {
      debugPrint('Background consent/ads init error: $e');
    }
    try {
      await InAppReviewService.recordAppOpen();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final HSLColor hsl = HSLColor.fromColor(_themeColor);
    final darkest = hsl
        .withLightness((hsl.lightness * 0.35).clamp(0.0, 1.0))
        .toColor();
    final mid = hsl
        .withLightness((hsl.lightness * 0.5).clamp(0.0, 1.0))
        .toColor();
    final lighter = hsl
        .withLightness((hsl.lightness * 0.65).clamp(0.0, 1.0))
        .toColor();

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
                                  color: Colors.white.withValues(
                                    alpha: _glowOpacity.value,
                                  ),
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
                                            color: Colors.white.withValues(
                                              alpha: 0.2 * _circleOpacity.value,
                                            ),
                                            width: 2,
                                          ),
                                        ),
                                      )
                                      .animate(
                                        onPlay: (controller) =>
                                            controller.repeat(),
                                      )
                                      .scale(
                                        duration: 2.seconds,
                                        begin: const Offset(1, 1),
                                        end: const Offset(1.2, 1.2),
                                      )
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
                                            Colors.white.withValues(
                                              alpha: 0.15,
                                            ),
                                            Colors.transparent,
                                          ],
                                        ),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.45,
                                          ),
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
                                      'assets/icon/icon_circle.webp',
                                      width: 152,
                                      height: 152,
                                      fit: BoxFit.cover, // Covered full circle
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
                    .fade(delay: 250.ms, duration: 500.ms)
                    .slideY(begin: 0.3, end: 0, curve: Curves.easeOut),

                const SizedBox(height: 20),

                // App Name
                Text(
                      'جامع الترمذی',
                      style: GoogleFonts.amiri(
                        fontSize: 36,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textDirection: TextDirection.rtl,
                    )
                    .animate()
                    .fade(delay: 400.ms, duration: 500.ms)
                    .slideY(begin: 0.5, end: 0, curve: Curves.easeOut),

                const SizedBox(height: 8),

                Text(
                      'Jami at-Tirmidhi',
                      style: GoogleFonts.rubik(
                        fontSize: 18,
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 2,
                      ),
                    )
                    .animate()
                    .fade(delay: 550.ms, duration: 500.ms)
                    .slideY(begin: 0.5, end: 0, curve: Curves.easeOut),

                const SizedBox(height: 6),

                Text(
                  'A Major Collection of Hadith',
                  style: GoogleFonts.rubik(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                    letterSpacing: 1,
                  ),
                ).animate().fade(delay: 700.ms, duration: 400.ms),

                const SizedBox(height: 40),

                // Loading indicator
                SizedBox(
                  width: 180,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withValues(alpha: 0.6),
                    ),
                    minHeight: 2.5,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ).animate().fade(delay: 800.ms, duration: 300.ms),

                const SizedBox(height: 12),

                Text(
                  'Loading...',
                  style: GoogleFonts.rubik(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ).animate().fade(delay: 900.ms, duration: 300.ms),

                const SizedBox(height: 20),

                // Version — kept in sync with pubspec.yaml version 1.1.8+10
                Text(
                  'v1.1.8',
                  style: GoogleFonts.rubik(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ).animate().fade(delay: 1000.ms, duration: 300.ms),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
