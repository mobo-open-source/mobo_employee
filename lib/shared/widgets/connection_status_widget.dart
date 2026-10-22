import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_employees/core/exceptions/odoo_error_mapper.dart';
import 'package:mobo_employees/core/services/connectivity_service.dart';

/// Full-page state shown in place of a screen's content, or its loading
/// shimmer, when loading that screen failed.
///
/// Pass the caught [error] to get a message that fits it: offline, server
/// unreachable, or the server's own error text. For connectivity errors it
/// retries by itself once the device is back online or the server accepts
/// connections again. Pull-to-refresh and the Retry button call [onRetry]
/// too.
class ConnectionStatusWidget extends StatefulWidget {
  /// The error the load failed with. When null, [serverUnreachable] picks
  /// between the "server unreachable" and the generic message.
  final Object? error;
  final bool serverUnreachable;
  final FutureOr<void> Function()? onRetry;
  final String? customMessage;

  const ConnectionStatusWidget({
    super.key,
    this.error,
    this.serverUnreachable = false,
    this.onRetry,
    this.customMessage,
  });

  @override
  State<ConnectionStatusWidget> createState() => _ConnectionStatusWidgetState();
}

class _ConnectionStatusWidgetState extends State<ConnectionStatusWidget> {
  /// How often the server is probed while it's unreachable, so the screen
  /// reloads on its own once the server is back.
  static const Duration _recoveryProbeInterval = Duration(seconds: 10);

  StreamSubscription<bool>? _internetSub;
  Timer? _recoveryProbe;
  bool _serverWasDown = false;
  bool _retrying = false;

  bool get _isConnectivityIssue {
    final error = widget.error;
    return error == null
        ? widget.serverUnreachable
        : ConnectivityService.isConnectivityError(error);
  }

  bool get _watchesForRecovery => _recoveryProbe != null;

  @override
  void initState() {
    super.initState();
    _syncRecoveryWatch();
  }

  @override
  void didUpdateWidget(covariant ConnectionStatusWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncRecoveryWatch();
  }

  @override
  void dispose() {
    _stopRecoveryWatch();
    super.dispose();
  }

  void _syncRecoveryWatch() {
    final shouldWatch = widget.onRetry != null && _isConnectivityIssue;
    if (shouldWatch && !_watchesForRecovery) {
      _internetSub = ConnectivityService.instance.onInternetChanged.listen((
        online,
      ) {
        if (online) _retry();
      });
      _recoveryProbe = Timer.periodic(
        _recoveryProbeInterval,
        (_) => _probeServer(),
      );
      _probeServer();
    } else if (!shouldWatch && _watchesForRecovery) {
      _stopRecoveryWatch();
    }
  }

  void _stopRecoveryWatch() {
    _internetSub?.cancel();
    _internetSub = null;
    _recoveryProbe?.cancel();
    _recoveryProbe = null;
  }

  /// Retries only when the server goes from refusing connections to
  /// accepting them. A server that accepts connections but still fails
  /// requests (e.g. a proxy answering 502 while Odoo restarts) would
  /// otherwise be retried, and the shimmer flashed, every interval.
  Future<void> _probeServer() async {
    final reachable = await ConnectivityService.instance
        .isCurrentServerReachable();
    if (!mounted) return;
    if (!reachable) {
      _serverWasDown = true;
    } else if (_serverWasDown) {
      _serverWasDown = false;
      _retry();
    }
  }

  Future<void> _retry() async {
    final onRetry = widget.onRetry;
    if (onRetry == null || _retrying) return;
    setState(() => _retrying = true);
    try {
      await onRetry();
    } catch (_) {
      /// The screen's provider records the failure and rebuilds this
      /// widget with the new error.
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;
    final content = _content();

    final body = Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: isDark ? Colors.red[900]!.withValues(alpha: 0.2) : Colors.red[50],
              shape: BoxShape.circle,
            ),
            child: HugeIcon(
              icon: content.icon,
              size: 40,
              color: isDark ? Colors.red[300] : Colors.red[700],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            content.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.customMessage ?? content.message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              height: 1.5,
            ),
          ),
          if (widget.onRetry != null) ...[
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _retrying ? null : _retry,
              icon: _retrying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.refresh, size: 20),
              label: Text(_retrying ? 'Retrying…' : 'Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: primary.withValues(alpha: 0.7),
                disabledForegroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
            if (_watchesForRecovery) ...[
              const SizedBox(height: 16),
              Text(
                "We'll reload automatically once the connection is back.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ],
        ],
      ),
    );

    /// Scrollable even when the content fits, so pull-to-refresh works the
    /// same as on the screen it replaces.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedHeight) return Center(child: body);
        final scrollable = SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: body),
          ),
        );
        if (widget.onRetry == null) return scrollable;
        return RefreshIndicator(
          onRefresh: _retry,
          color: primary,
          child: scrollable,
        );
      },
    );
  }

  _StatusContent _content() {
    final error = widget.error;
    if (error is NoInternetException) {
      return const _StatusContent(
        icon: HugeIcons.strokeRoundedWifiDisconnected02,
        title: "You're Offline",
        message:
            'Check your Wi‑Fi or mobile data connection and try again.',
      );
    }
    if (_isConnectivityIssue) {
      return const _StatusContent(
        icon: HugeIcons.strokeRoundedCloudServer,
        title: 'Server Unreachable',
        message:
            "We couldn't connect to the server. It may be offline or "
            'restarting. Please check your connection and try again.',
      );
    }
    if (error != null) {
      return _StatusContent(
        icon: HugeIcons.strokeRoundedAlert02,
        title: 'Something Went Wrong',
        message: OdooErrorMapper.serverMessage(
          error,
          fallback: "We couldn't load this page. Please try again.",
        ),
      );
    }
    return const _StatusContent(
      icon: HugeIcons.strokeRoundedAlert02,
      title: 'Connection Error',
      message: 'Something went wrong.\nPlease try again.',
    );
  }
}

class _StatusContent {
  final List<List<dynamic>> icon;
  final String title;
  final String message;

  const _StatusContent({
    required this.icon,
    required this.title,
    required this.message,
  });
}
