import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme/app_theme.dart';
import '../../data/repositories/hadith_repository.dart';
import '../../domain/models/models.dart';
import '../settings/settings_provider.dart';
import '../collections/collections_screen.dart';
import '../collections/collection_detail_screen.dart' show collectionHadithsProvider;
import '../bookmarks/bookmarks_screen.dart' show bookmarkedHadithsProvider;
import '../notes/notes_screen.dart' show allNotesWithInfoProvider;
import '../hadith/hadith_list_screen.dart'; // To access singleChapterProvider
import '../home/home_screen.dart' show statsProvider, chapterProgressProvider;
import 'share_image_screen.dart';
import '../../core/services/in_app_review_service.dart';

final hadithsByChapterProvider = FutureProvider.family<List<Hadith>, int>((
  ref,
  chapterId,
) async {
  final repo = ref.watch(hadithRepositoryProvider);
  return repo.getHadithsByChapter(chapterId);
});

final isBookmarkedProvider = FutureProvider.family<bool, int>((
  ref,
  hadithId,
) async {
  final repo = ref.watch(hadithRepositoryProvider);
  return repo.isBookmarked(hadithId);
});

class HadithDetailScreen extends ConsumerStatefulWidget {
  final int chapterId;
  final int startIndex;

  const HadithDetailScreen({
    super.key,
    required this.chapterId,
    this.startIndex = 0,
  });

  @override
  ConsumerState<HadithDetailScreen> createState() => _HadithDetailScreenState();
}

class _HadithDetailScreenState extends ConsumerState<HadithDetailScreen> {
  late int _currentIndex;
  late PageController _pageController;
  // Captured once so progress can still be saved/invalidated after dispose.
  late final ProviderContainer _container;
  int _lastSavedIndex = -1;

