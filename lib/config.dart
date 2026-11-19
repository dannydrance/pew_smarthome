/// App-wide settings.
class AppConfig {
  AppConfig._();

  static const String appName = 'PEW Smart Home';
  static const String company = 'Physician Electronics Workshop';

  /// Live server. Can be changed on the sign-in screen (Server settings),
  /// for example to http://192.168.1.10:8000 while testing on a local network.
  static const String defaultServer = 'https://homeauto-ab04.onrender.com';

  static const String apiPath = '/api/mobile/v1';

  static const String supportEmail = 'kamalizaliliane065@gmail.com';
  static const String supportPhone = '+250723364097';
  static const String supportPhoneDisplay = '+250 723 364 097';

  /// Render's free plan sleeps; the first request can take ~50 s to wake it.
  static const Duration requestTimeout = Duration(seconds: 60);
  static const int defaultPollSeconds = 5;
}
