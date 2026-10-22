import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

/// Centralized connectivity service to check device network status and real internet access.
class ConnectivityService {
  /// How long a reachability probe waits for the server to accept a TCP
  /// connection before treating it as unreachable.
  static const Duration _serverProbeTimeout = Duration(seconds: 5);

  /// True when [error] means the request never reached the server or the
  /// server could not answer it: device offline, DNS failure, connection
  /// refused/reset/timed out, or a proxy's HTML error page (502/503/504)
  /// served while Odoo itself is down. False for errors Odoo returned,
  /// such as access rights or validation errors.
  ///
  /// Also matches the raw errors thrown by calls that bypass
  /// `OdooSessionManager.callWithSession`.
  static bool isConnectivityError(Object error) {
    if (error is NoInternetException ||
        error is ServerUnreachableException ||
        error is SocketException ||
        error is HttpException ||
        error is TimeoutException ||
        error is http.ClientException) {
      return true;
    }
    if (error is FormatException) {
      final message = error.message.toLowerCase();
      final source = error.source?.toString().toLowerCase() ?? '';
      return _looksLikeHtml(message) || _looksLikeHtml(source);
    }
    /// Errors re-wrapped as `Exception('Failed to …: $e')` keep only the
    /// original's text.
    final s = error.toString().toLowerCase();
    return s.contains('nointernetexception') ||
        s.contains('serverunreachableexception') ||
        s.contains('socketexception') ||
        s.contains('clientexception') ||
        s.contains('connection refused') ||
        s.contains('connection reset') ||
        s.contains('connection closed') ||
        s.contains('connection timed out') ||
        s.contains('network is unreachable') ||
        s.contains('failed host lookup');
  }

  static bool _looksLikeHtml(String s) =>
      s.contains('<html') || s.contains('<!doctype');
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _internetController =
      StreamController<bool>.broadcast();
  final StreamController<bool> _serverController =
      StreamController<bool>.broadcast();
  bool _lastInternetReachable = false;
  bool _lastServerReachable = true; /// default optimistic until checked
  String? _currentServerUrl;

  /// Listen to real internet reachability changes (not just network type)
  Stream<bool> get onInternetChanged => _internetController.stream;

  /// Listen to current server reachability changes. Emits true when reachable, false otherwise.
  Stream<bool> get onServerChanged => _serverController.stream;

