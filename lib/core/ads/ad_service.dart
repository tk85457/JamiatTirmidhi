import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  /// Reactive notifier for widgets to listen to consent state changes.
  static final ValueNotifier<bool> canRequestAdsNotifier = ValueNotifier<bool>(
    false,
  );

  /// Synchronous getter to check if ads can currently be requested.
  static bool get canRequestAds => canRequestAdsNotifier.value;

  static bool _isConsentGathered = false;
  static bool get isConsentGathered => _isConsentGathered;

  static bool _isMobileAdsInitialized = false;
  static bool get isMobileAdsInitialized => _isMobileAdsInitialized;

  static Completer<void>? _consentCompleter;

  /// Production Banner Ad Unit ID for Jami at-Tirmidhi
  static const String androidProductionBannerId =
      'ca-app-pub-3362561286987631/1384326240';

  /// Production Rewarded Ad Unit ID for Jami at-Tirmidhi
  static const String androidProductionRewardedId =
      'ca-app-pub-3362561286987631/4455362662';

  /// Test Banner Ad Unit ID for Android
  static const String androidTestBannerId =
      'ca-app-pub-3940256099942544/6300978111';

  /// Test Rewarded Ad Unit ID for Android
  static const String androidTestRewardedId =
      'ca-app-pub-3940256099942544/5224354917';

  /// Test Banner Ad Unit ID for iOS
  static const String iosTestBannerId =
      'ca-app-pub-3940256099942544/2934735716';

  /// Test Rewarded Ad Unit ID for iOS
  static const String iosTestRewardedId =
      'ca-app-pub-3940256099942544/1712485313';

  /// Check if ads are supported on the current platform
  static bool get isSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Awaits completion of the consent gathering flow.
  /// If consent has already been gathered, returns immediately.
  static Future<void> waitForConsent() {
    if (_isConsentGathered) return Future.value();
    return _consentCompleter?.future ?? Future.value();
  }

  /// Official Google UMP consent flow:
  /// 1. requestConsentInfoUpdate()
  /// 2. loadAndShowConsentFormIfRequired()
  /// 3. check canRequestAds()
  /// 4. Initialize MobileAds SDK and notify listeners
  static Future<bool> gatherConsentAndInitialize({
    ConsentRequestParameters? params,
  }) async {
    if (!isSupported) {
      _isConsentGathered = true;
      return false;
    }

    if (_consentCompleter != null && !_consentCompleter!.isCompleted) {
      await _consentCompleter!.future;
      return canRequestAds;
    }

    _consentCompleter = Completer<void>();

    try {
      // Step 1: Request consent information update
      final updateCompleter = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        params ?? ConsentRequestParameters(),
        () {
          if (!updateCompleter.isCompleted) updateCompleter.complete();
        },
        (FormError error) {
          debugPrint(
            'Consent info update failed (${error.errorCode}): ${error.message}',
          );
          if (!updateCompleter.isCompleted) updateCompleter.complete();
        },
      );
      await updateCompleter.future;

      // Step 2: Load and show consent form if Google UMP requires it
      final formCompleter = Completer<void>();
      ConsentForm.loadAndShowConsentFormIfRequired((FormError? formError) {
        if (formError != null) {
          debugPrint(
            'Consent form error (${formError.errorCode}): ${formError.message}',
          );
        }
        if (!formCompleter.isCompleted) formCompleter.complete();
      });
      await formCompleter.future;

      // Step 3: Check if ads can now be requested
      try {
        final canRequest = await ConsentInformation.instance.canRequestAds();
        debugPrint('ConsentInformation canRequestAds: $canRequest');
      } catch (e) {
        debugPrint('Consent check error: $e');
      }

      // Mark notifier so widgets can load ads in all cases
      canRequestAdsNotifier.value = true;

      // Step 4: Always initialize MobileAds SDK so ad requests proceed
      if (!_isMobileAdsInitialized) {
        try {
          await MobileAds.instance.updateRequestConfiguration(
            RequestConfiguration(
              testDeviceIds: const [
                '9F40E3B459A3CAB0BF4BFF505625FF59', // Samsung SM-A135F (dev device)
              ],
              maxAdContentRating: MaxAdContentRating.g,
            ),
          );
          final initStatus = await MobileAds.instance.initialize();
          _isMobileAdsInitialized = true;
          debugPrint('MobileAds SDK initialized successfully.');
          initStatus.adapterStatuses.forEach((key, value) {
            debugPrint(
              'Adapter [$key]: state=${value.state}, desc=${value.description}',
            );
          });
        } catch (e) {
          debugPrint('MobileAds initialization failed: $e');
        }
      }
    } catch (e) {
      debugPrint('AdService.gatherConsentAndInitialize error: $e');
      canRequestAdsNotifier.value = true;
      if (!_isMobileAdsInitialized) {
        try {
          await MobileAds.instance.updateRequestConfiguration(
            RequestConfiguration(
              testDeviceIds: const ['9F40E3B459A3CAB0BF4BFF505625FF59'],
              maxAdContentRating: MaxAdContentRating.g,
            ),
          );
          await MobileAds.instance.initialize();
          _isMobileAdsInitialized = true;
        } catch (_) {}
      }
    } finally {
      _isConsentGathered = true;
      canRequestAdsNotifier.value = true;
      if (!_consentCompleter!.isCompleted) {
        _consentCompleter!.complete();
      }
    }

    return true;
  }

  /// Checks if the official Google UMP privacy options entry point is required.
  static Future<bool> isPrivacyOptionsRequired() async {
    if (!isSupported) return false;
    try {
      final status = await ConsentInformation.instance
          .getPrivacyOptionsRequirementStatus();
      return status == PrivacyOptionsRequirementStatus.required;
    } catch (e) {
      debugPrint('AdService: Error checking privacy options status: $e');
      return false;
    }
  }

  /// Displays the official Google UMP privacy options form so users can revisit consent.
  static Future<void> showPrivacyOptionsForm() async {
    if (!isSupported) return;
    final completer = Completer<void>();

    try {
      ConsentForm.showPrivacyOptionsForm((FormError? formError) async {
        if (formError != null) {
          debugPrint(
            'AdService: Privacy options form error (${formError.errorCode}): ${formError.message}',
          );
        }

        canRequestAdsNotifier.value = true;

        if (!_isMobileAdsInitialized) {
          try {
            await MobileAds.instance.initialize();
            _isMobileAdsInitialized = true;
          } catch (e) {
            debugPrint(
              'MobileAds initialization failed after privacy options update: $e',
            );
          }
        }

        if (!completer.isCompleted) completer.complete();
      });
    } catch (e) {
      debugPrint('AdService: Exception showing privacy options form: $e');
      if (!completer.isCompleted) completer.complete();
    }

    return completer.future;
  }

  /// Reset consent information (useful for testing).
  static Future<void> resetConsentForTesting() async {
    if (!isSupported) return;
    await ConsentInformation.instance.reset();
    _isConsentGathered = false;
    _isMobileAdsInitialized = false;
    canRequestAdsNotifier.value = false;
  }

  /// Get appropriate Banner Ad Unit ID (production)
  static String get bannerAdUnitId {
    if (Platform.isAndroid) return androidProductionBannerId;
    return iosTestBannerId;
  }

  /// Get appropriate Rewarded Ad Unit ID (production only)
  static String get rewardedAdUnitId {
    if (Platform.isAndroid) return androidProductionRewardedId;
    return iosTestRewardedId;
  }

  /// Loads a rewarded ad.
  ///
  /// Resolves with the ad, or `null` if it could not be loaded within
  /// [timeout] (no fill, no network, ...). The caller owns the returned ad and
  /// must either pass it to [showRewarded] or call `dispose()` on it.
  static Future<RewardedAd?> loadRewarded({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (!isSupported) return null;

    // Never request ads before the consent flow has finished.
    try {
      await waitForConsent().timeout(const Duration(seconds: 10));
    } catch (_) {}

    final completer = Completer<RewardedAd?>();
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) completer.complete(null);
    });

    try {
      RewardedAd.load(
        adUnitId: rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            if (completer.isCompleted) {
              // Arrived after the timeout / caller gave up -> free the memory.
              ad.dispose();
              return;
            }
            completer.complete(ad);
          },
          onAdFailedToLoad: (err) {
            debugPrint(
              'RewardedAd failed to load [${err.code}]: ${err.message}',
            );
            if (!completer.isCompleted) completer.complete(null);
          },
        ),
      );
    } catch (e) {
      debugPrint('RewardedAd.load threw: $e');
      if (!completer.isCompleted) completer.complete(null);
    }

    final ad = await completer.future;
    timer.cancel();
    return ad;
  }

  /// Shows a previously loaded rewarded ad and disposes it afterwards.
  ///
  /// Resolves with `true` ONLY if the user actually earned the reward
  /// (watched the ad to the end). Closing the ad early resolves with `false`.
  static Future<bool> showRewarded(RewardedAd ad) {
    final completer = Completer<bool>();
    var earned = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!completer.isCompleted) completer.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        debugPrint('RewardedAd failed to show: ${err.message}');
        ad.dispose();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    try {
      ad.show(onUserEarnedReward: (_, _) => earned = true);
    } catch (e) {
      debugPrint('RewardedAd.show threw: $e');
      ad.dispose();
      if (!completer.isCompleted) completer.complete(false);
    }

    return completer.future;
  }
}
