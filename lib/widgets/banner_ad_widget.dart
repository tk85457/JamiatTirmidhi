import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../core/ads/ad_free_service.dart';
import '../core/ads/ad_service.dart';

/// Production-ready banner ad widget.
///
/// Features:
/// - Completely OFF (no request, no view, no timers) while the user has the
///   24-hour "ad-free" reward active; resumes automatically when it expires.
/// - Adaptive banner size (better CPM than fixed 320×50)
/// - Smart retry on no-fill: 5 s → 10 s → 20 s → 30 s (capped)
/// - Zero UI impact when no ad — returns SizedBox.shrink()
/// - Properly disposes ad on widget removal (low memory)
/// - Pauses retry when app is backgrounded
/// - Safe against mount/unmount races
class BannerAdWidget extends StatefulWidget {
  /// Override the ad unit ID (leave null to use AdService default).
  final String? adUnitId;

  const BannerAdWidget({super.key, this.adUnitId});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget>
    with WidgetsBindingObserver {
  static const List<int> _retryDelaysSeconds = [5, 10, 20, 30];

  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _isLoadingAd = false;
  Timer? _retryTimer;
  int _retryAttempt = 0;

  // Cached adaptive size — resolved once per widget instance.
  AdSize? _resolvedSize;

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AdService.canRequestAdsNotifier.addListener(_onConsentChanged);
    AdFreeService.adFreeNotifier.addListener(_onAdFreeChanged);
    _checkConsentAndLoad();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Pause retries while app is in background — saves battery / network.
      _retryTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      // The 24 h window may have expired while the app was in background.
      AdFreeService.refresh();
      if (AdFreeService.isAdFree) return;

      // Resume: request a fresh ad if none is showing.
      if (!_isAdLoaded || _bannerAd == null) {
        _retryAttempt = 0;
        _loadAd();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    AdService.canRequestAdsNotifier.removeListener(_onConsentChanged);
    AdFreeService.adFreeNotifier.removeListener(_onAdFreeChanged);
    _bannerAd?.dispose();
    _bannerAd = null;
    super.dispose();
  }

  // ─── Ad-free reward ───────────────────────────────────────────────────────

  /// Fires when the 24 h "banner ads off" window starts or ends.
  void _onAdFreeChanged() {
    if (!mounted) return;

    if (AdFreeService.adFreeNotifier.value) {
      // Reward granted: stop everything and free the ad's memory.
      _retryTimer?.cancel();
      _retryTimer = null;
      _retryAttempt = 0;
      final old = _bannerAd;
      setState(() {
        _bannerAd = null;
        _isAdLoaded = false;
      });
      old?.dispose();
    } else {
      // Window expired: banner ads come back and requests start again.
      _retryAttempt = 0;
      if (_bannerAd == null && !_isAdLoaded && !_isLoadingAd) {
        _loadAd();
      }
    }
  }

  // ─── Consent & Load ───────────────────────────────────────────────────────

  /// Fires when AdService consent state changes (e.g. UMP form completed).
  void _onConsentChanged() {
    if (!mounted) return;
    if (_bannerAd == null && !_isAdLoaded && !_isLoadingAd) {
      _loadAd();
    }
  }

  /// Entry point called from initState — waits for consent then loads.
  Future<void> _checkConsentAndLoad() async {
    if (!AdService.isSupported) return;
    if (!AdService.isConsentGathered) {
      await AdService.waitForConsent();
      if (!mounted) return;
    }
    _loadAd();
  }

  /// Logical width of the screen, without needing a BuildContext
  /// (safe to call from initState).
  int _screenWidthDp() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return 360;
    final view = views.first;
    final dpr = view.devicePixelRatio <= 0 ? 1.0 : view.devicePixelRatio;
    return (view.physicalSize.width / dpr).truncate();
  }

