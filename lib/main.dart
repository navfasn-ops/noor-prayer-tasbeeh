import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';

import 'services/location_service.dart';
import 'services/prayer_service.dart';
import 'services/iqamah_service.dart';
import 'screens/splash_screen.dart';

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
  const NoorShell({super.key});

  @override
  State<NoorShell> createState() => _NoorShellState();
}

class _NoorShellState extends State<NoorShell> {
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
      ),
      PrayerPage(
        settingsNotifier: _settingsNotifier,
      ),
      const SectionPage(
        icon: Icons.radio_button_checked,
        title: 'Tasbeeh',
        subtitle: 'Personal & After Prayer Dhikr',
      ),
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
// HOME PAGE
// ============================================================

class NoorHomePage extends StatefulWidget {
  final ValueChanged<int> onNavigate;

  const NoorHomePage({
    super.key,
    required this.onNavigate,
  });

  @override
  State<NoorHomePage> createState() => _NoorHomePageState();
}

class _NoorHomePageState extends State<NoorHomePage> {
  PrayerTimes? _prayerTimes;
  String? _locationText;
  String? _errorMessage;
  bool _isLoading = true;
  DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadHomeData();

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

  Future<void> _loadHomeData() async {
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

      String locationName = 'Unknown location';

      try {
        final geocoding = Geocoding();

        final placemarks =
            await geocoding.placemarkFromCoordinates(
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

      if (!mounted) return;

      setState(() {
        _prayerTimes = prayerTimes;
        _locationText = locationName;
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
                      if (_isLoading)
                        _buildHomeLoadingCard()
                      else if (_errorMessage != null)
                        _buildHomeErrorCard()
                      else ...[
                        _buildDateCard(),
                        const SizedBox(height: 18),
                        _buildNextPrayerCard(),
                      ],
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

  Widget _buildHomeLoadingCard() {
    return _glassCard(
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: NoorApp.gold,
                strokeWidth: 2.5,
              ),
            ),
            SizedBox(width: 14),
            Text(
              'Loading prayer times...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeErrorCard() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Unable to load prayer times',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _errorMessage ?? 'Please try again.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xAAD9D9D9),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _loadHomeData,
            icon: const Icon(
              Icons.refresh,
              color: NoorApp.gold,
            ),
            label: const Text(
              'Retry',
              style: TextStyle(
                color: NoorApp.gold,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
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
                      color: Color(0xAAD9D9D9),
                      fontSize: 12,
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