// Integration notes:
// 1. Android: add INTERNET + ACCESS_NETWORK_STATE permissions and set the
//    `com.google.android.gms.ads.APPLICATION_ID` meta-data as in AndroidManifest.
// 2. iOS: update Info.plist with GADApplicationIdentifier, SKAdNetwork IDs, and
//    privacy text placeholders for review (see Apple + AdMob docs). iOS unit IDs
//    below are placeholders—swap with production values before release.
// 3. Call `await MobileAds.instance.initialize()` then `await Ads.instance.initialize()`
//    inside `main()` before `runApp`.
// 4. Wrap the root/root-like screen with `ExitAdGuard(child: HomePage())`.
// 5. Render banners via `Ads.instance.banner()` (e.g. Scaffold.bottomNavigationBar).
// Follow AdMob policies: show exit interstitials only on natural exit points and
// honor user intent even if the ad fails to load.
import 'dart:async';
import 'dart:io';


import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdIds {
  const AdIds._();

  static String get banner => _select(
    android: 'ca-app-pub-2762057624399418/9061591661',
    ios: 'ca-app-pub-xxxxxxxxxxxxxxxx/BBBBBBBBBB',
    testAndroid: 'ca-app-pub-3940256099942544/6300978111',
    testIos: 'ca-app-pub-3940256099942544/2934735716',
  );

  static String get interstitial => _select(
    android: 'ca-app-pub-2762057624399418/4888636262',
    ios: 'ca-app-pub-xxxxxxxxxxxxxxxx/IIIIIIIIII',
    testAndroid: 'ca-app-pub-3940256099942544/1033173712',
    testIos: 'ca-app-pub-3940256099942544/4411468910',
  );

  static String _select({
    required String android,
    required String ios,
    required String testAndroid,
    required String testIos,
  }) {
    if (kDebugMode) {
      return _platformPick(testAndroid, testIos);
    }
    return _platformPick(android, ios);
  }

  static String _platformPick(String android, String ios) {
    if (kIsWeb) {
      throw UnsupportedError('AdMob only supports Android/iOS');
    }
    if (Platform.isAndroid) return android;
    if (Platform.isIOS) return ios;
    throw UnsupportedError('Unsupported platform for AdMob');
  }
}

class Ads {
  Ads._();

  static final Ads instance = Ads._();

  static bool debug = false;

  static const Duration _interstitialCooldown = Duration(seconds: 45);
  static const int _maxDailyInterstitials = 3;
  static const _prefsDayKey = 'ads_interstitial_day';
  static const _prefsCountKey = 'ads_interstitial_count';
  static const int _maxLoadAttempts = 3;

  final ConsentInformation _consentInfo = ConsentInformation.instance;

