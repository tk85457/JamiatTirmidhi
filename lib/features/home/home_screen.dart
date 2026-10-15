import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme/app_theme.dart';
import '../../data/repositories/hadith_repository.dart';
import '../../domain/models/models.dart';
import '../settings/settings_provider.dart';
import '../common/widgets/shimmer_loading.dart';
import '../../core/ads/ad_free_service.dart';
import '../../widgets/ad_choice_dialog.dart';

final chaptersProvider = FutureProvider<List<Chapter>>((ref) async {
  final repo = ref.watch(hadithRepositoryProvider);
  return repo.getChapters();
});

final hadithOfTheDayProvider = FutureProvider<Hadith?>((ref) async {
  final repo = ref.watch(hadithRepositoryProvider);
  return repo.getHadithOfTheDay();
});

final statsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(hadithRepositoryProvider);
  final bookmarks = await repo.getBookmarkCount();
  final notes = await repo.getNotesCount();
  final readChapters = await repo.getTotalReadChapters();
  final totalChapters = await repo
      .getTotalChapterCount(); // Need to implement this
  final progress = totalChapters > 0
      ? (readChapters / totalChapters * 100).round()
      : 0;
  return {
    'bookmarks': bookmarks,
    'notes': notes,
    'chapters': readChapters,
    'progress': progress,
  };
});

