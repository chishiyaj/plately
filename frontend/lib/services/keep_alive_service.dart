import 'dart:async';
import 'api_service.dart';

/// Keeps the Railway/Render backend awake by pinging /api/health every 9 minutes.
/// Free-tier services sleep after 15 min of inactivity -- this prevents cold starts
/// without needing an external service like UptimeRobot.
///
/// Call KeepAliveService.start() once in main() after Firebase init.
/// The timer fires while the app is in the foreground.
class KeepAliveService {
  static Timer? _timer;
  static const _interval = Duration(minutes: 9);

  static void start() {
    _timer?.cancel();
    ApiService.ping();
    _timer = Timer.periodic(_interval, (_) => ApiService.ping());
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
