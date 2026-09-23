import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/location_service.dart';
import 'services/prayer_service.dart';
import 'services/iqamah_service.dart';
import 'services/update_service.dart';
import 'screens/splash_screen.dart';

class NoorResponsive {
  static double horizontalPadding(double width) {
    if (width < 360) return 12;
    if (width < 600) return 16;
    if (width < 900) return 24;
    if (width < 1200) return 32;
    return 40;
  }

  static double contentMaxWidth(double width) {
    if (width < 600) return width;
    if (width < 900) return 760;
    if (width < 1200) return 1000;
    return 1200;
  }

  static double scale(
    double width, {
    required double min,
    required double max,
    double designWidth = 390,
  }) {
    final value = width / designWidth * min;
    return value.clamp(min, max);
  }

  static bool isSmallPhone(double width) => width < 360;

  static bool isPhone(double width) => width < 600;

  static bool isTablet(double width) =>
      width >= 600 && width < 900;

  static bool isDesktop(double width) => width >= 900;
}

void main() {
  runApp(const NoorApp());
}

class NoorApp extends StatelessWidget {
  const NoorApp({super.key});

  static const gold = Color(0xFFD4AF37);
  static const darkGreen = Color(0xFF061A16);
  static const cardGreen = Color(0xFF0B241F);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Noor Prayer & Tasbeeh',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkGreen,
        colorScheme: ColorScheme.fromSeed(
          seedColor: gold,
          brightness: Brightness.dark,
        ),
        fontFamily: 'Arial',
      ),
      home: const SplashScreen(),
    );
  }
}

// ============================================================
// PRAYER PAGE
// ============================================================

class PrayerPage extends StatefulWidget {
  final ValueNotifier<IqamahSettings> settingsNotifier;

  const PrayerPage({
    super.key,
    required this.settingsNotifier,
  });

  @override
  State<PrayerPage> createState() => _PrayerPageState();
}

class _PrayerPageState extends State<PrayerPage> {
  PrayerTimes? _prayerTimes;
  String? _errorMessage;

  Timer? _timer;
  DateTime _now = DateTime.now();
  bool _isLoading = false;