final chapterProgressProvider = FutureProvider<Map<int, double>>((ref) async {
  final repo = ref.watch(hadithRepositoryProvider);
  final rows = await repo.getAllChapterProgress();
  final Map<int, double> progress = {};
  for (final row in rows) {
    final id = row['id'] as int;
    final hadithCount = (row['hadith_count'] as int?) ?? 1;
    final hadithIndex = (row['hadith_index'] as int?) ?? 0;
    progress[id] = hadithCount > 0
        ? (hadithIndex / hadithCount).clamp(0.0, 1.0)
        : 0.0;
  }
  return progress;
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chaptersAsync = ref.watch(chaptersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AdChoicePromptHost(
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Jami at-Tirmidhi Hadith',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          centerTitle: true,
          actions: [
            // Replaces the old "watch rewarded ad" icon: opens the 24h ad-free choice.
            ValueListenableBuilder<bool>(
              valueListenable: AdFreeService.adFreeNotifier,
              builder: (context, adFree, _) => IconButton(
                icon: Icon(
                  adFree ? Icons.verified_rounded : Icons.volunteer_activism,
                  color: adFree ? Colors.greenAccent : Colors.amber,
                ),
                tooltip: adFree
                    ? 'Banner ads are off'
                    : 'Remove banner ads for 24 hours',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  AdChoiceDialog.show(context);
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                HapticFeedback.lightImpact();
                context.go('/home/settings');
              },
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                HapticFeedback.selectionClick();
                switch (value) {
                  case 'Backup':
                    _showBackupDialog(context, ref);
                    break;
                  case 'Author':
                    context.go('/home/about');
                    break;
                  case 'AppIntro':
                    context.go('/home/about');
                    break;
                  case 'PrivacyPolicy':
                    context.go('/home/privacy');
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'Backup',
                  child: Text('Backup and Restore Data'),
                ),
                const PopupMenuItem(
                  value: 'Author',
                  child: Text('Author Introduction'),
                ),
                const PopupMenuItem(
                  value: 'AppIntro',
                  child: Text('App Introduction'),
                ),
                const PopupMenuItem(
                  value: 'PrivacyPolicy',
                  child: Text('Privacy Policy'),
                ),
              ],
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            HapticFeedback.mediumImpact();
            ref.invalidate(chaptersProvider);
            ref.invalidate(hadithOfTheDayProvider);
            ref.invalidate(statsProvider);
            ref.invalidate(chapterProgressProvider);
          },
          child: CustomScrollView(
            slivers: [
              // Grid Menu
              SliverToBoxAdapter(
                child: _buildGridMenu(context, ref, isDark),
              ),
              // Hadith of the Day (Premium Card)
              SliverToBoxAdapter(
                child: _buildHadithOfTheDay(context, ref, isDark),
              ),
              // Stats Dashboard
              SliverToBoxAdapter(
                child: _buildStatsDashboard(context, ref, isDark),
              ),
              // Search Bar
              SliverToBoxAdapter(
                child: _buildSearchBar(context, isDark),
              ),
              chaptersAsync.when(
                loading: () => SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        ShimmerLoading(child: ShimmerLoading.chapterCard()),
                    childCount: 6,
                  ),
                ),
                error: (e, st) => SliverFillRemaining(
                  child: Center(child: Text('Error: $e')),
                ),
                data: (chapters) {
                  final progressAsync = ref.watch(chapterProgressProvider);
                  final progressMap = progressAsync.value ?? {};
                  return SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final chapter = chapters[index];
                      final progress = progressMap[chapter.id];
                      return _ChapterCard(
                        chapter: chapter,
                        index: index,
                        isDark: isDark,
                        progress: progress,
                      );
                    }, childCount: chapters.length),
                  );
                },
              ),
              // Bottom padding
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
            ],
          ),
        ),
        floatingActionButton: _buildResumeButton(context, ref, isDark),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Widget _buildHadithOfTheDay(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
  ) {
    final hadithAsync = ref.watch(hadithOfTheDayProvider);
    final settings = ref.watch(settingsProvider);

    return hadithAsync.when(
      loading: () => const SizedBox(
        height: 150,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (hadith) {
        if (hadith == null) return const SizedBox.shrink();
        final primary = Theme.of(context).primaryColor;
        // Create darker and lighter variants for gradient
        final HSLColor hsl = HSLColor.fromColor(primary);
        final darkVariant = hsl
            .withLightness((hsl.lightness * 0.5).clamp(0.0, 1.0))
            .toColor();
        final midVariant = hsl
            .withLightness((hsl.lightness * 0.7).clamp(0.0, 1.0))
            .toColor();
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [darkVariant.withValues(alpha: 0.9), midVariant]
                  : [darkVariant, midVariant],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Positioned(
                  right: -20,
                  top: -20,
                  child: Icon(
                    Icons.format_quote,
                    size: 150,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () async {
                      HapticFeedback.heavyImpact();
                      final repo = ref.read(hadithRepositoryProvider);
                      final idx = await repo.getHadithIndexWithinChapter(
                        hadith.chapterId,
                        hadith.hadithNumber,
                      );
                      if (context.mounted) {
                        context.go(
                          '/home/chapter/${hadith.chapterId}?startIndex=$idx',
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: Colors.amber.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.auto_awesome,
                                      color: Colors.amber,
                                      size: 14,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'آج کی حدیث',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'آج کی حدیث',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (hadith.urduText.isNotEmpty)
                            Text(
                              hadith.urduText.length > 250
                                  ? '${hadith.urduText.substring(0, 250)}...'
                                  : hadith.urduText,
                              textAlign: TextAlign.right,
                              textDirection: TextDirection.rtl,
                              style: AppTheme.safeGetFont(
                                settings.urduFontFamily,
                                color: Colors.white,
                                fontSize: 18,
                                height: 1.8,
                              ),
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                'مکمل پڑھیں',
                                style: TextStyle(
                                  color: Colors.amber.shade200,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.amber.shade200,
                                size: 14,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsDashboard(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
  ) {
    final statsAsync = ref.watch(statsProvider);

    return statsAsync.when(
      loading: () => const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (stats) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.insights, color: Color(0xFF0A7E47), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'پڑھنے کی تفصیلات (Insights)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _statsItem(
                    context,
                    'بک مارکس',
                    '${stats['bookmarks']}',
                    Icons.bookmark_added,
                    const Color(0xFFE91E63),
                  ),
                  _statsItem(
                    context,
                    'نوٹس',
                    '${stats['notes']}',
                    Icons.note_alt,
                    const Color(0xFF2196F3),
                  ),
                  _statsItem(
                    context,
                    'پیش رفت',
                    '${stats['progress']}%',
                    Icons.auto_graph,
                    const Color(0xFF0A7E47),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statsItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridMenu(BuildContext context, WidgetRef ref, bool isDark) {
    final menuItems = [
      _GridItem(
        Icons.find_in_page_rounded,
        const Color(0xFF1565C0),
        'Find Hadith',
        () {
          HapticFeedback.lightImpact();
          _showFindHadithDialog(context, ref);
        },
      ),
      _GridItem(Icons.search_rounded, const Color(0xFFE65100), 'Search', () {
        HapticFeedback.lightImpact();
        context.go('/home/search');
      }),
      _GridItem(
        Icons.bookmark_rounded,
        const Color(0xFFC62828),
        'Bookmarks',
        () {
          HapticFeedback.lightImpact();
          context.go('/home/bookmarks');
        },
      ),
      _GridItem(
        Icons.sticky_note_2_rounded,
        const Color(0xFF2E7D32),
        'Notes',
        () {
          HapticFeedback.lightImpact();
          context.go('/home/notes');
        },
      ),
      _GridItem(
        Icons.folder_rounded,
        const Color(0xFFF9A825),
        'Collections',
        () {
          HapticFeedback.lightImpact();
          context.go('/home/collections');
        },
      ),
      _GridItem(
        Icons.shuffle_rounded,
        const Color(0xFF6A1B9A),
        'Random',
        () => _showRandomHadith(context, ref),
      ),
      _GridItem(
        Icons.feedback_rounded,
        const Color(0xFF00838F),
        'Feedback',
        () {
          HapticFeedback.lightImpact();
          _showFeedbackDialog(context);
        },
      ),
      _GridItem(Icons.share_rounded, const Color(0xFF4527A0), 'Share App', () {
        HapticFeedback.lightImpact();
        SharePlus.instance.share(
          ShareParams(
            text:
                'Download Jami at-Tirmidhi Hadith app — Read authentic Hadiths with Urdu, Arabic & English translations:\nhttps://play.google.com/store/apps/details?id=com.jami.at_tirmidhi',
          ),
        );
      }),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 4,
          mainAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        itemCount: menuItems.length,
        itemBuilder: (context, index) {
          final item = menuItems[index];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: item.onTap,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.icon, size: 32, color: item.color),
                  const SizedBox(height: 8),
                  Text(
                    item.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Random Hadith ───
  void _showRandomHadith(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    final repo = ref.read(hadithRepositoryProvider);
    final hadith = await repo.getRandomHadith();
    if (hadith == null || !context.mounted) return;

    final idx = await repo.getHadithIndexWithinChapter(
      hadith.chapterId,
      hadith.hadithNumber,
    );
    if (context.mounted) {
      context.go('/home/chapter/${hadith.chapterId}?startIndex=$idx');
    }
  }

  // ─── Backup Dialog ───
  void _showBackupDialog(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.backup, color: Theme.of(ctx).primaryColor, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Backup & Restore',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.cloud_upload, color: Colors.green.shade600),
              title: const Text('Export Backup'),
              subtitle: const Text('Save bookmarks, notes & collections'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              tileColor: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
              onTap: () async {
                final repo = ref.read(hadithRepositoryProvider);
                final data = await repo.exportUserData();
                if (ctx.mounted) Navigator.pop(ctx);
                final text = jsonEncode(data);
                await Clipboard.setData(ClipboardData(text: text));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Backup copied to clipboard! ✓'),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.cloud_download, color: Colors.blue.shade600),
              title: const Text('Import Backup'),
              subtitle: const Text('Restore from backup data'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              tileColor: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
              onTap: () {
                Navigator.pop(ctx);
                _showImportDialog(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showImportDialog(BuildContext context, WidgetRef ref) {
    final TextEditingController controller = TextEditingController();
    bool isImporting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Import Backup'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Paste your previously copied backup text below to restore your bookmarks, notes, and collections.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Paste backup here...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isImporting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isImporting
                  ? null
                  : () async {
                      final text = controller.text.trim();
                      if (text.isEmpty) return;

                      setState(() => isImporting = true);
                      try {
                        final data = jsonDecode(text) as Map<String, dynamic>;
                        final repo = ref.read(hadithRepositoryProvider);
                        final importedCount = await repo.importUserData(data);

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Successfully restored $importedCount records! ✓',
                              ),
                            ),
                          );
                          // Refresh data after import
                          ref.invalidate(chaptersProvider);
                          ref.invalidate(hadithOfTheDayProvider);
                        }
                      } catch (e) {
                        setState(() => isImporting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Invalid backup data. Import failed: $e',
                              ),
                            ),
                          );
                        }
                      }
                    },
              child: isImporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Restore'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () => context.go('/home/search'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'باب عنوان کے ذریعے تلاش کریں',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey.shade500,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.search,
              color: Theme.of(context).primaryColor.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumeButton(BuildContext context, WidgetRef ref, bool isDark) {
    return Container(
      // Lifted a little above the bottom edge / gesture bar.
      margin: const EdgeInsets.fromLTRB(60, 0, 60, 44),
      child: Material(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(30),
        elevation: 4,
        shadowColor: Theme.of(context).primaryColor.withValues(alpha: 0.3),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () async {
            HapticFeedback.lightImpact();
            final progress = await ref
                .read(hadithRepositoryProvider)
                .getLastReadingProgress();
            if (!context.mounted) return;
            if (progress != null) {
              context.go(
                '/home/chapter/${progress.chapterId}?startIndex=${progress.hadithIndex}',
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Start reading a hadith to enable resume!'),
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Theme.of(context).primaryColor,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.access_time,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Resume Hadith Reading',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Send Feedback',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'We love hearing from you! Share your thoughts, suggestions or report issues.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Write your feedback here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).primaryColor,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Thank you for your feedback! 🙏'),
                ),
              );
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showFindHadithDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    bool isSearching = false;

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> performSearch() async {
              if (controller.text.isEmpty || isSearching) return;
              final number = controller.text.trim();
              if (number.isEmpty) return;

              setState(() => isSearching = true);
              final repo = ref.read(hadithRepositoryProvider);
              final hadith = await repo.getHadithByNumber(number);

              if (hadith == null) {
                setState(() => isSearching = false);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Hadith not found')),
                  );
                }
                return;
              }

              final index = await repo.getHadithIndexWithinChapter(
                hadith.chapterId,
                number,
              );

              if (context.mounted) {
                Navigator.pop(context);
                context.go(
                  '/home/chapter/${hadith.chapterId}?startIndex=$index',
                );
              }
            }

            return AlertDialog(
                  title: const Text(
                    'Find Hadith',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Enter Hadith Number:'),
                      const SizedBox(height: 12),
                      TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'e.g. 4341',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        autofocus: true,
                        onSubmitted: (_) => performSearch(),
                      ),
                      if (isSearching)
                        const Padding(
                          padding: EdgeInsets.only(top: 16.0),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'CANCEL',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    TextButton(
                          onPressed: isSearching ? null : performSearch,
                          child: Text(
                            'FIND',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                  ],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
                );
          },
        );
      },
    );
  }
}

class _ChapterCard extends ConsumerWidget {
  final Chapter chapter;
  final int index;
  final bool isDark;
  final double? progress;

  const _ChapterCard({
    required this.chapter,
    required this.index,
    required this.isDark,
    this.progress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return GestureDetector(
          onTap: () => context.go('/home/chapterList/${chapter.id}'),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Hadith Count
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 4,
                      ),
                      child: Text(
                        '${chapter.hadithCount} احادیث',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey.shade400 : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Title
                    Expanded(
                      child: Text(
                        settings.titleLanguage == 'English'
                            ? chapter.titleEnglish
                            : settings.titleLanguage == 'Arabic'
                            ? chapter.titleArabic
                            : chapter.titleUrdu,
                        textAlign: settings.titleLanguage == 'English'
                            ? TextAlign.left
                            : TextAlign.right,
                        textDirection: settings.titleLanguage == 'English'
                            ? TextDirection.ltr
                            : TextDirection.rtl,
                        style: AppTheme.safeGetFont(
                          settings.titleLanguage == 'English'
                              ? settings.englishFontFamily
                              : settings.titleLanguage == 'Arabic'
                              ? settings.arabicFontFamily
                              : settings.urduFontFamily,
                          fontSize: 18,
                          height: 2.2,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Chapter Number
                    SizedBox(
                      width: 24,
                      child: Text(
                        '${chapter.id}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                // Progress bar
                if (progress != null && progress! > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${(progress! * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress!,
                            minHeight: 4,
                            backgroundColor: isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation(
                              progress! >= 1.0
                                  ? Colors.green
                                  : Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      ),
                      if (progress! >= 1.0) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
  }
}

class _GridItem {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _GridItem(this.icon, this.color, this.label, this.onTap);
}
