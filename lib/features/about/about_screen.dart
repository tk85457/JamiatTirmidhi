import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(title: const Text('About'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // App Info Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Perfectly circular icon — clipped, no square edges
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: primary.withValues(alpha: 0.4),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.2),
                          blurRadius: 20,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/icon/icon_circle.webp',
                        width: 110,
                        height: 110,
                        fit: BoxFit.cover, // Full fit in circle
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                   Text(
                   'جامع الترمذی',
                    style: GoogleFonts.amiri(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: primary,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Jami at-Tirmidhi Hadith',
                    style: GoogleFonts.rubik(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Version 1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),
            const SizedBox(height: 16),

            // About Jami at-Tirmidhi
            _buildCard(context, isDark, 'About Jami at-Tirmidhi', Icons.info_outline, [
              'Jami at-Tirmidhi is a collection of hadith compiled by Imam at-Tirmidhi (rahimahullah) in the 9th century.',
              'It is one of the six major collections of hadith (Kutub al-Sittah) and is prized for its scholarly analysis.',
              'It consists of over 3,900 ahadith divided into various chapters of law, manners, and creed.',
              'Imam Tirmidhi was the first to categorize hadiths into Sahih, Hasan, and Da\'if levels in a systematic way.',
            ], 0),
            const SizedBox(height: 12),

            // About Author
            _buildCard(
              context,
              isDark,
              'About Imam at-Tirmidhi',
              Icons.person_outline,
              [
                'Full Name: Muhammad ibn Isa as-Sulami ad-Darir al-Bughi at-Tirmidhi',
                'Born: 824 CE (209 AH) in Termez (Modern Uzbekistan)',
                'Died: 892 CE (279 AH) in Termez',
                'He was a student of Imam Bukhari and traveled extensively to gather knowledge.',
                'He is also famous for his work "ash-Shama\'il al-Muhammadiyya" on the character of the Prophet (PBUH).',
              ],
              1,
              showCircleIcon: true,
            ),
            const SizedBox(height: 12),

            // App Features
            _buildCard(context, isDark, 'App Features', Icons.star_outline, [
              '• Complete Jami at-Tirmidhi collection',
              '• Arabic, Urdu & English translations',
              '• Bookmark your favourite hadiths',
              '• Create custom collections',
              '• Powerful search functionality',
              '• Adjustable font sizes',
              '• Dark & Light mode',
              '• Notes on hadiths',
              '• Resume reading from where you left',
            ], 2),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    bool isDark,
    String title,
    IconData icon,
    List<String> items,
    int delay, {
    bool showCircleIcon = false,
  }) {
    final primary = Theme.of(context).primaryColor;

    return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: Theme.of(context).primaryColor, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
              if (showCircleIcon) ...[
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: primary.withValues(alpha: 0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.1),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/icon/icon_circle.webp',
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.5,
                      color: isDark
                          ? Colors.grey.shade300
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: (150 * delay).ms, duration: 400.ms)
        .slideY(begin: 0.05, end: 0);
  }
}