  /// Resolves adaptive banner size once, then creates and loads the BannerAd.
  Future<void> _loadAd() async {
    if (!AdService.isSupported || _isLoadingAd) return;
    if (AdFreeService.isAdFree) return; // user chose 24 h without banners
    _isLoadingAd = true;
    _retryTimer?.cancel();

    // Resolve adaptive size once per widget instance (cached).
    if (_resolvedSize == null) {
      AdSize? adaptive;
      try {
        adaptive =
            await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
              _screenWidthDp(),
            );
      } catch (e) {
        debugPrint('Adaptive banner size failed: $e');
      }
      // Fallback to standard banner if platform call fails.
      _resolvedSize = adaptive ?? AdSize.banner;
    }

    if (!mounted || AdFreeService.isAdFree) {
      _isLoadingAd = false;
      return;
    }

    // Network check: agar internet band ho toh bekaar me request na bheje
    try {
      final lookup = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 3));
      if (lookup.isEmpty || lookup[0].rawAddress.isEmpty) {
        _isLoadingAd = false;
        _scheduleRetry();
        return;
      }
    } catch (_) {
      _isLoadingAd = false;
      _scheduleRetry();
      return;
    }

    if (!mounted || AdFreeService.isAdFree) {
      _isLoadingAd = false;
      return;
    }

    final unitId = widget.adUnitId ?? AdService.bannerAdUnitId;
    final size = _resolvedSize ?? AdSize.banner;

    BannerAd(
      adUnitId: unitId,
      request: const AdRequest(),
      size: size,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          // Unmounted, or the user earned the 24 h reward while this request
          // was in flight -> throw the ad away immediately.
          if (!mounted || AdFreeService.isAdFree) {
            _isLoadingAd = false;
            ad.dispose();
            return;
          }
          final old = _bannerAd;
          setState(() {
            _bannerAd = ad as BannerAd;
            _isAdLoaded = true;
            _isLoadingAd = false;
          });
          old?.dispose();

          // Rule: Jab ad fill ho jaye, toh saara retry completely BAND!
          _retryAttempt = 0;
          _retryTimer?.cancel();
          _retryTimer = null;
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('BannerAd ($unitId) failed [${err.code}]: ${err.message}');
          ad.dispose();
          if (!mounted) return;
          _isLoadingAd = false;

          // Agar pehle se koi ad visible hai, usse rehne dein
          if (_bannerAd != null && _isAdLoaded) return;

          setState(() {
            _isAdLoaded = false;
            _bannerAd = null;
          });

          // Ad na dikhe ya no-fill ho, toh thodi der baad retry kare
          _scheduleRetry();
        },
      ),
    ).load();
  }

  /// Retry only while NO ad is loaded. Delay grows 5 → 10 → 20 → 30 s (capped)
  /// so a persistent no-fill never hammers the network / battery.
  void _scheduleRetry() {
    _retryTimer?.cancel();
    if (_isAdLoaded && _bannerAd != null) return;
    if (AdFreeService.isAdFree) return;

    final index = _retryAttempt < _retryDelaysSeconds.length
        ? _retryAttempt
        : _retryDelaysSeconds.length - 1;
    final delay = Duration(seconds: _retryDelaysSeconds[index]);
    _retryAttempt++;

    debugPrint(
      'BannerAd retry #$_retryAttempt scheduled in ${delay.inSeconds}s...',
    );
    _retryTimer = Timer(delay, () {
      if (mounted && !_isAdLoaded && !AdFreeService.isAdFree) {
        _loadAd();
      }
    });
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Return zero-size widget while loading, when no fill, or while the
    // user's 24 h ad-free window is active — UI layout stays unchanged.
    if (!AdService.isSupported ||
        !_isAdLoaded ||
        _bannerAd == null ||
        AdFreeService.isAdFree) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      top: false,
      child: SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(key: ValueKey(_bannerAd.hashCode), ad: _bannerAd!),
      ),
    );
  }
}