  String? _extractNarrator(String englishText) {
    if (englishText.isEmpty) return null;
    final regex = RegExp(r'^Narrated\s+(by\s+)?([^:]+):', caseSensitive: false);
    final match = regex.firstMatch(englishText.trim());
    if (match != null) {
      return match.group(2)?.trim();
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _container = ProviderScope.containerOf(context, listen: false);
    _currentIndex = widget.startIndex;
    _pageController = PageController(initialPage: widget.startIndex);
    _onHadithViewed();
    // Opening a hadith already counts as "last read" (even without swiping).
    WidgetsBinding.instance.addPostFrameCallback((_) => _saveProgress());
    // Prompt review on 2nd detail visit (with 3-day cooldown if dismissed/cancelled)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        InAppReviewService.checkPromptOnHadithDetail();
      }
    });
  }

  void _onHadithViewed() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        InAppReviewService.incrementHadithReadAndCheckPrompt(context);
      }
    });
  }

  @override
  void dispose() {
    _saveProgress(); // covers system back, gestures and any other exit
    _pageController.dispose();
    super.dispose();
  }

  void _saveProgress() {
    if (_lastSavedIndex == _currentIndex) return;
    _lastSavedIndex = _currentIndex;
    final container = _container;
    try {
      final repo = container.read(hadithRepositoryProvider);
      repo.saveReadingProgress(widget.chapterId, _currentIndex).then((_) {
        try {
          container.invalidate(lastProgressProvider);
          container.invalidate(statsProvider);
          container.invalidate(chapterProgressProvider);
        } catch (_) {}
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final hadithsAsync = ref.watch(hadithsByChapterProvider(widget.chapterId));
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Consumer(
          builder: (context, ref, _) {
            final chapterAsync = ref.watch(
              singleChapterProvider(widget.chapterId),
            );
            final settings = ref.watch(settingsProvider);
            return chapterAsync.when(
              data: (chapter) => Text(
                settings.titleLanguage == 'English'
                    ? (chapter?.titleEnglish ?? 'Chapter ${widget.chapterId}')
                    : settings.titleLanguage == 'Arabic'
                    ? (chapter?.titleArabic ?? 'باب ${widget.chapterId}')
                    : (chapter?.titleUrdu ?? 'باب ${widget.chapterId}'),
                style: AppTheme.safeGetFont(
                  settings.titleLanguage == 'English'
                      ? settings.englishFontFamily
                      : settings.titleLanguage == 'Arabic'
                      ? settings.arabicFontFamily
                      : settings.urduFontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              loading: () => const Text('Loading...'),
              error: (_, _) => Text('Chapter ${widget.chapterId}'),
            );
          },
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _saveProgress();
            context.pop();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_fields),
            onPressed: () => _showFontSizeDialog(),
            tooltip: 'Font Size',
          ),
        ],
      ),
      body: hadithsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).primaryColor,
          ),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (hadiths) {
          if (hadiths.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.menu_book,
                    size: 80,
                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hadiths in this chapter yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade500,
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 500.ms),
            );
          }
          if (_currentIndex >= hadiths.length) _currentIndex = 0;
          // FIX: _saveProgress() removed from build() — it was firing on
          // every widget rebuild (theme change, provider updates, etc.)
          // causing excessive DB writes. Now only called from
          // onPageChanged (user swipe) and the back-button handler.
          return _buildHadithView(hadiths, hadiths.length, settings, isDark);
        },
      ),
    );
  }

  Widget _buildHadithView(
    List<Hadith> hadiths,
    int total,
    AppSettings settings,
    bool isDark,
  ) {
    final hadith = hadiths[_currentIndex];
    return Column(
      children: [
        // Navigation Header (Tab style)
        Container(
          color: isDark ? AppTheme.cardDark : Theme.of(context).primaryColor,
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Previous Hadith Tab (Index increased in our array view)
              Expanded(
                child: InkWell(
                  onTap: _currentIndex < total - 1
                      ? () {
                          _pageController.animateToPage(
                            _currentIndex + 1,
                            duration: 400.ms,
                            curve: Curves.easeInOut,
                          );
                        }
                      : null,
                  child: Center(
                    child: Text(
                      _currentIndex < total - 1
                          ? 'حدیث نمبر ${_currentIndex + 2}'
                          : '',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
              // Current Hadith Tab
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.white, width: 3),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'حدیث نمبر ${hadith.hadithNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
              // Next Hadith Tab
              Expanded(
                child: InkWell(
                  onTap: _currentIndex > 0
                      ? () {
                          _pageController.animateToPage(
                            _currentIndex - 1,
                            duration: 400.ms,
                            curve: Curves.easeInOut,
                          );
                        }
                      : null,
                  child: Center(
                    child: Text(
                      _currentIndex > 0 ? 'حدیث نمبر $_currentIndex' : '',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Hadith Content with Swipe (PageView)
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: total,
            reverse: true, // User requested "Slide Right = Forward"
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
              _saveProgress();
              _onHadithViewed();
            },
            itemBuilder: (context, index) {
              final activeHadith = hadiths[index];
              return SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Arabic Card
                    if (settings.showArabic &&
                        activeHadith.arabicText.isNotEmpty)
                      Container(
                            padding: const EdgeInsets.all(20),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.cardDark : Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isDark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'حدیث نمبر : ${activeHadith.hadithNumber}',
                                  textAlign: TextAlign.center,
                                  textDirection: TextDirection.rtl,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                // Removed undefined narratorUrdu
                                const SizedBox(height: 20),
                                Text(
                                  activeHadith.arabicText,
                                  textAlign: TextAlign.right,
                                  textDirection: TextDirection.rtl,
                                  style: AppTheme.safeGetFont(
                                    settings.arabicFontFamily,
                                    color:
                                        AppTheme.getFontColor(
                                          settings.arabicFontColor,
                                          isDark,
                                        ) ??
                                        (isDark
                                            ? Colors.greenAccent
                                            : Theme.of(context).primaryColor),
                                    fontSize: settings.arabicFontSize,
                                    height: 2.2,
                                  ),
                                ),
                              ],
                            ),
                          )
                          .animate()
                          .fadeIn(duration: 300.ms)
                          .scale(
                            begin: const Offset(0.98, 0.98),
                            end: const Offset(1, 1),
                          ),

                    // Urdu & English Translation Card
                    if ((settings.showUrdu &&
                            activeHadith.urduText.isNotEmpty) ||
                        settings.showEnglish)
                      Container(
                        padding: const EdgeInsets.all(20),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.cardDark : Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Chapter Title Header
                            Consumer(
                              builder: (context, ref, child) {
                                final chapterAsync = ref.watch(
                                  singleChapterProvider(activeHadith.chapterId),
                                );
                                return chapterAsync.when(
                                  data: (chapter) => Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            settings.titleLanguage == 'English'
                                            ? MainAxisAlignment.start
                                            : MainAxisAlignment.end,
                                        textDirection:
                                            settings.titleLanguage == 'English'
                                            ? TextDirection.ltr
                                            : TextDirection.rtl,
                                        children: [
                                          Icon(
                                            Icons.circle,
                                            color: Theme.of(
                                              context,
                                            ).primaryColor,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              settings.titleLanguage ==
                                                      'English'
                                                  ? (chapter?.titleEnglish ??
                                                        '')
                                                  : settings.titleLanguage ==
                                                        'Arabic'
                                                  ? (chapter?.titleArabic ?? '')
                                                  : (chapter?.titleUrdu ?? ''),
                                              textAlign:
                                                  settings.titleLanguage ==
                                                      'English'
                                                  ? TextAlign.left
                                                  : TextAlign.right,
                                              textDirection:
                                                  settings.titleLanguage ==
                                                      'English'
                                                  ? TextDirection.ltr
                                                  : TextDirection.rtl,
                                              style: AppTheme.safeGetFont(
                                                settings.titleLanguage ==
                                                        'English'
                                                    ? settings.englishFontFamily
                                                    : settings.titleLanguage ==
                                                          'Arabic'
                                                    ? settings.arabicFontFamily
                                                    : settings.urduFontFamily,
                                                color: isDark
                                                    ? Colors.white70
                                                    : Colors.brown,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                height: 2.0,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      const Divider(height: 1),
                                      const SizedBox(height: 12),
                                      Text(
                                        settings.titleLanguage == 'English'
                                            ? 'Jami at-Tirmidhi Hadith No: ${activeHadith.hadithNumber} Chapter: ${chapter?.titleEnglish ?? ''}'
                                            : settings.titleLanguage == 'Arabic'
                                            ? 'جامع الترمذی حدیث رقم: ${activeHadith.hadithNumber} باب: ${chapter?.titleArabic ?? ''}'
                                            : 'جامع الترمذی حدیث نمبر: ${activeHadith.hadithNumber} فصل: ${chapter?.titleUrdu ?? ''}',
                                        textAlign: TextAlign.center,
                                        textDirection:
                                            settings.titleLanguage == 'English'
                                            ? TextDirection.ltr
                                            : TextDirection.rtl,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          height: 1.6,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.brown,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      const Divider(height: 1),
                                      const SizedBox(height: 16),
                                    ],
                                  ),
                                  loading: () => const SizedBox.shrink(),
                                  error: (_, _) => const SizedBox.shrink(),
                                );
                              },
                            ),

                            // Grade Chip
                            Consumer(
                              builder: (ctx, ref, _) {
                                final gradeSettings = ref.watch(
                                  settingsProvider,
                                );
                                if (activeHadith.grade.isNotEmpty) {
                                  // ── Complete Grade Translation Maps ──
                                  const Map<String, String> gradeToUrdu = {
                                    'Sahih': 'صحیح',
                                    'Sahih Hadith': 'صحیح حدیث',
                                    'Sahih Isnaad': 'صحیح الاسناد',
                                    'Sahih Lighairihi': 'صحیح لغیرہ',
                                    'Sahih Matn': 'صحیح المتن',
                                    'Sahih Muquf': 'صحیح موقوف',
                                    'Sahih Mutawatir': 'صحیح متواتر',
                                    'Sahih - Agreed Upon': 'صحیح - متفق علیہ',
                                    'Hasan': 'حسن',
                                    'Hasan Sahih': 'حسن صحیح',
                                    'Hasan Isnaad': 'حسن الاسناد',
                                    'Hasan Lighairihi': 'حسن لغیرہ',
                                    'Daif': 'ضعیف',
                                    'Sanad Daif': 'ضعیف السند',
                                    'Daif Isnaad': 'ضعیف الاسناد',
                                    'Daif Munkar': 'ضعیف منکر',
                                    'Very Daif': 'انتہائی ضعیف',
                                    'Very Daif Isnaad': 'انتہائی ضعیف الاسناد',
                                    'Munkar': 'منکر',
                                    'Munkar Daif': 'منکر ضعیف',
                                    'Mawdu': 'موضوع',
                                    'Batil': 'باطل',
                                    'Isnaad Malool': 'معلول الاسناد',
                                    'Shadh': 'شاذ',
                                  };
                                  const Map<String, String> gradeToArabic = {
                                    'Sahih': 'صحيح',
                                    'Sahih Hadith': 'صحيح الحديث',
                                    'Sahih Isnaad': 'صحيح الإسناد',
                                    'Sahih Lighairihi': 'صحيح لغيره',
                                    'Sahih Matn': 'صحيح المتن',
                                    'Sahih Muquf': 'صحيح موقوف',
                                    'Sahih Mutawatir': 'صحيح متواتر',
                                    'Sahih - Agreed Upon': 'صحيح - متفق عليه',
                                    'Hasan': 'حسن',
                                    'Hasan Sahih': 'حسن صحيح',
                                    'Hasan Isnaad': 'حسن الإسناد',
                                    'Hasan Lighairihi': 'حسن لغيره',
                                    'Daif': 'ضعيف',
                                    'Sanad Daif': 'سند ضعيف',
                                    'Daif Isnaad': 'ضعيف الإسناد',
                                    'Daif Munkar': 'ضعيف منكر',
                                    'Very Daif': 'ضعيف جداً',
                                    'Very Daif Isnaad': 'ضعيف الإسناد جداً',
                                    'Munkar': 'منكر',
                                    'Munkar Daif': 'منكر ضعيف',
                                    'Mawdu': 'موضوع',
                                    'Batil': 'باطل',
                                    'Isnaad Malool': 'إسناد معلول',
                                    'Shadh': 'شاذ',
                                  };

                                  // ── Color Category ──
                                  final gradeLower = activeHadith.grade
                                      .toLowerCase();
                                  final isSahihGrade =
                                      gradeLower.startsWith('sahih') ||
                                      activeHadith.grade.contains('صحيح') ||
                                      activeHadith.grade.contains('صحیح');
                                  final isHasanGrade =
                                      gradeLower.startsWith('hasan') ||
                                      activeHadith.grade.contains('حسن');
                                  final isBadGrade =
                                      gradeLower.contains('daif') ||
                                      gradeLower.contains('mawdu') ||
                                      gradeLower.contains('batil') ||
                                      gradeLower.contains('munkar') ||
                                      gradeLower.contains('shadh') ||
                                      gradeLower.contains('malool') ||
                                      activeHadith.grade.contains('ضعيف') ||
                                      activeHadith.grade.contains('ضعیف') ||
                                      activeHadith.grade.contains('موضوع') ||
                                      activeHadith.grade.contains('باطل');

                                  final Color gradeColor = isSahihGrade
                                      ? Colors.green.shade600
                                      : isHasanGrade
                                      ? Colors.teal.shade600
                                      : isBadGrade
                                      ? Colors.red.shade600
                                      : Colors.grey.shade600;

                                  final IconData gradeIcon =
                                      isSahihGrade || isHasanGrade
                                      ? Icons.check_circle_outline
                                      : isBadGrade
                                      ? Icons.error_outline
                                      : Icons.info_outline;

                                  // ── Translated Label ──
                                  String translatedGrade;
                                  String gradeLabel;
                                  if (gradeSettings.titleLanguage == 'Urdu') {
                                    translatedGrade =
                                        gradeToUrdu[activeHadith.grade] ??
                                        activeHadith.grade;
                                    gradeLabel = 'درجہ: $translatedGrade';
                                  } else if (gradeSettings.titleLanguage ==
                                      'Arabic') {
                                    translatedGrade =
                                        gradeToArabic[activeHadith.grade] ??
                                        activeHadith.grade;
                                    gradeLabel = 'الدرجة: $translatedGrade';
                                  } else {
                                    gradeLabel = 'Grade: ${activeHadith.grade}';
                                  }

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: gradeColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: gradeColor.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      textDirection:
                                          gradeSettings.titleLanguage ==
                                              'English'
                                          ? TextDirection.ltr
                                          : TextDirection.rtl,
                                      children: [
                                        Icon(
                                          gradeIcon,
                                          size: 18,
                                          color: gradeColor,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          gradeLabel,
                                          textDirection:
                                              gradeSettings.titleLanguage ==
                                                  'English'
                                              ? TextDirection.ltr
                                              : TextDirection.rtl,
                                          style: TextStyle(
                                            color: gradeColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),

                            // Narrator Chip
                            Builder(
                              builder: (ctx) {
                                final narrator = _extractNarrator(
                                  activeHadith.englishText,
                                );
                                if (narrator != null) {
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 24),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).primaryColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Theme.of(
                                          context,
                                        ).primaryColor.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.person,
                                          size: 18,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Narrator: $narrator',
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).primaryColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),

                            // Urdu Text
                            if (settings.showUrdu &&
                                activeHadith.urduText.isNotEmpty) ...[
                              Text(
                                activeHadith.urduText,
                                textAlign: _getAlignment(
                                  settings.urduAlignment,
                                ),
                                textDirection: TextDirection.rtl,
                                style: AppTheme.safeGetFont(
                                  settings.urduFontFamily,
                                  fontSize: settings.urduFontSize,
                                  height: 2.4,
                                  color: AppTheme.getFontColor(
                                    settings.urduFontColor,
                                    isDark,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),
                            ],

                            // English Text
                            if (settings.showEnglish) ...[
                              const Divider(height: 1),
                              const SizedBox(height: 12),
                              Text(
                                activeHadith.englishText,
                                textAlign: TextAlign.left,
                                textDirection: TextDirection.ltr,
                                style: AppTheme.safeGetFont(
                                  settings.englishFontFamily,
                                  fontSize: settings.englishFontSize,
                                  height: 1.6,
                                  color:
                                      AppTheme.getFontColor(
                                        settings.englishFontColor,
                                        isDark,
                                      ) ??
                                      (isDark
                                          ? Colors.white70
                                          : Colors.brown.shade700),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        // Bottom Action Bar
        _buildActionBar(hadith, isDark),
      ],
    );
  }

  Widget _buildActionBar(Hadith hadith, bool isDark) {
    // FIX: Add bottom safe-area padding so the system navigation bar
    // (3-button nav or gesture bar on edge-to-edge devices) does not
    // overlap/cover these action buttons (bookmark, copy, share, note, collect).
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.only(left: 4, right: 4, top: 6, bottom: 6 + bottomInset),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Bookmark
          Consumer(
            builder: (context, ref, _) {
              final isBookmarked = ref.watch(isBookmarkedProvider(hadith.id));
              return _actionButton(
                isBookmarked.when(
                  data: (v) => v ? Icons.bookmark : Icons.bookmark_outline,
                  loading: () => Icons.bookmark_outline,
                  error: (_, st) => Icons.bookmark_outline,
                ),
                'Bookmark',
                () async {
                  HapticFeedback.mediumImpact();
                  final repo = ref.read(hadithRepositoryProvider);
                  final wasBookmarked = await repo.isBookmarked(hadith.id);
                  await repo.toggleBookmark(hadith.id);
                  ref.invalidate(isBookmarkedProvider(hadith.id));
                  ref.invalidate(statsProvider);
                  ref.invalidate(bookmarkedHadithsProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          !wasBookmarked
                              ? 'Bookmarked ✓'
                              : 'Removed from bookmarks',
                        ),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  }
                },
              );
            },
          ),
          // Copy
          _actionButton(Icons.copy_rounded, 'Copy', () {
            HapticFeedback.lightImpact();
            _showCopyOptions(hadith);
          }),
          // Share
          _actionButton(Icons.share, 'Share', () {
            HapticFeedback.selectionClick();
            _showShareOptions(hadith);
          }),
          // Add Note
          _actionButton(Icons.note_add_outlined, 'Note', () {
            HapticFeedback.lightImpact();
            _showAddNoteDialog(hadith);
          }),
          // Add to Collection
          _actionButton(Icons.playlist_add, 'Collect', () {
            HapticFeedback.lightImpact();
            _showAddToCollectionDialog(hadith);
          }),
        ],
      ),
    );
  }

  void _showCopyOptions(Hadith hadith) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.copy_rounded, color: Theme.of(ctx).primaryColor),
                  const SizedBox(width: 10),
                  const Text(
                    'Copy Hadith Text',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _copyTile(
                ctx,
                isDark,
                'عربی (Arabic)',
                hadith.arabicText,
                Icons.language,
              ),
              _copyTile(
                ctx,
                isDark,
                'اردو (Urdu)',
                hadith.urduText,
                Icons.translate,
              ),
              _copyTile(ctx, isDark, 'English', hadith.englishText, Icons.abc),
              const Divider(),
              _copyTile(
                ctx,
                isDark,
                'Copy All',
                '${hadith.arabicText}\n\n${hadith.urduText}\n\n${hadith.englishText}\n\n— Jami at-Tirmidhi, Hadith #${hadith.hadithNumber}',
                Icons.select_all,
              ),
            ],
          ),
        );
      },
    );
  }

  void _showShareOptions(Hadith hadith) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.share, color: Theme.of(ctx).primaryColor),
                  const SizedBox(width: 10),
                  const Text(
                    'Share Hadith',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(
                  Icons.text_snippet,
                  color: Theme.of(ctx).primaryColor,
                ),
                title: const Text('Share as Text'),
                onTap: () {
                  Navigator.pop(ctx);
                  final text =
                      '${hadith.arabicText}\n\n${hadith.urduText}\n\n${hadith.englishText}\n\n— Jami at-Tirmidhi, Hadith #${hadith.hadithNumber}';
                  SharePlus.instance.share(ShareParams(text: text));
                },
              ),
              ListTile(
                leading: Icon(Icons.image, color: Theme.of(ctx).primaryColor),
                title: const Text('Share as Image'),
                onTap: () {
                  Navigator.pop(ctx);
                  // Determine chapter title async or just pass null to preview
                  final chapterTitleAsync = ref.watch(
                    singleChapterProvider(hadith.chapterId),
                  );
                  final settings = ref.read(settingsProvider);
                  final titleUrl = settings.titleLanguage == 'English'
                      ? chapterTitleAsync.value?.titleEnglish
                      : settings.titleLanguage == 'Arabic'
                      ? chapterTitleAsync.value?.titleArabic
                      : chapterTitleAsync.value?.titleUrdu;

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ShareImageScreen(
                        hadith: hadith,
                        chapterTitle: titleUrl,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _copyTile(
    BuildContext ctx,
    bool isDark,
    String label,
    String text,
    IconData icon,
  ) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(ctx).primaryColor, size: 22),
      title: Text(label, style: const TextStyle(fontSize: 15)),
      trailing: Icon(
        Icons.content_copy,
        size: 18,
        color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onTap: () {
        HapticFeedback.lightImpact();
        Clipboard.setData(ClipboardData(text: text));
        Navigator.pop(ctx);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label copied ✓'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Theme.of(context).primaryColor, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddNoteDialog(Hadith hadith) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Add Note — Hadith #${hadith.id}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Write your note here...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).primaryColor,
                width: 2,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final repo = ref.read(hadithRepositoryProvider);
                await repo.addNote(hadith.id, controller.text);
                ref.invalidate(statsProvider);
                ref.invalidate(allNotesWithInfoProvider);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Note saved! 📝')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddToCollectionDialog(Hadith hadith) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final collectionsAsync = ref.watch(collectionsProvider);

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add to Collection',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 16),
                collectionsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error: $e'),
                  data: (collections) {
                    if (collections.isEmpty) {
                      return const Text(
                        'No collections yet. Create one from the Collections screen.',
                      );
                    }
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: collections
                          .map(
                            (c) => ListTile(
                              leading: Icon(
                                Icons.folder,
                                color: Theme.of(context).primaryColor,
                              ),
                              title: Text(
                                c.name,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : AppTheme.textDark,
                                ),
                              ),
                              onTap: () async {
                                final repo = ref.read(hadithRepositoryProvider);
                                await repo.addHadithToCollection(
                                  c.id,
                                  hadith.id,
                                );
                                ref.invalidate(collectionHadithsProvider(c.id));
                                ref.invalidate(collectionsProvider);
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Added to "${c.name}" ✓'),
                                    ),
                                  );
                                }
                              },
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showFontSizeDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final settings = ref.watch(settingsProvider);
            final notifier = ref.read(settingsProvider.notifier);

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Font Size',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  _fontSlider(
                    'Arabic',
                    settings.arabicFontSize,
                    16,
                    40,
                    (v) => notifier.updateFontSize('Arabic', v),
                  ),
                  _fontSlider(
                    'Urdu',
                    settings.urduFontSize,
                    14,
                    36,
                    (v) => notifier.updateFontSize('Urdu', v),
                  ),
                  _fontSlider(
                    'English',
                    settings.englishFontSize,
                    12,
                    32,
                    (v) => notifier.updateFontSize('English', v),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _fontSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
        SizedBox(
          width: 40,
          child: Text('${value.toInt()}', textAlign: TextAlign.center),
        ),
      ],
    );
  }

  TextAlign _getAlignment(String alignment) {
    switch (alignment) {
      case 'Right':
        return TextAlign.right;
      case 'Center':
        return TextAlign.center;
      case 'Left':
        return TextAlign.left;
      default:
        return TextAlign.right;
    }
  }
}