  @override
  void initState() {
    super.initState();

    widget.settingsNotifier.addListener(_settingsChanged);

    _loadPrayerTimes();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted) {
          setState(() {
            _now = DateTime.now();
          });
        }
      },
    );
  }

  @override
  void dispose() {
    widget.settingsNotifier.removeListener(_settingsChanged);
    _timer?.cancel();
    super.dispose();
  }

  void _settingsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadPrayerTimes() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final locationService = LocationService();

      final position = await locationService.getCurrentPosition();

      final prayerService = PrayerService();

      final prayerTimes = await prayerService.getPrayerTimes(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!mounted) return;

      setState(() {
        _prayerTimes = prayerTimes;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  DateTime? _parsePrayerTime(String? value) {
    if (value == null || value == '--:--') {
      return null;
    }

    try {
      final parts = value.split(':');

      if (parts.length < 2) {
        return null;
      }

      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      return DateTime(
        _now.year,
        _now.month,
        _now.day,
        hour,
        minute,
      );
    } catch (_) {
      return null;
    }
  }

  List<_PrayerData> _prayers() {
    final times = _prayerTimes;

    if (times == null) {
      return [];
    }

    return [
      _PrayerData(
        name: 'Fajr',
        time: times.fajr,
        icon: Icons.nightlight_round,
      ),
      _PrayerData(
        name: 'Dhuhr',
        time: times.dhuhr,
        icon: Icons.wb_sunny_outlined,
      ),
      _PrayerData(
        name: 'Asr',
        time: times.asr,
        icon: Icons.wb_twilight,
      ),
      _PrayerData(
        name: 'Maghrib',
        time: times.maghrib,
        icon: Icons.wb_sunny,
      ),
      _PrayerData(
        name: 'Isha',
        time: times.isha,
        icon: Icons.dark_mode_outlined,
      ),
    ];
  }

  _PrayerStatus _getPrayerStatus(_PrayerData prayer) {
    final adhanTime = _parsePrayerTime(prayer.time);

    if (adhanTime == null) {
      return _PrayerStatus(
        type: _PrayerStatusType.upcoming,
        prayer: prayer,
      );
    }

    final settings = widget.settingsNotifier.value;

    final iqamahService = IqamahService(
      settings: settings,
    );

    final state = iqamahService.createState(
      prayerName: prayer.name,
      prayerTime: prayer.time,
      date: _now,
    );

    // Before Adhan
    if (_now.isBefore(state.adhanTime)) {
      return _PrayerStatus(
        type: _PrayerStatusType.upcoming,
        prayer: prayer,
        adhanTime: state.adhanTime,
        iqamahTime: state.iqamahTime,
      );
    }

    // From Adhan until Iqamah
    if (_now.isBefore(state.iqamahTime)) {
      return _PrayerStatus(
        type: _PrayerStatusType.adhanNow,
        prayer: prayer,
        adhanTime: state.adhanTime,
        iqamahTime: state.iqamahTime,
      );
    }

    // Iqamah moment
    if (_now.difference(state.iqamahTime).inSeconds <= 1) {
      return _PrayerStatus(
        type: _PrayerStatusType.iqamahNow,
        prayer: prayer,
        adhanTime: state.adhanTime,
        iqamahTime: state.iqamahTime,
      );
    }

    // After Iqamah
    return _PrayerStatus(
      type: _PrayerStatusType.completed,
      prayer: prayer,
      adhanTime: state.adhanTime,
      iqamahTime: state.iqamahTime,
    );
  }

  _PrayerStatus? _activeStatus() {
    final prayers = _prayers();

    for (final prayer in prayers) {
      final status = _getPrayerStatus(prayer);

      if (status.type == _PrayerStatusType.adhanNow ||
          status.type == _PrayerStatusType.iqamahNow) {
        return status;
      }
    }

    return null;
  }

  _PrayerStatus? _nextPrayerStatus() {
    final prayers = _prayers();

    for (final prayer in prayers) {
      final status = _getPrayerStatus(prayer);

      if (status.type == _PrayerStatusType.upcoming) {
        return status;
      }
    }

    // All of today's prayers are completed.
    // The next prayer is tomorrow's Fajr.
    if (prayers.isNotEmpty) {
      final fajr = prayers.first;
      final tomorrow = _now.add(const Duration(days: 1));

      final fajrTime = _parsePrayerTime(fajr.time);

      if (fajrTime != null) {
        final nextFajr = DateTime(
          tomorrow.year,
          tomorrow.month,
          tomorrow.day,
          fajrTime.hour,
          fajrTime.minute,
        );

        return _PrayerStatus(
          type: _PrayerStatusType.upcoming,
          prayer: fajr,
          adhanTime: nextFajr,
          iqamahTime: nextFajr.add(
            Duration(
              minutes: widget.settingsNotifier.value.delayFor(fajr.name),
            ),
          ),
        );
      }
    }

    return null;
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;

    if (totalSeconds <= 0) {
      return '00:00';
    }

    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  String _statusTitle(_PrayerStatus status) {
    switch (status.type) {
      case _PrayerStatusType.upcoming:
        return 'Next Prayer';

      case _PrayerStatusType.adhanNow:
        return '🔔 ${status.prayer.name} Adhan — Now';

      case _PrayerStatusType.iqamahNow:
        return '🕌 ${status.prayer.name} Iqamah — Now';

      case _PrayerStatusType.completed:
        return '${status.prayer.name} Completed';
    }
  }

  Widget _buildStatusCard() {
    final active = _activeStatus();

    if (active != null) {
      final remaining = active.iqamahTime == null
          ? Duration.zero
          : active.iqamahTime!.difference(_now);

      if (active.type == _PrayerStatusType.adhanNow) {
        return _glassCard(
          child: Column(
            children: [
              const Icon(
                Icons.notifications_active_outlined,
                color: NoorApp.gold,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                _statusTitle(active),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: NoorApp.gold,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Iqamah in',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDuration(remaining),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${_formatIqamahDelay(active.prayer.name)} minutes after Adhan',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      }

      return _glassCard(
        child: Column(
          children: [
            const Icon(
              Icons.mosque,
              color: NoorApp.gold,
              size: 50,
            ),
            const SizedBox(height: 12),
            Text(
              _statusTitle(active),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: NoorApp.gold,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    final next = _nextPrayerStatus();

    if (next != null && next.adhanTime != null) {
      final remaining = next.adhanTime!.difference(_now);

      return _glassCard(
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x22D4AF37),
                border: Border.all(
                  color: const Color(0x55D4AF37),
                ),
              ),
              child: const Icon(
                Icons.access_time,
                color: NoorApp.gold,
                size: 28,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Next Prayer',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    next.prayer.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    formatPrayerTime(next.prayer.time),
                    style: const TextStyle(
                      color: NoorApp.gold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _formatDuration(remaining),
              style: const TextStyle(
                color: NoorApp.gold,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return _glassCard(
      child: const Center(
        child: Text(
          'Prayer times are ready',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  int _formatIqamahDelay(String prayerName) {
    return widget.settingsNotifier.value.delayFor(prayerName);
  }

  Widget _buildPrayerCard(_PrayerData prayer) {
    final status = _getPrayerStatus(prayer);

    String? badge;

    if (status.type == _PrayerStatusType.adhanNow) {
      badge = 'ADHAN NOW';
    } else if (status.type == _PrayerStatusType.iqamahNow) {
      badge = 'IQAMAH NOW';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0x22152F29),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: badge != null
              ? const Color(0x99D4AF37)
              : const Color(0x3322D4AF),
        ),
        boxShadow: badge != null
            ? const [
                BoxShadow(
                  color: Color(0x22D4AF37),
                  blurRadius: 16,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Icon(
            prayer.icon,
            color: NoorApp.gold,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prayer.name,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatPrayerTime(prayer.time),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: const Color(0x22D4AF37),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  color: NoorApp.gold,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prayers = _prayers();

    return Scaffold(
      backgroundColor: NoorApp.darkGreen,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 900,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Prayer Times',
                              style: TextStyle(
                                color: NoorApp.gold,
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Prayer Times & Iqamah',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: _loadPrayerTimes,
                        icon: const Icon(
                          Icons.refresh,
                          color: NoorApp.gold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  if (_isLoading)
                    _glassCard(
                      child: Column(
                        children: [
                          const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              color: NoorApp.gold,
                              strokeWidth: 2.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Loading prayer times...',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_errorMessage != null)
                    _glassCard(
                      child: Column(
                        children: [
                          const Icon(
                            Icons.location_off_outlined,
                            color: NoorApp.gold,
                            size: 42,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Unable to load prayer times',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _loadPrayerTimes,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try Again'),
                          ),
                        ],
                      ),
                    )
                  else if (_prayerTimes == null)
                    _glassCard(
                      child: const Column(
                        children: [
                          Icon(
                            Icons.mosque_outlined,
                            color: NoorApp.gold,
                            size: 48,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Loading Prayer Times...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Preparing your daily prayer schedule',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    _buildStatusCard(),

                  const SizedBox(height: 20),

                  if (prayers.isNotEmpty) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildPrayerCard(prayers[0]),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPrayerCard(prayers[1]),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _buildPrayerCard(prayers[2]),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPrayerCard(prayers[3]),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    _buildPrayerCard(prayers[4]),
                  ],
                ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _glassCard({
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0x33152F29),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0x44D4AF37),
        ),
      ),
      child: child,
    );
  }
}

class _PrayerData {
  final String name;
  final String time;
  final IconData icon;

  const _PrayerData({
    required this.name,
    required this.time,
    required this.icon,
  });
}

enum _PrayerStatusType {
  upcoming,
  adhanNow,
  iqamahNow,
  completed,
}

class _PrayerStatus {
  final _PrayerStatusType type;
  final _PrayerData prayer;
  final DateTime? adhanTime;
  final DateTime? iqamahTime;

  const _PrayerStatus({
    required this.type,
    required this.prayer,
    this.adhanTime,
    this.iqamahTime,
  });
}

// ============================================================
// SETTINGS PAGE
// ============================================================

class SettingsPage extends StatefulWidget {
  final ValueNotifier<IqamahSettings> settingsNotifier;

  const SettingsPage({
    super.key,
    required this.settingsNotifier,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final IqamahStorage _storage = IqamahStorage();

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _storage.loadSettings();

    if (!mounted) return;

    widget.settingsNotifier.value = settings;

    setState(() {
      _loading = false;
    });
  }

  Future<void> _editPrayer(
    String prayerName,
    int currentValue,
  ) async {
    final controller = TextEditingController(
      text: currentValue.toString(),
    );

    final value = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: NoorApp.cardGreen,
          title: Text(
            '$prayerName Iqamah',
            style: const TextStyle(
              color: NoorApp.gold,
            ),
          ),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            style: const TextStyle(
              color: Colors.white,
            ),
            decoration: const InputDecoration(
              labelText: 'Minutes after Adhan',
              suffixText: 'min',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = int.tryParse(
                  controller.text.trim(),
                );

                if (parsed == null || parsed < 0) {
                  return;
                }

                Navigator.pop(context, parsed);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (value == null) return;

    final old = widget.settingsNotifier.value;

    final updated = IqamahSettings(
      fajrMinutes:
          prayerName == 'Fajr' ? value : old.fajrMinutes,
      dhuhrMinutes:
          prayerName == 'Dhuhr' ? value : old.dhuhrMinutes,
      asrMinutes:
          prayerName == 'Asr' ? value : old.asrMinutes,
      maghribMinutes:
          prayerName == 'Maghrib' ? value : old.maghribMinutes,
      ishaMinutes:
          prayerName == 'Isha' ? value : old.ishaMinutes,
    );

    await _storage.saveSettings(updated);

    widget.settingsNotifier.value = updated;

    if (mounted) {
      setState(() {});
    }
  }

  Widget _durationTile({
    required String prayer,
    required int minutes,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0x331B4D42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0x33D4AF37),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 5,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0x22D4AF37),
            border: Border.all(
              color: const Color(0x44D4AF37),
            ),
          ),
          child: Icon(
            icon,
            color: NoorApp.gold,
          ),
        ),
        title: Text(
          prayer,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '$minutes minutes after Adhan',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
          ),
        ),
        trailing: const Icon(
          Icons.edit_outlined,
          color: NoorApp.gold,
        ),
        onTap: () => _editPrayer(
          prayer,
          minutes,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settingsNotifier.value;

    return Scaffold(
      backgroundColor: NoorApp.darkGreen,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 700,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Settings',
                    style: TextStyle(
                      color: NoorApp.gold,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Prayer & Iqamah Settings',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 28),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0x331B4D42),
                      borderRadius:
                          BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0x33D4AF37),
                      ),
                    ),
                    child: const Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.mosque_outlined,
                              color: NoorApp.gold,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Iqamah Duration',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Set how many minutes after each Adhan the Iqamah should begin.',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(30),
                        child: CircularProgressIndicator(
                          color: NoorApp.gold,
                        ),
                      ),
                    )
                  else ...[
                    _durationTile(
                      prayer: 'Fajr',
                      minutes: settings.fajrMinutes,
                      icon: Icons.nightlight_round,
                    ),
                    _durationTile(
                      prayer: 'Dhuhr',
                      minutes: settings.dhuhrMinutes,
                      icon: Icons.wb_sunny_outlined,
                    ),
                    _durationTile(
                      prayer: 'Asr',
                      minutes: settings.asrMinutes,
                      icon: Icons.wb_twilight,
                    ),
                    _durationTile(
                      prayer: 'Maghrib',
                      minutes: settings.maghribMinutes,
                      icon: Icons.wb_sunny,
                    ),
                    _durationTile(
                      prayer: 'Isha',
                      minutes: settings.ishaMinutes,
                      icon: Icons.dark_mode_outlined,
                    ),
                  ],

                  const SizedBox(height: 25),

                  const Center(
                    child: Text(
                      'Iqamah settings are saved automatically',
                      style: TextStyle(
                        color: Color(0x66D4AF37),
                        fontSize: 11,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Center(
                    child: Text(
                      'Created by Safwan',
                      style: TextStyle(
                        color: Color(0x88D4AF37),
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// MAIN NAVIGATION SHELL
// ============================================================

class NoorShell extends StatefulWidget {
  const NoorShell({
    super.key,
    required this.prayerTimes,
    required this.locationText,
  });

  final PrayerTimes prayerTimes;
  final String locationText;

  @override
  State<NoorShell> createState() => _NoorShellState();
}

class _NoorShellState extends State<NoorShell> {
  static const MethodChannel _updateChannel = MethodChannel('noor.app/update');
  int _selectedIndex = 0;

  final ValueNotifier<IqamahSettings> _settingsNotifier =
      ValueNotifier(const IqamahSettings());

  late final List<Widget> _pages;

  final List<NavigationDestination> _destinations = const [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.mosque_outlined),
      selectedIcon: Icon(Icons.mosque),
      label: 'Prayer',
    ),
    NavigationDestination(
      icon: Icon(Icons.radio_button_unchecked),
      selectedIcon: Icon(Icons.radio_button_checked),
      label: 'Tasbeeh',
    ),
    NavigationDestination(
      icon: Icon(Icons.menu_book_outlined),
      selectedIcon: Icon(Icons.menu_book),
      label: 'Quran',
    ),
    NavigationDestination(
      icon: Icon(Icons.auto_stories_outlined),
      selectedIcon: Icon(Icons.auto_stories),
      label: 'Duas',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'Settings',
    ),
  ];

  @override
  void initState() {
    super.initState();

    _pages = [
      NoorHomePage(
        onNavigate: _onDestinationSelected,
        prayerTimes: widget.prayerTimes,
        locationText: widget.locationText,
      ),
      PrayerPage(
        settingsNotifier: _settingsNotifier,
      ),
      TasbeehPage(onBackToHome: () => _onDestinationSelected(0)),
      const SectionPage(
        icon: Icons.menu_book_outlined,
        title: 'Quran',
        subtitle: 'Complete Quran',
      ),
      const SectionPage(
        icon: Icons.auto_stories_outlined,
        title: 'Duas',
        subtitle: 'Duas & Adhkar',
      ),
      SettingsPage(
        settingsNotifier: _settingsNotifier,
      ),
    ];

    _checkForAppUpdate();
  }

  Future<void> _checkForAppUpdate() async {
    try {
      final updateService = UpdateService();
      final update = await updateService.checkForUpdate();

      if (!mounted || update == null) return;

      final shouldUpdate = await _showUpdateDialog(update);

      if (!shouldUpdate || !mounted) return;

      _showDownloadDialog();

      try {
        final apkPath = await updateService.downloadApk(update);

        if (!mounted) return;

        Navigator.of(context, rootNavigator: true).pop();

        await _updateChannel.invokeMethod<bool>(
          'installApk',
          <String, dynamic>{
            'apkPath': apkPath,
          },
        );
      } catch (_) {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();

          await showDialog<void>(
            context: context,
            builder: (dialogContext) {
              return AlertDialog(
                backgroundColor: NoorApp.cardGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: const BorderSide(
                    color: NoorApp.gold,
                    width: 0.7,
                  ),
                ),
                title: const Text(
                  'Update Failed',
                  style: TextStyle(
                    color: NoorApp.gold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                content: const Text(
                  'The update could not be installed. Please try again later.',
                  style: TextStyle(
                    color: Color(0xFFEDE9DE),
                    height: 1.5,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        color: NoorApp.gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        }
      }
    } catch (_) {
      // Update checking must never interrupt normal app usage.
    }
  }

  Future<bool> _showUpdateDialog(AppUpdateInfo update) async {
    if (!mounted) return false;

    final shouldUpdate = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: NoorApp.cardGreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(
              color: NoorApp.gold,
              width: 0.7,
            ),
          ),
          title: const Text(
            'Update Available',
            style: TextStyle(
              color: NoorApp.gold,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'A new version of Noor is ready.\n\n'
            'Version ${update.version} is available.',
            style: const TextStyle(
              color: Color(0xFFEDE9DE),
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text(
                'LATER',
                style: TextStyle(
                  color: Color(0xFFBDB7A8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: NoorApp.gold,
                foregroundColor: NoorApp.darkGreen,
              ),
              child: const Text(
                'UPDATE NOW',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    return shouldUpdate ?? false;
  }

  void _showDownloadDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: NoorApp.cardGreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(
              color: NoorApp.gold,
              width: 0.7,
            ),
          ),
          content: const Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: NoorApp.gold,
                ),
              ),
              SizedBox(width: 20),
              Expanded(
                child: Text(
                  'Downloading update...',
                  style: TextStyle(
                    color: Color(0xFFEDE9DE),
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _settingsNotifier.dispose();
    super.dispose();
  }

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isLargeScreen =
            constraints.maxWidth >= 600;

        if (isLargeScreen) {
          return Scaffold(
            body: Row(
              children: [
                _buildNavigationRail(),
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: _pages,
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          body: IndexedStack(
            index: _selectedIndex,
            children: _pages,
          ),
          bottomNavigationBar: _buildNavigationBar(),
        );
      },
    );
  }

  Widget _buildNavigationBar() {
    return NavigationBar(
      height: 80,
      selectedIndex: _selectedIndex,
      onDestinationSelected: _onDestinationSelected,
      backgroundColor: const Color(0xFF0B241F),
      indicatorColor: const Color(0x55D4AF37),
      elevation: 12,
      labelBehavior:
          NavigationDestinationLabelBehavior.alwaysShow,
      destinations: _destinations,
      labelTextStyle:
          WidgetStateProperty.resolveWith(
        (states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: NoorApp.gold,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            );
          }

          return const TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: 11,
          );
        },
      ),
    );
  }

  Widget _buildNavigationRail() {
    return Container(
      width: 96,
      decoration: const BoxDecoration(
        color: Color(0xF20B241F),
        border: Border(
          right: BorderSide(
            color: Color(0x332A2A2A),
          ),
        ),
      ),
      child: NavigationRail(
        selectedIndex: _selectedIndex,
        onDestinationSelected:
            _onDestinationSelected,
        backgroundColor: Colors.transparent,
        labelType: NavigationRailLabelType.all,
        selectedIconTheme:
            const IconThemeData(
          color: NoorApp.gold,
          size: 25,
        ),
        unselectedIconTheme:
            const IconThemeData(
          color: Color(0x99FFFFFF),
          size: 23,
        ),
        selectedLabelTextStyle:
            const TextStyle(
          color: NoorApp.gold,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle:
            const TextStyle(
          color: Color(0x99FFFFFF),
          fontSize: 11,
        ),
        indicatorColor:
            const Color(0x33D4AF37),
        destinations: _destinations
            .map(
              (destination) =>
                  NavigationRailDestination(
                icon: destination.icon,
                selectedIcon:
                    destination.selectedIcon,
                label: Text(destination.label),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ============================================================
// SIMPLE SECTION PAGE
// ============================================================

class SectionPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const SectionPage({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0x221B4D42),
                  border: Border.all(
                    color: const Color(0x55D4AF37),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: NoorApp.gold,
                  size: 44,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFD9D9D9),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Coming next',
                style: TextStyle(
                  color: Color(0x99D4AF37),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ============================================================
// SMART RING EXPLORE PAGE
// ============================================================

class SmartRingExplorePage extends StatelessWidget {
  const SmartRingExplorePage({super.key});

  static const Color _background = Color(0xFF061A15);
  static const Color _deepGreen = Color(0xFF08251D);
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _softGold = Color(0xFFE8D889);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final horizontalPadding = NoorResponsive.horizontalPadding(width);

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      12,
                      horizontalPadding,
                      28,
                    ),
                    child: Column(
                      children: [
                        _buildTopBar(context),
                        const SizedBox(height: 14),
                        _buildHero(context, width),
                        const SizedBox(height: 18),
                        _buildFeatures(width),
                        const SizedBox(height: 18),
                        _buildMoreSection(width),
                        const SizedBox(height: 18),
                        _buildChatButton(context, width),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x331B4D42),
                border: Border.all(
                  color: const Color(0x55D4AF37),
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: _softGold,
                size: 19,
              ),
            ),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: const Color(0x221B4D42),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0x44D4AF37),
            ),
          ),
          child: const Text(
            'NOOR SMART RING',
            style: TextStyle(
              color: _gold,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHero(BuildContext context, double width) {
    final heroHeight = NoorResponsive.scale(
      width,
      min: 500,
      max: 700,
      designWidth: 390,
    );

    return Container(
      width: double.infinity,
      height: heroHeight,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0A3025),
            Color(0xFF061B15),
            Color(0xFF03110D),
          ],
        ),
        border: Border.all(
          color: _softGold,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: _gold.withOpacity(0.12),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: -100,
            top: -100,
            child: Container(
              width: 420,
              height: 420,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _gold.withOpacity(0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            right: -100,
            bottom: -80,
            child: Container(
              width: 420,
              height: 420,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _gold.withOpacity(0.16),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            left: 24,
            right: 24,
            top: 20,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xCC06251D),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _gold,
                    ),
                  ),
                  child: const Text(
                    'NOOR PRAYER & TASBEEH',
                    style: TextStyle(
                      color: _gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            left: 24,
            top: 82,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SMART RING',
                  style: TextStyle(
                    color: const Color(0xFFE7D9A1),
                    fontSize: NoorResponsive.scale(
                      width,
                      min: 16,
                      max: 24,
                    ),
                    letterSpacing: 5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Faith in Every Step',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: NoorResponsive.scale(
                      width,
                      min: 24,
                      max: 38,
                    ),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            left: 12,
            right: 12,
            bottom: 55,
            height: heroHeight * 0.48,
            child: Image.asset(
              'assets/images/noor_smart_ring.png',
              fit: BoxFit.contain,
            ),
          ),

          Positioned(
            right: 24,
            top: 30,
            child: Icon(
              Icons.nightlight_round,
              color: _gold.withOpacity(0.9),
              size: NoorResponsive.scale(
                width,
                min: 42,
                max: 70,
              ),
            ),
          ),

          Positioned(
            right: 20,
            bottom: 30,
            child: Opacity(
              opacity: 0.16,
              child: Icon(
                Icons.mosque,
                color: _gold,
                size: NoorResponsive.scale(
                  width,
                  min: 130,
                  max: 230,
                ),
              ),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _gold.withOpacity(0.30),
                    const Color(0xFF0A211A),
                  ],
                ),
                border: Border(
                  top: BorderSide(
                    color: _gold.withOpacity(0.40),
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatures(double width) {
    final features = [
      (Icons.touch_app_outlined, 'Dhikr Count'),
      (Icons.directions_walk_outlined, 'Activity'),
      (Icons.favorite_border, 'Heart Rate'),
      (Icons.bedtime_outlined, 'Sleep'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x221B4D42),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0x33D4AF37),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceEvenly,
        runSpacing: 14,
        spacing: 10,
        children: features.map((feature) {
          return SizedBox(
            width: NoorResponsive.scale(
              width,
              min: 125,
              max: 190,
            ),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0x221B4D42),
                    border: Border.all(
                      color: const Color(0x55D4AF37),
                    ),
                  ),
                  child: Icon(
                    feature.$1,
                    color: _gold,
                    size: 23,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  feature.$2,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMoreSection(double width) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 20,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0x332D5A4B),
            Color(0x221B4D42),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0x33D4AF37),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0x22D4AF37),
              border: Border.all(
                color: const Color(0x55D4AF37),
              ),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: _gold,
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AND MORE',
                  style: TextStyle(
                    color: _gold,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Prayer vibration • SpO₂ • Battery • Find Ring',
                  style: TextStyle(
                    color: Color(0xBFFFFFFF),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatButton(BuildContext context, double width) {
    return SizedBox(
      width: double.infinity,
      height: NoorResponsive.scale(
        width,
        min: 58,
        max: 70,
      ),
      child: ElevatedButton(
        onPressed: () async {
          final uri = Uri.parse(
            'https://www.instagram.com/noor_prayer_tasbeeh/',
          );

          await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: _gold,
          foregroundColor: const Color(0xFF071B15),
          elevation: 8,
          shadowColor: _gold.withOpacity(0.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text(
              'CHAT FOR MORE DETAILS',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            SizedBox(width: 10),
            Icon(
              Icons.arrow_forward_rounded,
              size: 21,
            ),
          ],
        ),
      ),
    );
  }
}

class TasbeehPage extends StatefulWidget {
  const TasbeehPage({
    super.key,
    required this.onBackToHome,
  });

  final VoidCallback onBackToHome;

  @override
  State<TasbeehPage> createState() => _TasbeehPageState();
}

class _TasbeehPageState extends State<TasbeehPage> {
  int _selectedTab = 0;
  int _currentDhikrIndex = 0;
  int _currentCount = 0;

  final List<int> _dhikrTargets = [33, 33, 33, 11, 11];

  final List<String> _dhikrNames = [
    'SubhanAllah',
    'Alhamdulillah',
    'Allahu Akbar',
    'La ilaha illallah',
    'Salawat',
  ];

  final List<String> _dhikrArabic = [
    'سبحان الله',
    'الحمد لله',
    'الله اكبر',
    'لا اله الا الله',
    'صلى الله على محمد صلى الله عليه وسلم',
  ];

  final List<Map<String, dynamic>> _myDhikr = [];
  final List<Map<String, dynamic>> _myDhikrHistory = [];

  int _selectedMyDhikrIndex = 0;

  static const String _myDhikrStorageKey = 'noor_my_dhikr';
  static const String _myDhikrHistoryStorageKey = 'noor_my_dhikr_history';

  @override
  void initState() {
    super.initState();
    _loadMyDhikr();
    _loadMyDhikrHistory();
  }

  Future<void> _loadMyDhikr() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_myDhikrStorageKey);

    if (saved == null || saved.isEmpty || !mounted) {
      return;
    }

    final loaded = <Map<String, dynamic>>[];

    for (final item in saved) {
      try {
        final parts = item.split('|');

        // Support both the old format:
        // name|arabic|target|count
        // and the new format:
        // name|target|count
        String name;
        int target;
        int count;

        if (parts.length == 4) {
          name = parts[0];
          target = int.parse(parts[2]);
          count = int.parse(parts[3]);
        } else if (parts.length == 3) {
          name = parts[0];
          target = int.parse(parts[1]);
          count = int.parse(parts[2]);
        } else {
          continue;
        }

        if (name.trim().isEmpty || target <= 0 || count < 0) {
          continue;
        }

        loaded.add({
          'name': name,
          'target': target,
          'count': count > target ? target : count,
        });
      } catch (_) {
        // Ignore invalid saved entries.
      }
    }

    if (!mounted || loaded.isEmpty) {
      return;
    }

    setState(() {
      _myDhikr
        ..clear()
        ..addAll(loaded);
      if (_selectedMyDhikrIndex >= _myDhikr.length) {
        _selectedMyDhikrIndex = 0;
      }
    });
  }

  Future<void> _loadMyDhikrHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_myDhikrHistoryStorageKey) ?? [];

    final loaded = <Map<String, dynamic>>[];

    for (final item in saved) {
      try {
        final parts = item.split('|');

        if (parts.length != 6) {
          continue;
        }

        final name = parts[0];
        final target = int.parse(parts[1]);
        final count = int.parse(parts[2]);
        final status = parts[3];
        final date = parts[4];
        final time = parts[5];

        if (name.trim().isEmpty ||
            target <= 0 ||
            count < 0 ||
            status.trim().isEmpty ||
            date.trim().isEmpty ||
            time.trim().isEmpty) {
          continue;
        }

        loaded.add({
          'name': name,
          'target': target,
          'count': count,
          'status': status,
          'date': date,
          'time': time,
        });
      } catch (_) {
        // Ignore invalid saved history entries.
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _myDhikrHistory
        ..clear()
        ..addAll(loaded.reversed);
    });
  }

  Future<void> _saveMyDhikr() async {
    final prefs = await SharedPreferences.getInstance();

    final saved = _myDhikr.map((dhikr) {
      final name = dhikr['name'] as String;
      final target = dhikr['target'] as int;
      final count = dhikr['count'] as int;

      return '$name|$target|$count';
    }).toList();

    await prefs.setStringList(_myDhikrStorageKey, saved);
  }

  Future<void> _saveMyDhikrHistory({
    required String name,
    required int target,
    required int count,
    required String status,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_myDhikrHistoryStorageKey) ?? [];

    final now = DateTime.now();
    final date = DateFormat('dd MMM yyyy').format(now);
    final time = DateFormat('hh:mm a').format(now);

    saved.add(
      '$name|$target|$count|$status|$date|$time',
    );

    await prefs.setStringList(
      _myDhikrHistoryStorageKey,
      saved,
    );
  }

  void _incrementDhikr() {
    setState(() {
      final target = _dhikrTargets[_currentDhikrIndex];

      if (_currentCount < target - 1) {
        _currentCount++;
        return;
      }

      if (_currentDhikrIndex < _dhikrTargets.length - 1) {
        _currentDhikrIndex++;
        _currentCount = 0;
      } else {
        _currentCount = target;
      }
    });
  }

  Future<void> _showAddDhikrDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final targetController = TextEditingController();

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: const Color(0xFF0B241F),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: const BorderSide(
                color: Color(0x44D4AF37),
              ),
            ),
            title: const Text(
              'Add Dhikr',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Dhikr',
                      labelStyle: TextStyle(color: Color(0xCCFFFFFF)),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: NoorApp.gold),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter a name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: targetController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Target Count',
                      labelStyle: TextStyle(color: Color(0xCCFFFFFF)),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: NoorApp.gold),
                      ),
                    ),
                    validator: (value) {
                      final target =
                          int.tryParse(value?.trim() ?? '');
                      if (target == null || target <= 0) {
                        return 'Enter a valid target';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(false),
                child: const Text(
                  'CANCEL',
                  style: TextStyle(color: Color(0xCCFFFFFF)),
                ),
              ),
              TextButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.of(dialogContext).pop(true);
                  }
                },
                child: const Text(
                  'SAVE',
                  style: TextStyle(
                    color: NoorApp.gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );
        },
      );

      if (saved == true) {
        final target = int.parse(targetController.text.trim());

        setState(() {
          _myDhikr.add({
            'name': nameController.text.trim(),
            'target': target,
            'count': 0,
          });
          _selectedMyDhikrIndex = _myDhikr.length - 1;
        });

        await _saveMyDhikr();
      }
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        nameController.dispose();
          targetController.dispose();
      });
    }
  }

  Future<void> _showEditTargetDialog() async {
    final dhikr = _myDhikr[_selectedMyDhikrIndex];
    final controller = TextEditingController(
      text: (dhikr['target'] as int).toString(),
    );
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0B241F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(
              color: Color(0x44D4AF37),
            ),
          ),
          title: const Text(
            'Edit Target',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Target Count',
                labelStyle: TextStyle(
                  color: Color(0xCCFFFFFF),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: NoorApp.gold,
                  ),
                ),
              ),
              validator: (value) {
                final target = int.tryParse(value?.trim() ?? '');
                if (target == null || target <= 0) {
                  return 'Enter a valid target';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                'CANCEL',
                style: TextStyle(color: Color(0xCCFFFFFF)),
              ),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: const Text(
                'SAVE',
                style: TextStyle(
                  color: NoorApp.gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (saved == true) {
      final newTarget = int.parse(controller.text.trim());

      setState(() {
        dhikr['target'] = newTarget;
        final currentCount = dhikr['count'] as int;
        if (currentCount > newTarget) {
          dhikr['count'] = newTarget;
        }
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
  }

  Widget _buildSmartRingCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: AspectRatio(
        aspectRatio: 1479 / 781,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.center,
            child: SizedBox(
              width: 1479,
              height: 781,
              child: Stack(
                children: [
                  // --------------------------------------------------
                  // Premium emerald background + Islamic atmosphere
                  // --------------------------------------------------
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF123F32),
                            NoorApp.darkGreen,
                            const Color(0xFF001C15),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Soft golden lighting
                  Positioned(
                    left: -120,
                    top: -120,
                    child: Container(
                      width: 520,
                      height: 520,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            NoorApp.gold.withOpacity(0.28),
                            NoorApp.gold.withOpacity(0.08),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    right: -100,
                    top: -80,
                    child: Container(
                      width: 620,
                      height: 620,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            NoorApp.gold.withOpacity(0.22),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // --------------------------------------------------
                  // Subtle Islamic arch background
                  // --------------------------------------------------
                  Positioned(
                    left: 45,
                    top: 50,
                    child: Container(
                      width: 420,
                      height: 610,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(210),
                        ),
                        border: Border.all(
                          color: NoorApp.gold.withOpacity(0.12),
                          width: 10,
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    right: 35,
                    top: 25,
                    child: Container(
                      width: 420,
                      height: 540,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(210),
                        ),
                        border: Border.all(
                          color: NoorApp.gold.withOpacity(0.20),
                          width: 9,
                        ),
                      ),
                    ),
                  ),

                  // --------------------------------------------------
                  // Faint mosque silhouette
                  // --------------------------------------------------
                  Positioned(
                    right: 55,
                    bottom: 95,
                    child: Opacity(
                      opacity: 0.20,
                      child: Icon(
                        Icons.mosque,
                        size: 410,
                        color: NoorApp.gold,
                      ),
                    ),
                  ),

                  // Mosque warm glow
                  Positioned(
                    right: 175,
                    bottom: 175,
                    child: Container(
                      width: 210,
                      height: 210,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            NoorApp.gold.withOpacity(0.35),
                            NoorApp.gold.withOpacity(0.06),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Crescent moon
                  Positioned(
                    right: 105,
                    top: 70,
                    child: Icon(
                      Icons.nightlight_round,
                      size: 100,
                      color: NoorApp.gold.withOpacity(0.92),
                    ),
                  ),

                  // --------------------------------------------------
                  // Outer premium gold border
                  // --------------------------------------------------
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: const Color(0xFFE8D889),
                            width: 5,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // --------------------------------------------------
                  // LEFT: NOOR PRAYER & TASBEEH
                  // --------------------------------------------------
                  Positioned(
                    left: 110,
                    top: 65,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF06291F).withOpacity(0.78),
                        borderRadius: BorderRadius.circular(34),
                        border: Border.all(
                          color: NoorApp.gold,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: NoorApp.gold.withOpacity(0.18),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Text(
                        'NOOR PRAYER & TASBEEH',
                        style: TextStyle(
                          color: NoorApp.gold,
                          fontSize: 31,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    left: 185,
                    top: 175,
                    child: Text(
                      'SMART RING',
                      style: TextStyle(
                        color: const Color(0xFFE7D9A1),
                        fontSize: 29,
                        letterSpacing: 9,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),

                  // --------------------------------------------------
                  // Actual Noor Smart Ring product
                  // --------------------------------------------------
                  Positioned(
                    left: 30,
                    bottom: 55,
                    width: 610,
                    height: 475,
                    child: Image.asset(
                      'assets/images/noor_smart_ring.png',
                      fit: BoxFit.contain,
                    ),
                  ),

                  // Product platform
                  Positioned(
                    left: 5,
                    bottom: 0,
                    width: 650,
                    height: 95,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(120),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            NoorApp.gold.withOpacity(0.30),
                            const Color(0xFF0A211A),
                          ],
                        ),
                        border: Border(
                          top: BorderSide(
                            color: NoorApp.gold.withOpacity(0.45),
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // --------------------------------------------------
                  // RIGHT CONTENT
                  // --------------------------------------------------
                  Positioned(
                    left: 635,
                    top: 125,
                    right: 70,
                    child: Text(
                      'Noor Smart Ring',
                      style: TextStyle(
                        color: const Color(0xFFFFE7A1),
                        fontSize: 70,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1.5,
                      ),
                    ),
                  ),

                  Positioned(
                    left: 640,
                    top: 225,
                    right: 105,
                    child: Text(
                      'A smarter way to stay connected\n'
                      'with your Dhikr & daily life.',
                      style: TextStyle(
                        color: const Color(0xFFF2F0E7),
                        fontSize: 34,
                        height: 1.35,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),

                  // --------------------------------------------------
                  // Feature icons
                  // --------------------------------------------------
                  Positioned(
                    left: 650,
                    top: 375,
                    child: _buildSmartRingFeature(
                      icon: Icons.blur_circular,
                      title: 'Dhikr\nCount',
                    ),
                  ),

                  Positioned(
                    left: 820,
                    top: 375,
                    child: _buildSmartRingFeature(
                      icon: Icons.directions_run,
                      title: 'Activity\nTracking',
                    ),
                  ),

                  Positioned(
                    left: 990,
                    top: 375,
                    child: _buildSmartRingFeature(
                      icon: Icons.favorite_outline,
                      title: 'Heart\nRate',
                    ),
                  ),

                  Positioned(
                    left: 1160,
                    top: 375,
                    child: _buildSmartRingFeature(
                      icon: Icons.nightlight_round,
                      title: 'Sleep\nTracking',
                    ),
                  ),

                  // --------------------------------------------------
                  // Faith in Every Step
                  // --------------------------------------------------
                  Positioned(
                    right: 18,
                    top: 535,
                    child: SizedBox(
                      width: 145,
                      child: Text(
                        'Faith\nin Every\nStep',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: NoorApp.gold,
                          fontSize: 29,
                          height: 1.15,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    right: 165,
                    top: 535,
                    height: 145,
                    child: Container(
                      width: 2,
                      color: NoorApp.gold.withOpacity(0.55),
                    ),
                  ),

                  Positioned(
                    right: 28,
                    top: 690,
                    child: Text(
                      'AND\nMORE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFFD9D5C7),
                        fontSize: 22,
                        height: 1.35,
                        letterSpacing: 5,
                      ),
                    ),
                  ),

                  // --------------------------------------------------
                  // SMART RING CTA
                  // --------------------------------------------------
                  Positioned(
                    left: 770,
                    right: 170,
                    bottom: 55,
                    height: 125,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Direct Instagram DM button
                        SizedBox(
                          width: double.infinity,
                          height: 72,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(38),
                              onTap: () async {
                                final uri = Uri.parse(
                                  'https://ig.me/m/noor_prayer_tasbeeh',
                                );

                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              },
                              child: Ink(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFFE6A0),
                                      Color(0xFFD9A93A),
                                      Color(0xFFFFE8A5),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(38),
                                  boxShadow: [
                                    BoxShadow(
                                      color: NoorApp.gold.withOpacity(0.40),
                                      blurRadius: 25,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'CHAT FOR MORE DETAILS',
                                      style: TextStyle(
                                        color: const Color(0xFF071812),
                                        fontSize: 27,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(width: 18),
                                    const Icon(
                                      Icons.chat_rounded,
                                      color: Color(0xFF071812),
                                      size: 32,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 3),

                        // Instagram profile button
                        SizedBox(
                          height: 48,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () async {
                                final uri = Uri.parse(
                                  'https://www.instagram.com/noor_prayer_tasbeeh/',
                                );

                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF08251D),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: NoorApp.gold.withOpacity(0.75),
                                    width: 1.2,
                                  ),
                                ),
                                child: const Text(
                                  'Instagram',
                                  style: TextStyle(
                                    color: Color(0xFFE8D889),
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSmartRingFeature({
    required IconData icon,
    required String title,
  }) {
    return SizedBox(
      width: 180,
      child: Column(
        children: [
          Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0B392C).withOpacity(0.88),
              border: Border.all(
                color: NoorApp.gold.withOpacity(0.65),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: NoorApp.gold.withOpacity(0.14),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              icon,
              color: NoorApp.gold,
              size: 55,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFF4F0E5),
              fontSize: 24,
              height: 1.1,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyDhikrContent() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _showAddDhikrDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Dhikr'),
              style: ElevatedButton.styleFrom(
                backgroundColor: NoorApp.gold,
                foregroundColor: NoorApp.darkGreen,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        if (_myDhikr.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 44,
              ),
              decoration: BoxDecoration(
                color: const Color(0x331B4D42),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0x33D4AF37),
                ),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.auto_awesome_outlined,
                    color: NoorApp.gold,
                    size: 34,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No personal Dhikr yet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Create your own Dhikr and target.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0x99FFFFFF),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: List.generate(
                    _myDhikr.length,
                    (index) {
                      final selected =
                          index == _selectedMyDhikrIndex;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedMyDhikrIndex = index;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0x33D4AF37)
                                  : const Color(0x221B4D42),
                              borderRadius:
                                  BorderRadius.circular(14),
                              border: Border.all(
                                color: selected
                                    ? const Color(0x66D4AF37)
                                    : const Color(0x22D4AF37),
                              ),
                            ),
                            child: Text(
                              _myDhikr[index]['name'] as String,
                              style: TextStyle(
                                color: selected
                                    ? NoorApp.gold
                                    : const Color(0xCCFFFFFF),
                                fontSize: 13,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _buildSelectedMyDhikrCounter(),
            ],
          ),
      ],
    );
  }

  Widget _buildSelectedMyDhikrCounter() {
    final dhikr = _myDhikr[_selectedMyDhikrIndex];
    final String name = dhikr['name'] as String;
    final int target = dhikr['target'] as int;
    final int count = dhikr['count'] as int;
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double counterSize = NoorResponsive.scale(
      screenWidth,
      min: 160,
      max: 200,
    );
    final double innerCounterSize = counterSize - 8;
    final double addButtonSize = NoorResponsive.scale(
      screenWidth,
      min: 52,
      max: 58,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
        decoration: BoxDecoration(
          color: const Color(0x331B4D42),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0x33D4AF37),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const SizedBox(height: 22),
            GestureDetector(
              onTap: () async {
                final current = dhikr['count'] as int;

                if (current >= target) {
                  return;
                }

                final newCount = current + 1;

                setState(() {
                  dhikr['count'] = newCount;
                });

                await _saveMyDhikr();

                if (newCount == target) {
                  await HapticFeedback.mediumImpact();

                  await _saveMyDhikrHistory(
                    name: name,
                    target: target,
                    count: newCount,
                    status: 'Completed',
                  );
                }
              },
              child: ClipOval(
                child: SizedBox(
                  width: counterSize,
                  height: counterSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: counterSize,
                        height: counterSize,
                        child: CircularProgressIndicator(
                          value: target == 0
                              ? 0
                              : count / target,
                          strokeWidth: 9,
                          backgroundColor:
                              const Color(0x331B4D42),
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(
                            NoorApp.gold,
                          ),
                        ),
                      ),
                      Container(
                        width: innerCounterSize,
                        height: innerCounterSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF0B241F),
                          border: Border.all(
                            color: const Color(0x44D4AF37),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x44000000),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Text(
                              '$count / $target',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              width: addButtonSize,
                              height: addButtonSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: NoorApp.gold,
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x55D4AF37),
                                    blurRadius: 14,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.add,
                                color: NoorApp.darkGreen,
                                size: 30,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _showEditTargetDialog,
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 18,
                  ),
                  label: const Text('EDIT TARGET'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NoorApp.gold,
                    side: const BorderSide(
                      color: Color(0x66D4AF37),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final current = dhikr['count'] as int;

                    if (current <= 0) {
                      return;
                    }

                    await _saveMyDhikrHistory(
                      name: name,
                      target: target,
                      count: current,
                      status: 'Reset',
                    );

                    setState(() {
                      dhikr['count'] = 0;
                    });

                    await _saveMyDhikr();
                  },
              icon: const Icon(
                Icons.restart_alt,
                size: 18,
              ),
              label: const Text('RESET'),
              style: OutlinedButton.styleFrom(
                foregroundColor: NoorApp.gold,
                side: const BorderSide(
                  color: Color(0x66D4AF37),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: const Color(0x221B4D42),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0x22D4AF37),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.flag_outlined,
                    color: NoorApp.gold,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Target',
                    style: TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$target',
                    style: const TextStyle(
                      color: NoorApp.gold,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: widget.onBackToHome,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0x221B4D42),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0x44D4AF37),
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: NoorApp.gold,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                const Text(
                  'Tasbeeh',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0x221B4D42),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0x33D4AF37),
                ),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedTab = 0;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedTab == 0
                              ? const Color(0x33D4AF37)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'After Prayer',
                          style: TextStyle(
                            color: _selectedTab == 0
                                ? NoorApp.gold
                                : const Color(0x99FFFFFF),
                            fontSize: 13,
                            fontWeight: _selectedTab == 0
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedTab = 1;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedTab == 1
                              ? const Color(0x33D4AF37)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'My Dhikr',
                          style: TextStyle(
                            color: _selectedTab == 1
                                ? NoorApp.gold
                                : const Color(0x99FFFFFF),
                            fontSize: 13,
                            fontWeight: _selectedTab == 1
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                children: [
                  const SizedBox(height: 18),

                      if (_selectedTab == 0)
                        Builder(
                          builder: (context) {
                            final double screenWidth =
                                MediaQuery.sizeOf(context).width;
                            final double counterSize = NoorResponsive.scale(
                              screenWidth,
                              min: 180,
                              max: 220,
                            );
                            final double innerCounterSize = counterSize - 48;
                            final double addButtonSize = NoorResponsive.scale(
                              screenWidth,
                              min: 52,
                              max: 58,
                            );

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 18),
                              child: Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.fromLTRB(20, 22, 20, 24),
                                decoration: BoxDecoration(
                                  color: const Color(0x331B4D42),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: const Color(0x33D4AF37),
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x33000000),
                                      blurRadius: 20,
                                      offset: Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      _dhikrNames[_currentDhikrIndex],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _dhikrArabic[_currentDhikrIndex],
                                      textDirection: ui.TextDirection.rtl,
                                      style: const TextStyle(
                                        color: NoorApp.gold,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 22),
                                    GestureDetector(
                                      onTap: _incrementDhikr,
                                      child: ClipOval(
                                        child: SizedBox(
                                          width: counterSize,
                                          height: counterSize,
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              SizedBox(
                                                width: counterSize,
                                                height: counterSize,
                                                child: CircularProgressIndicator(
                                                  value: _currentCount /
                                                      _dhikrTargets[
                                                          _currentDhikrIndex],
                                                  strokeWidth: 9,
                                                  backgroundColor:
                                                      const Color(0x331B4D42),
                                                  valueColor:
                                                      const AlwaysStoppedAnimation<
                                                          Color>(
                                                    NoorApp.gold,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                width: innerCounterSize,
                                                height: innerCounterSize,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color:
                                                      const Color(0xFF0B241F),
                                                  border: Border.all(
                                                    color:
                                                        const Color(0x44D4AF37),
                                                    width: 1,
                                                  ),
                                                  boxShadow: const [
                                                    BoxShadow(
                                                      color: Color(0x44000000),
                                                      blurRadius: 18,
                                                      spreadRadius: 2,
                                                    ),
                                                  ],
                                                ),
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      '$_currentCount / ${_dhikrTargets[_currentDhikrIndex]}',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 28,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 14),
                                                    Container(
                                                      width: addButtonSize,
                                                      height: addButtonSize,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: NoorApp.gold,
                                                        boxShadow: const [
                                                          BoxShadow(
                                                            color:
                                                                Color(0x55D4AF37),
                                                            blurRadius: 14,
                                                            spreadRadius: 1,
                                                          ),
                                                        ],
                                                      ),
                                                      child: const Icon(
                                                        Icons.add,
                                                        color:
                                                            NoorApp.darkGreen,
                                                        size: 30,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: List.generate(
                                        _dhikrTargets.length,
                                        (index) {
                                          final isCurrent =
                                              index == _currentDhikrIndex;
                                          final isCompleted =
                                              index < _currentDhikrIndex;

                                          return Container(
                                            margin:
                                                const EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                            width: isCurrent ? 28 : 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: isCurrent
                                                  ? NoorApp.gold
                                                  : isCompleted
                                                      ? const Color(
                                                          0x99D4AF37)
                                                      : const Color(
                                                          0x331B4D42),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color:
                                                    const Color(0x44D4AF37),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                      if (_selectedTab == 1) _buildMyDhikrContent(),

                      const SizedBox(height: 18),


                  const SizedBox(height: 18),
                  _buildSmartRingCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// HOME PAGE
// ============================================================

class NoorHomePage extends StatefulWidget {
  final ValueChanged<int> onNavigate;
  final PrayerTimes prayerTimes;
  final String locationText;

  const NoorHomePage({
    super.key,
    required this.onNavigate,
    required this.prayerTimes,
    required this.locationText,
  });

  @override
  State<NoorHomePage> createState() => _NoorHomePageState();
}

class _NoorHomePageState extends State<NoorHomePage> {
  PrayerTimes? _prayerTimes;
  String? _locationText;
  DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _prayerTimes = widget.prayerTimes;
    _locationText = widget.locationText;

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) return;
        setState(() {
          _now = DateTime.now();
        });
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double horizontalPadding =
            constraints.maxWidth < 500
                ? 16
                : constraints.maxWidth < 900
                    ? 28
                    : 40;

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF061A16),
                Color(0xFF081F1A),
                Color(0xFF04130F),
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                24,
                horizontalPadding,
                30,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 1000,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildDateCard(),
                      const SizedBox(height: 18),
                      _buildNextPrayerCard(),
                      const SizedBox(height: 28),
                      const Text(
                        'Quick Access',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildQuickGrid(
                        constraints.maxWidth,
                      ),
                      const SizedBox(height: 30),
                      const Center(
                        child: Text(
                          'Created by Safwan',
                          style: TextStyle(
                            color: Color(0x88D4AF37),
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            color: const Color(0x331B4D42),
            border: Border.all(
              color: const Color(0x55D4AF37),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1AD4AF37),
                blurRadius: 14,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Icon(
            Icons.nightlight_round,
            color: NoorApp.gold,
            size: 27,
          ),
        ),
        const SizedBox(width: 15),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'السلام عليكم',
                style: TextStyle(
                  color: Color(0xFFD9D9D9),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Noor Prayer & Tasbeeh',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'May Allah accept your good deeds',
                style: TextStyle(
                  color: Color(0x99D4AF37),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateCard() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat(
              'EEEE, d MMMM yyyy',
            ).format(_now),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat('hh:mm:ss a').format(_now),
            style: const TextStyle(
              color: NoorApp.gold,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Islamic Calendar',
            style: TextStyle(
              color: NoorApp.gold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: NoorApp.gold,
                size: 18,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _locationText ?? 'Loading location...',
                  style: const TextStyle(
                    color: Color(0xBBD9D9D9),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, String>? _getNextPrayer() {
    final prayerTimes = _prayerTimes;
    if (prayerTimes == null) return null;

    final prayers = <Map<String, String>>[
      {'name': 'Fajr', 'time': prayerTimes.fajr},
      {'name': 'Dhuhr', 'time': prayerTimes.dhuhr},
      {'name': 'Asr', 'time': prayerTimes.asr},
      {'name': 'Maghrib', 'time': prayerTimes.maghrib},
      {'name': 'Isha', 'time': prayerTimes.isha},
    ];

    for (final prayer in prayers) {
      final parts = prayer['time']!.split(':');
      if (parts.length < 2) continue;

      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);

      if (hour == null || minute == null) continue;

      final prayerTime = DateTime(
        _now.year,
        _now.month,
        _now.day,
        hour,
        minute,
      );

      if (_now.isBefore(prayerTime)) {
        final remaining = prayerTime.difference(_now);

        return {
          'name': prayer['name']!,
          'time': prayer['time']!,
          'countdown':
              '${remaining.inHours.toString().padLeft(2, '0')}:'
              '${remaining.inMinutes.remainder(60).toString().padLeft(2, '0')}:'
              '${remaining.inSeconds.remainder(60).toString().padLeft(2, '0')}',
        };
      }
    }

    return {
      'name': 'Fajr',
      'time': prayerTimes.fajr,
      'countdown': 'Tomorrow',
    };
  }

  Widget _buildNextPrayerCard() {
    final nextPrayer = _getNextPrayer();

    return GestureDetector(
      onTap: () => widget.onNavigate(1),
      child: _glassCard(
        child: Row(
          children: [
            Container(
              width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0x22D4AF37),
              border: Border.all(
                color: const Color(0x55D4AF37),
              ),
            ),
            child: const Icon(
              Icons.nightlight_outlined,
              color: NoorApp.gold,
              size: 27,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Next Prayer',
                  style: TextStyle(
                    color: Color(0xAAD9D9D9),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  nextPrayer?['name'] ?? 'Loading...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (nextPrayer != null &&
                    nextPrayer['countdown'] != 'Tomorrow') ...[
                  const SizedBox(height: 3),
                  Text(
                    'in ${nextPrayer['countdown']}',
                    style: const TextStyle(
                      color: NoorApp.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            nextPrayer?['time'] ?? '--:--',
            style: const TextStyle(
              color: NoorApp.gold,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickGrid(double width) {
    final int columns = width < 600 ? 2 : 3;

    final items = [
      const _QuickItem(
        icon: Icons.radio_button_checked,
        title: 'Tasbeeh',
        subtitle: 'Dhikr & Counter',
        navigationIndex: 2,
      ),
      const _QuickItem(
        icon: Icons.menu_book_outlined,
        title: 'Quran',
        subtitle: 'Read Quran',
        navigationIndex: 3,
      ),
      const _QuickItem(
        icon: Icons.explore_outlined,
        title: 'Qibla',
        subtitle: 'Find Qibla',
      ),
      const _QuickItem(
        icon: Icons.auto_stories_outlined,
        title: 'Duas',
        subtitle: 'Duas & Adhkar',
        navigationIndex: 4,
      ),
      const _QuickItem(
        icon: Icons.calendar_month_outlined,
        title: 'Calendar',
        subtitle: 'Hijri Calendar',
      ),
      const _QuickItem(
        icon: Icons.access_time_outlined,
        title: 'Prayer',
        subtitle: 'Prayer Times',
        navigationIndex: 1,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate:
          SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio:
            width < 600 ? 1.45 : 1.8,
      ),
      itemBuilder: (context, index) {
        return _QuickCard(
          item: items[index],
          onTap: items[index].navigationIndex == null
              ? null
              : () => widget.onNavigate(
                  items[index].navigationIndex!,
                ),
        );
      },
    );
  }

  Widget _glassCard({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0x331B4D42),
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0x33D4AF37),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _QuickItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final int? navigationIndex;

  const _QuickItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.navigationIndex,
  });
}

class _QuickCard extends StatelessWidget {
  final _QuickItem item;
  final VoidCallback? onTap;

  const _QuickCard({
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0x331B4D42),
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0x2ED4AF37),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0x22D4AF37),
              borderRadius:
                  BorderRadius.circular(13),
              border: Border.all(
                color: const Color(0x44D4AF37),
              ),
            ),
            child: Icon(
              item.icon,
              color: NoorApp.gold,
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0x99D9D9D9),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
}

// ============================================================
// HELPERS
// ============================================================

String formatPrayerTime(String time) {
  try {
    final parsedTime =
        DateFormat('HH:mm').parse(time);

    return DateFormat('h:mm a')
        .format(parsedTime);
  } catch (_) {
    return time;
  }
}