  SharedPreferences? _prefs;
  InterstitialAd? _interstitialAd;
  Timer? _retryTimer;
  DateTime? _lastInterstitialShownAt;
  int _loadAttempts = 0;
  int _shownToday = 0;
  String _currentDayKey = '';
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _log('Initializing ads service…');
    _prefs ??= await SharedPreferences.getInstance();
    _rollDailyCounter();
    await _initConsentFlow();
    await _requestInterstitial(force: true);
    _initialized = true;
  }

  Future<void> _initConsentFlow() async {
    try {
      final params = ConsentRequestParameters(
        consentDebugSettings: ConsentDebugSettings(
          debugGeography: DebugGeography.debugGeographyDisabled,
          testIdentifiers: const [],
        ),
      );
      await _requestConsentInfoUpdate(params);
      final isAvailable = await _consentInfo.isConsentFormAvailable();
      if (isAvailable) {
        await _loadAndShowConsentForm();
      }
    } catch (e, st) {
      _log('Consent flow failed: $e\n$st');
    }
  }

  Future<void> _requestConsentInfoUpdate(ConsentRequestParameters params) {
    final completer = Completer<void>();
    _consentInfo.requestConsentInfoUpdate(
      params,
      () {
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      (error) {
        if (!completer.isCompleted) {
          completer.completeError(error, StackTrace.current);
        }
      },
    );
    return completer.future;
  }

  Future<void> _loadAndShowConsentForm() async {
    final completer = Completer<void>();
    ConsentForm.loadConsentForm(
      (form) {
        _consentInfo
            .getConsentStatus()
            .then((status) {
              if (status == ConsentStatus.required) {
                form.show((error) {
                  if (error != null) {
                    _log('Consent form dismissed with error: $error');
                  }
                  if (!completer.isCompleted) {
                    completer.complete();
                  }
                });
              } else {
                if (!completer.isCompleted) {
                  completer.complete();
                }
              }
            })
            .catchError((error, stack) {
              _log('Consent status fetch error: $error');
              if (!completer.isCompleted) {
                completer.completeError(error, stack);
              }
            });
      },
      (error) {
        _log('Consent form error: $error');
        if (!completer.isCompleted) {
          completer.completeError(error, StackTrace.current);
        }
      },
    );

    try {
      await completer.future;
    } catch (e) {
      _log('Consent form completion issue: $e');
    }
  }

  Future<void> loadInterstitial() => _requestInterstitial(force: true);

  Future<void> _requestInterstitial({bool force = false}) async {
    if (!force && _interstitialAd != null) {
      _log('Interstitial already loaded');
      return;
    }
    final canRequestAds = await _consentInfo.canRequestAds();
    if (!canRequestAds) {
      _log('Consent not granted yet; skipping interstitial load.');
      return;
    }
    if (_loadAttempts >= _maxLoadAttempts) {
      if (force) {
        _loadAttempts = 0;
      } else {
        _log('Max interstitial load attempts reached.');
        return;
      }
    }
    _loadAttempts += 1;
    _retryTimer?.cancel();
    _log('Loading interstitial attempt $_loadAttempts…');
    final completer = Completer<void>();

    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _log('Interstitial loaded.');
          _interstitialAd?.dispose();
          _interstitialAd = ad;
          _loadAttempts = 0;
          _attachInterstitialCallbacks(ad);
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onAdFailedToLoad: (error) {
          _log('Interstitial failed to load: $error');
          _interstitialAd?.dispose();
          _interstitialAd = null;
          if (!completer.isCompleted) {
            completer.completeError(error, StackTrace.current);
          }
          _scheduleRetry();
        },
      ),
    );

    try {
      await completer.future;
    } catch (_) {
      // Already logged above.
    }
  }

  void _attachInterstitialCallbacks(InterstitialAd ad) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) => _log('Interstitial showed.'),
      onAdFailedToShowFullScreenContent: (ad, error) {
        _log('Interstitial failed to show: $error');
        ad.dispose();
        _interstitialAd = null;
        _scheduleRetry(immediate: true);
      },
      onAdDismissedFullScreenContent: (ad) {
        _log('Interstitial dismissed.');
        ad.dispose();
        _interstitialAd = null;
        _scheduleRetry(immediate: true);
      },
      onAdImpression: (ad) => _log('Interstitial impression logged.'),
    );
  }

  void _scheduleRetry({bool immediate = false}) {
    if (_loadAttempts >= _maxLoadAttempts) return;
    _retryTimer?.cancel();
    final attempt = _loadAttempts;
    final delay = immediate ? Duration.zero : _retryDelayForAttempt(attempt);
    _retryTimer = Timer(delay, () {
      _log('Retrying interstitial load after $delay…');
      _requestInterstitial(force: true);
    });
  }

  Duration _retryDelayForAttempt(int attempt) {
    const delays = [
      Duration(seconds: 3),
      Duration(seconds: 10),
      Duration(seconds: 20),
    ];
    final index = (attempt - 1).clamp(0, delays.length - 1);
    return delays[index];
  }

  Future<bool> showExitInterstitial() async {
    _rollDailyCounter();
    final canRequestAds = await _consentInfo.canRequestAds();
    if (!canRequestAds) {
      _log('Cannot show interstitial: consent unavailable.');
      return false;
    }
    if (!_isCooldownSatisfied) {
      _log('Skipping interstitial: cooldown active.');
      return false;
    }
    if (_shownToday >= _maxDailyInterstitials) {
      _log('Daily interstitial limit reached.');
      return false;
    }
    final ad = _interstitialAd;
    if (ad == null) {
      _log('Interstitial not ready.');
      _scheduleRetry(immediate: true);
      return false;
    }
    _interstitialAd = null;
    _lastInterstitialShownAt = DateTime.now();
    _incrementShownToday();
    _log('Showing interstitial.');
    ad.show();
    return true;
  }

  bool get _isCooldownSatisfied {
    final last = _lastInterstitialShownAt;
    if (last == null) return true;
    return DateTime.now().difference(last) >= _interstitialCooldown;
  }

  Widget banner({
    AdSize size = AdSize.banner,
    AlignmentGeometry alignment = Alignment.bottomCenter,
    EdgeInsetsGeometry? margin,
  }) {
    return BannerView(size: size, alignment: alignment, margin: margin);
  }

  void dispose() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }

  void _rollDailyCounter() {
    final todayKey = _formatDayKey(DateTime.now());
    if (_currentDayKey == todayKey) return;
    final savedDay = _prefs?.getString(_prefsDayKey);
    if (savedDay == todayKey) {
      _shownToday = _prefs?.getInt(_prefsCountKey) ?? 0;
    } else {
      _shownToday = 0;
      _prefs?.setString(_prefsDayKey, todayKey);
      _prefs?.setInt(_prefsCountKey, 0);
    }
    _currentDayKey = todayKey;
  }

  void _incrementShownToday() {
    _rollDailyCounter();
    _shownToday += 1;
    _prefs?.setInt(_prefsCountKey, _shownToday);
  }

  String _formatDayKey(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${date.year}$mm$dd';
  }

  void _log(String message) {
    if (!debug) return;
    debugPrint('[Ads] $message');
  }
}


