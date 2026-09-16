import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geocoding;

import '../widgets/subtle_loading.dart';
import '../main.dart';
import '../services/location_service.dart';
import '../services/prayer_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _contentController;
  late final AnimationController _loadingController;

  late final Animation<double> _noorFade;
  late final Animation<double> _subtitleFade;
  late final Animation<double> _detailsFade;

  PrayerTimes? _prayerTimes;
  String? _locationText;
  String? _splashError;

  @override
  void initState() {
    super.initState();

    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _noorFade = CurvedAnimation(
      parent: _contentController,
      curve: const Interval(
        0.20,
        0.70,
        curve: Curves.easeOut,
      ),
    );

    _subtitleFade = CurvedAnimation(
      parent: _contentController,
      curve: const Interval(
        0.35,
        0.85,
        curve: Curves.easeOut,
      ),
    );

    _detailsFade = CurvedAnimation(
      parent: _contentController,
      curve: const Interval(
        0.50,
        1.0,
        curve: Curves.easeInOut,
      ),
    );

    _contentController.forward();

    _loadPrayerData();
  }

  void _retryPrayerData() {
    if (!mounted) return;

    setState(() {
      _splashError = null;
    });

    _loadPrayerData();
  }

  Future<void> _loadPrayerData() async {
    try {
      debugPrint('[SPLASH] Starting prayer data load');
      final locationService = LocationService();
      debugPrint('[SPLASH] Requesting current location');
      final position = await locationService.getCurrentPosition();
      debugPrint('[SPLASH] Location received: ${position.latitude}, ${position.longitude}');

      debugPrint('[SPLASH] Starting prayer API request');
      final prayerService = PrayerService();
      final prayerTimes = await prayerService.getPrayerTimes(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      debugPrint('[SPLASH] Prayer times received');
      String locationName = 'Unknown location';

      try {
        debugPrint('[SPLASH] Starting reverse geocoding');
        final geocoder = geocoding.Geocoding();
        final placemarks =
            await geocoder.placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;

          final city = place.locality?.trim();
          final state = place.administrativeArea?.trim();
          final country = place.country?.trim();

          final parts = <String>[
            if (city != null && city.isNotEmpty) city,
            if (state != null &&
                state.isNotEmpty &&
                state != city)
              state,
            if (country != null && country.isNotEmpty) country,
          ];

          if (parts.isNotEmpty) {
            locationName = parts.join(', ');
          }
        }
      } catch (_) {
        locationName = 'Location unavailable';
      }

      debugPrint('[SPLASH] Prayer data ready, opening Home');
      if (!mounted) return;

      setState(() {
        _prayerTimes = prayerTimes;
        _locationText = locationName;
      });

      _openHome();
    } catch (e, stackTrace) {
      debugPrint('[SPLASH] ERROR: $e');
      debugPrint('[SPLASH] STACK: $stackTrace');

      if (!mounted) return;

      setState(() {
        _splashError = e.toString();
      });
    }
  }

  void _openHome() {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, animation, secondaryAnimation) => NoorShell(
          prayerTimes: _prayerTimes!,
          locationText: _locationText ?? 'Location unavailable',
        ),
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/noor_splash_background.png',
            fit: BoxFit.cover,
          ),

          // Very subtle overlay for text readability.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  NoorApp.darkGreen.withValues(alpha: 0.18),
                  NoorApp.darkGreen.withValues(alpha: 0.48),
                ],
                stops: const [0.0, 0.42, 0.72, 1.0],
              ),
            ),
          ),

          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  bottom: size.height < 700 ? 28 : 46,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeTransition(
                      opacity: _noorFade,
                      child: const Text(
                        'Noor',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: NoorApp.gold,
                          fontSize: 48,
                          height: 1.0,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Georgia',
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),

                    const SizedBox(height: 9),

                    FadeTransition(
                      opacity: _subtitleFade,
                      child: const Text(
                        'Prayer & Tasbeeh',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFF4F0E6),
                          fontSize: 22,
                          height: 1.1,
                          fontWeight: FontWeight.w400,
                          fontFamily: 'Georgia',
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    FadeTransition(
                      opacity: _detailsFade,
                      child: Column(
                        children: [
                          _OrnamentalDivider(),

                          const SizedBox(height: 17),

                          const Text(
                            'A JOURNEY CLOSER\nTO ALLAH',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFEDE9DE),
                              fontSize: 10,
                              height: 1.65,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 4.5,
                            ),
                          ),

                          const SizedBox(height: 24),

                          if (_splashError == null)
                            AnimatedBuilder(
                              animation: _loadingController,
                              builder: (_, child) {
                                return SubtleLoading(
                                  progress: _loadingController.value,
                                );
                              },
                            )
                          else
                            Column(
                              children: [
                                Text(
                                  _splashError!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFEDE9DE),
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextButton(
                                  onPressed: _retryPrayerData,
                                  child: const Text(
                                    'RETRY',
                                    style: TextStyle(
                                      color: NoorApp.gold,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrnamentalDivider extends StatelessWidget {
  const _OrnamentalDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _line(),
        const SizedBox(width: 9),
        Transform.rotate(
          angle: 0.785398,
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              border: Border.all(
                color: NoorApp.gold.withValues(alpha: 0.9),
                width: 1,
              ),
            ),
          ),
        ),
        const SizedBox(width: 9),
        _line(),
      ],
    );
  }

  Widget _line() {
    return Container(
      width: 62,
      height: 1,
      color: NoorApp.gold.withValues(alpha: 0.65),
    );
  }
}
