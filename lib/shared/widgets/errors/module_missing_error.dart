import 'package:flutter/material.dart';

/// Widget to display module/app missing errors prominently
class ModuleMissingError extends StatelessWidget {
  final String errorMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onContactAdmin;

  const ModuleMissingError({
    super.key,
    required this.errorMessage,
    this.onRetry,
    this.onContactAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMissingModule =
        errorMessage.contains('Missing Module') ||
        errorMessage.contains('Required App') ||
        errorMessage.contains('not installed');

    final semanticColor = isMissingModule ? Colors.orange : Colors.red;
    final semanticShade = isMissingModule
        ? Colors.orange.shade700
        : Colors.red.shade700;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: semanticColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isMissingModule
                          ? Icons.extension_off_rounded
                          : Icons.error_outline_rounded,
                      size: 60,
                      color: semanticShade,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),

            Text(
              isMissingModule ? 'Module Not Installed' : 'Error',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: semanticColor.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                errorMessage,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                if (onRetry != null)
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      side: BorderSide(color: theme.colorScheme.primary),
                    ),
                  ),
                if (onContactAdmin != null)
                  ElevatedButton.icon(
                    onPressed: onContactAdmin,
                    icon: const Icon(Icons.support_agent),
                    label: const Text('Contact Admin'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      backgroundColor: semanticShade,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),

            if (isMissingModule) ...[
              const SizedBox(height: 24),
              Text(
                'Your administrator needs to install the required Odoo app/module on the server.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
