import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../data/repositories/hadith_repository.dart';
import '../../domain/models/models.dart';
import '../settings/settings_provider.dart';

final chapterHadithsListProvider = FutureProvider.family<List<Hadith>, int>((
  ref,
  chapterId,
) async {
  final repo = ref.watch(hadithRepositoryProvider);
  return repo.getHadithsByChapter(chapterId, limit: 10000);
});

final singleChapterProvider = FutureProvider.family<Chapter?, int>((
  ref,
  chapterId,
) async {
  final repo = ref.watch(hadithRepositoryProvider);
  return repo.getChapterById(chapterId);
});

class HadithListScreen extends ConsumerWidget {
  final int chapterId;

  const HadithListScreen({super.key, required this.chapterId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hadithsAsync = ref.watch(chapterHadithsListProvider(chapterId));
    final chapterAsync = ref.watch(singleChapterProvider(chapterId));
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: chapterAsync.when(
          data: (chapter) => Text(
            settings.titleLanguage == 'English'
                ? (chapter?.titleEnglish ?? 'Chapter')
                : settings.titleLanguage == 'Arabic'
                ? (chapter?.titleArabic ?? 'باب')
                : (chapter?.titleUrdu ?? 'باب'),
            style: AppTheme.safeGetFont(
              settings.titleLanguage == 'English'
                  ? settings.englishFontFamily
                  : settings.titleLanguage == 'Arabic'
                  ? settings.arabicFontFamily
                  : settings.urduFontFamily,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          loading: () => const Text('Loading...'),
          error: (_, _) => const Text('Error'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/home/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Field
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    onSubmitted: (query) {
                      context.push('/home/search');
                    },
                    decoration: InputDecoration(
                      hintText: 'حدیث نمبر یا عنوان کے ذریعے تلاش کریں',
                      hintStyle: TextStyle(
                        color: isDark
                            ? Colors.grey.shade500
                            : Colors.grey.shade400,
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                Icon(Icons.search, color: Theme.of(context).primaryColor),
              ],
            ),
          ),
          Expanded(
            child: hadithsAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).primaryColor,
                ),
              ),
              error: (e, st) => Center(child: Text('Error: $e')),
              data: (hadiths) {
                if (hadiths.isEmpty) {
                  return Center(
                    child: Text(
                      'عذر خواہ ہیں، کوئی حدیث نہیں ملی',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: hadiths.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                          onTap: () {
                            context.push(
                              '/home/chapter/$chapterId?startIndex=$index',
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 20,
                            ),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.cardDark : Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isDark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              textDirection: TextDirection.rtl,
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 14,
                                  color: Theme.of(context).primaryColor,
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  hadiths[index].hadithNumber,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        settings.titleLanguage == 'English'
                                            ? (chapterAsync
                                                      .value
                                                      ?.titleEnglish ??
                                                  'Hadith')
                                            : settings.titleLanguage == 'Arabic'
                                            ? (chapterAsync
                                                      .value
                                                      ?.titleArabic ??
                                                  'حديث')
                                            : (chapterAsync.value?.titleUrdu ??
                                                  'حدیث'),
                                        textAlign:
                                            settings.titleLanguage == 'English'
                                            ? TextAlign.left
                                            : TextAlign.right,
                                        textDirection:
                                            settings.titleLanguage == 'English'
                                            ? TextDirection.ltr
                                            : TextDirection.rtl,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTheme.safeGetFont(
                                          settings.titleLanguage == 'English'
                                              ? settings.englishFontFamily
                                              : settings.titleLanguage ==
                                                    'Arabic'
                                              ? settings.arabicFontFamily
                                              : settings.urduFontFamily,
                                          color: Theme.of(context).primaryColor,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          height: 2.2,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        hadiths[index].urduText.replaceAll(
                                          '\n',
                                          ' ',
                                        ),
                                        textAlign: TextAlign.right,
                                        textDirection: TextDirection.rtl,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTheme.safeGetFont(
                                          settings.urduFontFamily,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black87,
                                          fontSize: 16,
                                          height: 2.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .animate()
                        .fade(duration: 400.ms)
                        .slideY(
                          begin: 0.1,
                          end: 0,
                          curve: Curves.easeOut,
                          delay: (index * 50).ms,
                        );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
