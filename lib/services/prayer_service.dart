import 'dart:convert';
import 'package:http/http.dart' as http;

class PrayerTimes {
  final String fajr;
  final String sunrise;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;

  const PrayerTimes({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  factory PrayerTimes.fromJson(Map<String, dynamic> json) {
    final timings = json['timings'] as Map<String, dynamic>;

    return PrayerTimes(
      fajr: timings['Fajr']?.toString() ?? '--:--',
      sunrise: timings['Sunrise']?.toString() ?? '--:--',
      dhuhr: timings['Dhuhr']?.toString() ?? '--:--',
      asr: timings['Asr']?.toString() ?? '--:--',
      maghrib: timings['Maghrib']?.toString() ?? '--:--',
      isha: timings['Isha']?.toString() ?? '--:--',
    );
  }
}

class PrayerService {
  static const String _baseUrl =
      'https://api.aladhan.com/v1/timings';

  Future<PrayerTimes> getPrayerTimes({
    required double latitude,
    required double longitude,
    int method = 4,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'method': method.toString(),
      },
    );

    final response = await http.get(uri).timeout(
      const Duration(seconds: 15),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load prayer times: ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (data['code'] != 200) {
      throw Exception('Prayer API returned an error.');
    }

    return PrayerTimes.fromJson(
      data['data'] as Map<String, dynamic>,
    );
  }
}