  /// Start monitoring connectivity (idempotent)
  void startMonitoring() {
    /// Initial probe
    _probeInternet();
    _probeServer();
    _connectivity.onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) async {
      await _probeInternet();
      await _probeServer();
    });
  }

  Future<void> _probeInternet() async {
    final reachable = await hasInternetAccess();
    if (reachable != _lastInternetReachable) {
      _lastInternetReachable = reachable;
      _internetController.add(reachable);
    }
  }

  Future<void> _probeServer() async {
    final url = _currentServerUrl;
    if (url == null) return;
    /// Only meaningful to probe server if we have internet
    if (!_lastInternetReachable) {
      /// When internet is down, we implicitly consider server unreachable, but we don't spam stream unless state changes
      if (_lastServerReachable != false) {
        _lastServerReachable = false;
        _serverController.add(false);
      }
      return;
    }
    try {
      await ensureServerReachable(url);
      if (_lastServerReachable != true) {
        _lastServerReachable = true;
        _serverController.add(true);
      }
    } catch (_) {
      if (_lastServerReachable != false) {
        _lastServerReachable = false;
        _serverController.add(false);
      }
    }
  }

  /// Returns true if device has any network (wifi/mobile/ethernet)
  Future<bool> isNetworkAvailable() async {
    final List<ConnectivityResult> results = await _connectivity
        .checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// DNS probe to confirm real internet access. Optionally specify host for enterprise networks.
  Future<bool> hasInternetAccess({String host = 'example.com'}) async {
    try {
      final result = await InternetAddress.lookup(
        host,
      ).timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    }
  }

  /// Ensures internet is reachable, else throws [NoInternetException].
  Future<void> ensureInternetOrThrow() async {
    final net = await isNetworkAvailable();
    if (!net) {
      throw NoInternetException(
        'No network connection. Please check Wi‑Fi or mobile data.',
      );
    }
    final online = await hasInternetAccess();
    if (!online) {
      throw NoInternetException(
        'Connected to a network but no internet access.',
      );
    }
  }

  /// Ensures the specified server accepts connections.
  ///
  /// Opens (and immediately closes) a TCP connection to the server's port.
  /// A DNS lookup alone is not enough: it always succeeds for a raw IP
  /// address such as `http://10.0.20.120:8020`, even when nothing is
  /// listening there. Falls back to a DNS lookup only when the URL has no
  /// http/https scheme, since the port is unknown then.
  Future<void> ensureServerReachable(String serverUrl) async {
    try {
      final uri = Uri.parse(serverUrl);
      final hasScheme = uri.scheme == 'http' || uri.scheme == 'https';
      if (hasScheme && uri.host.isNotEmpty) {
        final socket = await Socket.connect(
          uri.host,
          uri.port,
          timeout: _serverProbeTimeout,
        );
        socket.destroy();
        return;
      }
      final host = uri.host.isNotEmpty ? uri.host : serverUrl;
      final res = await InternetAddress.lookup(
        host,
      ).timeout(const Duration(seconds: 3));
      if (res.isEmpty) {
        throw ServerUnreachableException('Unable to reach server host: $host');
      }
    } on Exception {
      throw ServerUnreachableException(
        'Unable to reach server. Please verify the URL and network.',
      );
    }
  }

  /// Probes the current server (see [ensureServerReachable]) and publishes
  /// the result on [onServerChanged]. Returns true when no server is set.
  Future<bool> isCurrentServerReachable() async {
    final url = _currentServerUrl;
    if (url == null) return true;
    try {
      await ensureServerReachable(url);
      reportServerReachable(true);
      return true;
    } on ServerUnreachableException {
      reportServerReachable(false);
      return false;
    }
  }

  /// Records the server's reachability as observed by a real request, so
  /// [onServerChanged] and [lastKnownServerReachable] follow actual RPC
  /// outcomes and not only the probes run on network changes.
  void reportServerReachable(bool reachable) {
    if (_lastServerReachable == reachable) return;
    _lastServerReachable = reachable;
    _serverController.add(reachable);
  }

  /// Converts a connectivity failure (see [isConnectivityError]) into a
  /// [NoInternetException] when the device has no network at all, otherwise
  /// a [ServerUnreachableException], and records the server as unreachable.
  ///
  /// Uses the device's network state rather than [hasInternetAccess]: an
  /// on-premise Odoo server can be reachable without public internet, so a
  /// failed public DNS probe doesn't mean the device is offline.
  Future<Exception> toConnectivityException(Object error) async {
    if (error is NoInternetException) return error;
    if (error is ServerUnreachableException) {
      reportServerReachable(false);
      return error;
    }
    if (!await isNetworkAvailable()) {
      return NoInternetException(
        'No network connection. Please check Wi‑Fi or mobile data.',
      );
    }
    reportServerReachable(false);
    return ServerUnreachableException(
      'Unable to connect to the server. It may be offline or restarting.',
    );
  }

  /// Set current server URL to be monitored for reachability. Pass null to clear.
  void setCurrentServerUrl(String? serverUrl) {
    _currentServerUrl = serverUrl;
    /// Re-probe when server changes
    _probeServer();
  }

  /// Returns last known server reachability state. If no server set, returns true.
  bool get lastKnownServerReachable =>
      _currentServerUrl == null ? true : _lastServerReachable;
}

class NoInternetException implements Exception {
  final String message;
  NoInternetException(this.message);
  @override
  String toString() => 'NoInternetException: $message';
}

class ServerUnreachableException implements Exception {
  final String message;
  ServerUnreachableException(this.message);
  @override
  String toString() => 'ServerUnreachableException: $message';
}
