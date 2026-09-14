import 'package:shared_preferences/shared_preferences.dart';

class IqamahSettings {
  final int fajrMinutes;
  final int dhuhrMinutes;
  final int asrMinutes;
  final int maghribMinutes;
  final int ishaMinutes;

  const IqamahSettings({
    this.fajrMinutes = 30,
    this.dhuhrMinutes = 20,
    this.asrMinutes = 15,
    this.maghribMinutes = 10,
    this.ishaMinutes = 20,
  });

  int delayFor(String prayerName) {
    switch (prayerName.toLowerCase()) {
      case 'fajr':
        return fajrMinutes;
      case 'dhuhr':
        return dhuhrMinutes;
      case 'asr':
        return asrMinutes;
      case 'maghrib':
        return maghribMinutes;
      case 'isha':
        return ishaMinutes;
      default:
        return 0;
    }
  }
}

class IqamahStorage {
  static const String _fajrKey = 'iqamah_fajr';
  static const String _dhuhrKey = 'iqamah_dhuhr';
  static const String _asrKey = 'iqamah_asr';
  static const String _maghribKey = 'iqamah_maghrib';
  static const String _ishaKey = 'iqamah_isha';

  Future<IqamahSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    return IqamahSettings(
      fajrMinutes: prefs.getInt(_fajrKey) ?? 30,
      dhuhrMinutes: prefs.getInt(_dhuhrKey) ?? 20,
      asrMinutes: prefs.getInt(_asrKey) ?? 15,
      maghribMinutes: prefs.getInt(_maghribKey) ?? 10,
      ishaMinutes: prefs.getInt(_ishaKey) ?? 20,
    );
  }

  Future<void> saveSettings(IqamahSettings settings) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt(_fajrKey, settings.fajrMinutes);
    await prefs.setInt(_dhuhrKey, settings.dhuhrMinutes);
    await prefs.setInt(_asrKey, settings.asrMinutes);
    await prefs.setInt(_maghribKey, settings.maghribMinutes);
    await prefs.setInt(_ishaKey, settings.ishaMinutes);
  }
}

class IqamahState {
  final String prayerName;
  final DateTime adhanTime;
  final DateTime iqamahTime;

  const IqamahState({
    required this.prayerName,
    required this.adhanTime,
    required this.iqamahTime,
  });

  bool get isAdhanNowOrPassed {
    return !DateTime.now().isBefore(adhanTime);
  }

  bool get isIqamahNowOrPassed {
    return !DateTime.now().isBefore(iqamahTime);
  }

  Duration get remainingToIqamah {
    final remaining = iqamahTime.difference(DateTime.now());

    if (remaining.isNegative) {
      return Duration.zero;
    }

    return remaining;
  }
}

class IqamahService {
  final IqamahSettings settings;

  const IqamahService({
    this.settings = const IqamahSettings(),
  });

  IqamahState createState({
    required String prayerName,
    required String prayerTime,
    DateTime? date,
  }) {
    final baseDate = date ?? DateTime.now();

    final parts = prayerTime.split(':');

    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    final adhanTime = DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day,
      hour,
      minute,
    );

    final delay = settings.delayFor(prayerName);

    final iqamahTime = adhanTime.add(
      Duration(minutes: delay),
    );

    return IqamahState(
      prayerName: prayerName,
      adhanTime: adhanTime,
      iqamahTime: iqamahTime,
    );
  }
}