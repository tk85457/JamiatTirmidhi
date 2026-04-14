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
      appBar: AppBar(
        title: const Text('About'),
        centerTitle: true,
      ),
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
                      border: Border.all(color: primary.withValues(alpha: 0.4), width: 3),
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
                        'assets/icon/icon.png',
                        width: 110,
                        height: 110,
                        fit: BoxFit.contain, // Changed to contain for perfect fit
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'سنن ابن ماجہ',
                    style: GoogleFonts.amiri(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: primary,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sunan Ibn Majah',
                    style: GoogleFonts.rubik(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Version 1.0.0',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),
            const SizedBox(height: 16),

            // About Sunan Ibn Majah
            _buildCard(context, isDark, 'About Sunan Ibn Majah', Icons.info_outline, [
              'Sunan Ibn Majah is a collection of hadith compiled by Imam Ibn Majah (rahimahullah) in the 9th century.',
              'It is widely considered to be the sixth of the six major collections of hadith (Kutub al-Sittah).',
              'It consists of over 4,000 ahadith divided into 32 books.',
              'The collection is highly regarded for its comprehensive coverage of Fiqh (jurisprudence) topics.',
            ], 0),
            const SizedBox(height: 12),

            // About Author
            _buildCard(context, isDark, 'About Imam Ibn Majah', Icons.person_outline, [
              'Full Name: Abu Abdullah Muhammad ibn Yazid Ibn Majah al-Rabai al-Qazwini',
              'Born: 824 CE (209 AH) in Qazvin, present-day Iran',
              'Died: 887 CE (273 AH) in Qazvin',
              'He traveled widely across the Islamic world to Iraq, Hejaz, Syria, and Egypt to gather hadiths.',
              'He was a prominent student of many great scholars of his time and a renowned traditionalist.',
            ], 1),
            const SizedBox(height: 12),

            // App Features
            _buildCard(context, isDark, 'App Features', Icons.star_outline, [
              '• Complete Sunan Ibn Majah collection',
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

  Widget _buildCard(BuildContext context, bool isDark, String title, IconData icon, List<String> items, int delay) {
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
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              item,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
          )),
        ],
      ),
    ).animate().fadeIn(delay: (150 * delay).ms, duration: 400.ms).slideY(begin: 0.05, end: 0);
  }
}
