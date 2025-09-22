import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../providers/location_provider.dart';
import 'dialogs.dart';

/// Widget para gerenciar o fluxo de permissões de localização
class LocationPermissionHandler extends ConsumerStatefulWidget {
  final Widget child;
  final bool autoRequest;
  final VoidCallback? onPermissionGranted;
  final VoidCallback? onPermissionDenied;
  final bool showDialog;

  const LocationPermissionHandler({
    super.key,
    required this.child,
    this.autoRequest = false,
    this.onPermissionGranted,
    this.onPermissionDenied,
    this.showDialog = true,
  });

  @override
  ConsumerState<LocationPermissionHandler> createState() => _LocationPermissionHandlerState();
}

class _LocationPermissionHandlerState extends ConsumerState<LocationPermissionHandler> {
  bool _hasCheckedPermissions = false;
  bool _isRequestingPermission = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoRequest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndRequestPermissions();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasCheckedPermissions && widget.autoRequest) {
      _checkAndRequestPermissions();
    }
  }

  Future<void> _checkAndRequestPermissions() async {
    if (_hasCheckedPermissions || _isRequestingPermission) return;
    
    setState(() {
      _hasCheckedPermissions = true;
      _isRequestingPermission = true;
    });

    try {
      final locationNotifier = ref.read(locationProvider.notifier);
      final locationState = ref.read(locationProvider);

      // Verifica se já tem todas as permissões
      if (locationState.hasAllPermissions) {
        widget.onPermissionGranted?.call();
        return;
      }

      // Verifica o status atual da permissão
      final currentStatus = await Permission.location.status;
      
      if (currentStatus == PermissionStatus.granted) {
        // Já tem permissão, atualiza o estado
        await locationNotifier.getCurrentLocation();
        widget.onPermissionGranted?.call();
        return;
      }

      if (currentStatus == PermissionStatus.permanentlyDenied) {
        // Permissão negada permanentemente, mostra dialog para configurações
        if (widget.showDialog && mounted) {
          _showPermissionDeniedDialog();
        } else {
          widget.onPermissionDenied?.call();
        }
        return;
      }

      // Solicita permissão
      final success = await locationNotifier.requestLocationPermission();
      
      if (success) {
        widget.onPermissionGranted?.call();
      } else {
        if (widget.showDialog && mounted) {
          _showPermissionDeniedDialog();
        } else {
          widget.onPermissionDenied?.call();
        }
      }
    } catch (e) {
      debugPrint('Erro ao verificar permissões: $e');
      widget.onPermissionDenied?.call();
    } finally {
      if (mounted) {
        setState(() {
          _isRequestingPermission = false;
        });
      }
    }
  }

  void _showPermissionDeniedDialog() {
    LocationPermissionDialog.show(
      context,
      onOpenSettings: () async {
        final opened = await openAppSettings();
        if (!opened && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não foi possível abrir as configurações'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      onCancel: () {
        widget.onPermissionDenied?.call();
      },
    );
  }

  /// Método público para solicitar permissões manualmente
  Future<void> requestPermissions() async {
    await _checkAndRequestPermissions();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Widget para mostrar status de permissão de localização
class LocationPermissionStatus extends ConsumerWidget {
  final bool showIcon;
  final TextStyle? textStyle;
  final VoidCallback? onTap;

  const LocationPermissionStatus({
    super.key,
    this.showIcon = true,
    this.textStyle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationState = ref.watch(locationProvider);
    
    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (locationState.isLoading) {
      statusText = 'Verificando localização...';
      statusColor = AppColors.textSecondary;
      statusIcon = Icons.location_searching;
    } else if (locationState.hasAllPermissions && locationState.currentLocation != null) {
      statusText = 'Localização ativa';
      statusColor = AppColors.success;
      statusIcon = Icons.location_on;
    } else if (locationState.permissionStatus == PermissionStatus.permanentlyDenied) {
      statusText = 'Permissão negada';
      statusColor = AppColors.error;
      statusIcon = Icons.location_disabled;
    } else {
      statusText = 'Localização desabilitada';
      statusColor = AppColors.warning;
      statusIcon = Icons.location_off;
    }

    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(
              statusIcon,
              size: 16,
              color: statusColor,
            ),
            SizedBox(width: 4),
          ],
          Text(
            statusText,
            style: textStyle ?? AppTextStyles.bodySmall.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget de botão para solicitar permissões de localização
class LocationPermissionButton extends ConsumerWidget {
  final String? text;
  final VoidCallback? onSuccess;
  final VoidCallback? onError;
  final bool showStatus;

  const LocationPermissionButton({
    super.key,
    this.text,
    this.onSuccess,
    this.onError,
    this.showStatus = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationState = ref.watch(locationProvider);
    
    if (locationState.hasAllPermissions && showStatus) {
      return const LocationPermissionStatus();
    }

    return ElevatedButton.icon(
      onPressed: locationState.isLoading ? null : () async {
        try {
          final success = await ref.read(locationProvider.notifier).requestLocationPermission();
          if (success) {
            onSuccess?.call();
          } else {
            onError?.call();
          }
        } catch (e) {
          onError?.call();
        }
      },
      icon: locationState.isLoading 
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Icon(Icons.location_on),
      label: Text(text ?? 'Ativar Localização'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}