//--------new----
// ⬇️ NEW: replace your existing BannerView with this exact version
class BannerView extends StatefulWidget {
  const BannerView({
    super.key,
    this.size = AdSize.banner,
    this.margin,
    this.alignment = Alignment.bottomCenter, // (not used to expand)
  });

  final AdSize size;
  final EdgeInsetsGeometry? margin;
  final AlignmentGeometry alignment;

  @override
  State<BannerView> createState() => _BannerViewState();
}

class _BannerViewState extends State<BannerView> with AutomaticKeepAliveClientMixin {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _create();
  }

  void _create() {
    final ad = BannerAd(
      size: widget.size,
      adUnitId: AdIds.banner, // ✅ uses your routed id
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() {
            _ad = ad as BannerAd;
            _loaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _ad = null;
            _loaded = false;
          });
        },
      ),
    );
    ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final h = widget.size.height.toDouble();
    final w = widget.size.width.toDouble();

    // ✅ KEY FIX: only reserve exact banner height when loaded; otherwise 0.
    return Material(
      elevation: _loaded ? 1 : 0,
      color: Colors.transparent,
      child: SafeArea(
        top: false,
   minimum: (widget.margin ?? EdgeInsets.zero) as EdgeInsets,

        child: SizedBox(
          width: w,
          height: _loaded ? h : 0,
          child: _loaded && _ad != null
              ? Center(child: AdWidget(ad: _ad!))
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}



//-----new----




class _LoadingPlaceholder extends StatelessWidget {
  const _LoadingPlaceholder({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: const SizedBox(
        height: 14,
        width: 14,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class ExitAdGuard extends StatefulWidget {
  const ExitAdGuard({
    super.key,
    required this.child,
    this.enabled = true,
    this.haptic = true,
  });

  final Widget child;
  final bool enabled;
  final bool haptic;

  @override
  State<ExitAdGuard> createState() => _ExitAdGuardState();
}

class _ExitAdGuardState extends State<ExitAdGuard> {
  bool _handling = false;

  Future<bool> _handleWillPop() async {
    if (!widget.enabled) return true;
    if (_handling) return true;
    _handling = true;
    try {
      if (widget.haptic) {
        await HapticFeedback.lightImpact();
      }
      await Ads.instance.showExitInterstitial();
    } finally {
      _handling = false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return WillPopScope(onWillPop: _handleWillPop, child: widget.child);
  }
}
