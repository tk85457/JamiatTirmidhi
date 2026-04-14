import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last updated: April 2026',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ).animate().fadeIn(duration: 400.ms),
            const SizedBox(height: 24),

            _buildSection(
              isDark,
              'Introduction',
              'Welcome to Sunan Ibn Majah. We respect your privacy and are committed to protecting your personal data. This privacy policy will inform you as to how we look after your personal data when you visit our application and tell you about your privacy rights.',
            ),

            _buildSection(
              isDark,
              'Data Collection',
              'We only collect the data necessary for the application to function. "Sunan Ibn Majah" stores data locally on your device for features such as bookmarks, notes, and reading progress. We do not collect or transmit personal information to our servers.',
            ),

            _buildSection(
              isDark,
              'Permissions',
              'The application may request certain permissions (such as storage access) strictly to save your preferences, downloaded data, and backups. We do not access other files on your device.',
            ),

            _buildSection(
              isDark,
              'Data Storage',
              'All your personal data, including bookmarks and notes, are stored securely using local databases (Isar) on your device. You have the option to back up your data locally or export it manually.',
            ),

            _buildSection(
              isDark,
              'Third-Party Services',
              'We may use third-party services like Firebase Crashlytics or Google Analytics to improve the app\'s stability and performance. These services collect anonymous crash reports and usage data. They do not track your specific reading habits or personal identity.',
            ),

            _buildSection(
              isDark,
              'Changes to this Policy',
              'We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page. You are advised to review this Privacy Policy periodically for any changes.',
            ),

            _buildSection(
              isDark,
              'Contact Us',
              'If you have any questions about this Privacy Policy, please contact us via the support section in the app or via our support email.',
            ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(bool isDark, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
          ),
        ],
      ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0),
    );
  }
}
