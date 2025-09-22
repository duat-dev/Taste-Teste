import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/navigation_helper.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/services/ui/interaction_service.dart';
import '../../data/models/restaurant_model.dart';
import '../../data/models/review_model.dart';
import '../../data/repositories/review_repository.dart';
import '../../services/analytics_service.dart';
import '../providers/favorites_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_button.dart';

/// Botão de favorito aprimorado para páginas de detalhes
class FavoriteButtonEnhanced extends ConsumerStatefulWidget {
  final RestaurantModel restaurant;
  final Function(bool)? onFavoriteChanged;
  final bool showLabel;
  final bool showQuickActions;
  final bool showFeedback;

  const FavoriteButtonEnhanced({
    super.key,
    required this.restaurant,
    this.onFavoriteChanged,
    this.showLabel = true,
    this.showQuickActions = true,
    this.showFeedback = true,
  });

  @override
  ConsumerState<FavoriteButtonEnhanced> createState() => _FavoriteButtonEnhancedState();
}

class _FavoriteButtonEnhancedState extends ConsumerState<FavoriteButtonEnhanced>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  bool _isLoading = false;
  bool _showQuickActions = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFavorite = ref.watch(isFavoriteProvider(widget.restaurant.id));
    
    return AnimatedBuilder(
      animation: Listenable.merge([_scaleAnimation, _pulseAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value * _pulseAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                onTap: _isLoading ? null : _toggleFavorite,
                onLongPress: widget.showQuickActions ? _showQuickActionsMenu : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingMedium,
                    vertical: AppDimensions.paddingSmall,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isLoading)
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isFavorite ? AppColors.error : AppColors.primary,
                            ),
                          ),
                        )
                      else
                        Icon(
                          isFavorite ? AppIcons.heartFilled : AppIcons.heart,
                          size: 24,
                          color: isFavorite ? AppColors.error : AppColors.textLight,
                        ),
                      
                      if (widget.showLabel) ...[
                        SizedBox(width: 8),
                        Text(
                          isFavorite ? 'Favoritado' : 'Favoritar',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isFavorite ? AppColors.error : AppColors.textDark,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      
                      if (widget.showQuickActions && isFavorite) ...[
                        SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: 16,
                          color: AppColors.textLight,
                        ),
                      ],
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

  Future<void> _toggleFavorite() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      _animationController.forward().then((_) {
        _animationController.reverse();
      });
      
      InteractionService.mediumHaptic();
      
      final favoritesNotifier = ref.read(favoritesProvider.notifier);
      final success = await favoritesNotifier.toggleFavorite(widget.restaurant);
      
      if (success) {
        final isFavorite = ref.read(isFavoriteProvider(widget.restaurant.id));
        
        // Animação de pulso para favoritos
        if (isFavorite) {
          _pulseController.repeat(reverse: true);
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              _pulseController.stop();
              _pulseController.reset();
            }
          });
        }
        
        AnalyticsService.instance.trackEvent(
          'favorite_action',
          parameters: {
            'restaurant_id': widget.restaurant.id,
            'restaurant_name': widget.restaurant.name,
            'action': isFavorite ? 'add' : 'remove',
          },
        );

        if (widget.onFavoriteChanged != null) {
          widget.onFavoriteChanged!(isFavorite);
        }
        
        if (widget.showFeedback && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isFavorite 
                          ? '${widget.restaurant.name} adicionado aos favoritos'
                          : '${widget.restaurant.name} removido dos favoritos',
                    ),
                  ),
                ],
              ),
              backgroundColor: isFavorite ? AppColors.success : AppColors.warning,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(AppDimensions.paddingMedium),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
              ),
              action: isFavorite ? SnackBarAction(
                label: 'Ver Favoritos',
                textColor: Colors.white,
                onPressed: () {
                  // Navegar para página de favoritos
                },
              ) : null,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erro ao alterar favorito: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 8),
                const Expanded(
                  child: Text('Erro ao alterar favorito. Tente novamente.'),
                ),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(AppDimensions.paddingMedium),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showQuickActionsMenu() {
    InteractionService.lightHaptic();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimensions.radiusLarge),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textLight.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ações Rápidas',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    widget.restaurant.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textLight,
                    ),
                  ),
                  SizedBox(height: 24),
                  
                  // Ações
                  _buildQuickAction(
                    icon: Icons.star_rate,
                    title: 'Avaliar Restaurante',
                    subtitle: 'Deixe sua avaliação',
                    onTap: () {
                      NavigationHelper.safeGoBack(context);
                      // Implementar navegação para avaliação
                    },
                  ),
                  
                  _buildQuickAction(
                    icon: Icons.share,
                    title: 'Compartilhar',
                    subtitle: 'Compartilhe com amigos',
                    onTap: () {
                      NavigationHelper.safeGoBack(context);
                      // Implementar compartilhamento
                    },
                  ),
                  
                  _buildQuickAction(
                    icon: Icons.list_alt,
                    title: 'Adicionar à Lista',
                    subtitle: 'Organize seus favoritos',
                    onTap: () {
                      NavigationHelper.safeGoBack(context);
                      // Implementar adição à lista
                    },
                  ),
                  
                  _buildQuickAction(
                    icon: Icons.notifications,
                    title: 'Notificações',
                    subtitle: 'Receba atualizações',
                    onTap: () {
                      NavigationHelper.safeGoBack(context);
                      // Implementar configuração de notificações
                    },
                  ),
                  
                  SizedBox(height: 16),
                  
                  CustomButton(
                    text: 'Fechar',
                    onPressed: () => NavigationHelper.safeGoBack(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingMedium),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.textLight,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão de favorito reutilizável
class FavoriteButton extends ConsumerStatefulWidget {
  final RestaurantModel restaurant;
  final Function(bool)? onFavoriteChanged;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? backgroundColor;
  final bool showBackground;
  final bool showFeedback;
  final EdgeInsets? padding;

  const FavoriteButton({
    super.key,
    required this.restaurant,
    this.onFavoriteChanged,
    this.size = 24.0,
    this.activeColor,
    this.inactiveColor,
    this.backgroundColor,
    this.showBackground = true,
    this.showFeedback = true,
    this.padding,
  });

  @override
  ConsumerState<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends ConsumerState<FavoriteButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFavorite = ref.watch(isFavoriteProvider(widget.restaurant.id));
    final activeColor = widget.activeColor ?? AppColors.error;
    final inactiveColor = widget.inactiveColor ?? AppColors.textLight;
    final backgroundColor = widget.backgroundColor ?? AppColors.surface.withOpacity(0.9);

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTap: _isLoading ? null : _toggleFavorite,
            child: Container(
              padding: widget.padding ?? EdgeInsets.all(
                widget.showBackground ? AppDimensions.paddingSmall : 0,
              ),
              decoration: widget.showBackground
                  ? BoxDecoration(
                      color: backgroundColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadow.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    )
                  : null,
              child: _isLoading
                  ? SizedBox(
                      width: widget.size,
                      height: widget.size,
                      child: CircularProgressIndicator(
                        strokeWidth: widget.size < 20 ? 1.5 : 2.0,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isFavorite ? activeColor : inactiveColor,
                        ),
                      ),
                    )
                  : Icon(
                      isFavorite ? AppIcons.heartFilled : AppIcons.heart,
                      size: widget.size,
                      color: isFavorite ? activeColor : inactiveColor,
                    ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleFavorite() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Animação de feedback
      _animationController.forward().then((_) {
        _animationController.reverse();
      });
      
      InteractionService.mediumHaptic();
      
      final favoritesNotifier = ref.read(favoritesProvider.notifier);
      final success = await favoritesNotifier.toggleFavorite(widget.restaurant);
      
      if (success) {
        final isFavorite = ref.read(isFavoriteProvider(widget.restaurant.id));
        
        // Analytics: rastrear ação de favoritar
        AnalyticsService.instance.trackEvent(
          'favorite_action',
          parameters: {
            'restaurant_id': widget.restaurant.id,
            'action': isFavorite ? 'add' : 'remove',
            'source': 'favorite_button',
          },
        );

        if (widget.onFavoriteChanged != null) {
          widget.onFavoriteChanged!(isFavorite);
        }
        
        // Mostrar feedback se habilitado
        if (widget.showFeedback && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isFavorite 
                    ? '${widget.restaurant.name} adicionado aos favoritos'
                    : '${widget.restaurant.name} removido dos favoritos',
              ),
              backgroundColor: isFavorite ? AppColors.success : AppColors.warning,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(AppDimensions.paddingMedium),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
              ),
            ),
          );
        }
      } else {
        throw Exception('Falha ao alterar favorito');
      }
    } catch (e) {
      debugPrint('Erro ao alterar favorito: $e');
      
      // Mostrar erro para o usuário
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao alterar favorito. Tente novamente.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(AppDimensions.paddingMedium),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

/// Botão de favorito compacto para uso em listas
class CompactFavoriteButton extends StatelessWidget {
  final RestaurantModel restaurant;
  final Function(bool)? onFavoriteChanged;
  final bool showFeedback;

  const CompactFavoriteButton({
    super.key,
    required this.restaurant,
    this.onFavoriteChanged,
    this.showFeedback = false,
  });

  @override
  Widget build(BuildContext context) {
    return FavoriteButton(
      restaurant: restaurant,
      onFavoriteChanged: onFavoriteChanged,
      size: 16.0,
      showBackground: false,
      showFeedback: showFeedback,
      padding: const EdgeInsets.all(4),
    );
  }
}

/// Botão de favorito para cards
class CardFavoriteButton extends StatelessWidget {
  final RestaurantModel restaurant;
  final Function(bool)? onFavoriteChanged;
  final bool showFeedback;

  const CardFavoriteButton({
    super.key,
    required this.restaurant,
    this.onFavoriteChanged,
    this.showFeedback = true,
  });

  @override
  Widget build(BuildContext context) {
    return FavoriteButton(
      restaurant: restaurant,
      onFavoriteChanged: onFavoriteChanged,
      size: AppDimensions.iconSmall,
      showBackground: true,
      showFeedback: showFeedback,
    );
  }
}

/// Botão de favorito grande para páginas de detalhes
class LargeFavoriteButton extends StatelessWidget {
  final RestaurantModel restaurant;
  final Function(bool)? onFavoriteChanged;
  final bool showFeedback;

  const LargeFavoriteButton({
    super.key,
    required this.restaurant,
    this.onFavoriteChanged,
    this.showFeedback = true,
  });

  @override
  Widget build(BuildContext context) {
    return FavoriteButton(
      restaurant: restaurant,
      onFavoriteChanged: onFavoriteChanged,
      size: 32.0,
      showBackground: true,
      showFeedback: showFeedback,
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
    );
  }
}

/// Botão de favorito com avaliação rápida
class FavoriteButtonWithQuickRating extends ConsumerStatefulWidget {
  final RestaurantModel restaurant;
  final Function(bool)? onFavoriteChanged;
  final Function(int)? onRatingChanged;
  final bool showFeedback;

  const FavoriteButtonWithQuickRating({
    super.key,
    required this.restaurant,
    this.onFavoriteChanged,
    this.onRatingChanged,
    this.showFeedback = true,
  });

  @override
  ConsumerState<FavoriteButtonWithQuickRating> createState() => _FavoriteButtonWithQuickRatingState();
}

class _FavoriteButtonWithQuickRatingState extends ConsumerState<FavoriteButtonWithQuickRating>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isLoading = false;
  bool _showQuickRating = false;
  int _selectedRating = 0;
  final ReviewRepository _reviewRepository = ReviewRepository();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFavorite = ref.watch(isFavoriteProvider(widget.restaurant.id));
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Botão de favorito principal
        AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: GestureDetector(
                onTap: _isLoading ? null : _toggleFavorite,
                onLongPress: isFavorite ? _showQuickRatingDialog : null,
                child: Container(
                  padding: const EdgeInsets.all(AppDimensions.paddingSmall),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadow.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                          ),
                        )
                      : Icon(
                          isFavorite ? AppIcons.heartFilled : AppIcons.heart,
                          size: 24,
                          color: isFavorite ? AppColors.error : AppColors.textLight,
                        ),
                ),
              ),
            );
          },
        ),
        
        // Indicador de avaliação rápida
        if (isFavorite) ...[
          SizedBox(height: 4),
          Text(
            'Manter pressionado\npara avaliar',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textLight,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Future<void> _toggleFavorite() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      _animationController.forward().then((_) {
        _animationController.reverse();
      });
      
      InteractionService.mediumHaptic();
      
      final favoritesNotifier = ref.read(favoritesProvider.notifier);
      final success = await favoritesNotifier.toggleFavorite(widget.restaurant);
      
      if (success) {
        final isFavorite = ref.read(isFavoriteProvider(widget.restaurant.id));
        
        AnalyticsService.instance.trackEvent(
          'favorite_action',
          parameters: {
            'restaurant_id': widget.restaurant.id,
            'action': isFavorite ? 'add' : 'remove',
            'source': 'favorite_button',
          },
        );

        if (widget.onFavoriteChanged != null) {
          widget.onFavoriteChanged!(isFavorite);
        }
        
        if (widget.showFeedback && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isFavorite 
                    ? '${widget.restaurant.name} adicionado aos favoritos'
                    : '${widget.restaurant.name} removido dos favoritos',
              ),
              backgroundColor: isFavorite ? AppColors.success : AppColors.warning,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(AppDimensions.paddingMedium),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erro ao alterar favorito: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao alterar favorito. Tente novamente.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(AppDimensions.paddingMedium),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showQuickRatingDialog() {
    InteractionService.lightHaptic();
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Avaliação Rápida',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 8),
              Text(
                widget.restaurant.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textLight,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              
              // Estrelas de avaliação
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedRating = index + 1;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        index < _selectedRating ? Icons.star : Icons.star_border,
                        size: 32,
                        color: AppColors.primary,
                      ),
                    ),
                  );
                }),
              ),
              SizedBox(height: 16),
              
              if (_selectedRating > 0)
                Text(
                  _getRatingText(_selectedRating),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              SizedBox(height: 24),
              
              // Botões
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: 'Cancelar',
                      onPressed: () {
                        NavigationHelper.safeGoBack(context);
                        setState(() {
                          _selectedRating = 0;
                        });
                      },
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: CustomButton(
                      text: 'Avaliar',
                      onPressed: _selectedRating > 0
                          ? () {
                              NavigationHelper.safeGoBack(context);
                              _submitQuickRating();
                            }
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitQuickRating() async {
    if (_selectedRating == 0) return;
    
    try {
      final user = ref.read(authProvider);
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Faça login para avaliar restaurantes'),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(AppDimensions.paddingMedium),
            ),
          );
        }
        return;
      }

      final review = ReviewModel(
        id: '',
        restaurantId: widget.restaurant.id,
        userId: user.user?.id ?? '',
        userName: user.user?.email.split('@').first ?? 'Usuário',
        userAvatar: null,
        rating: _selectedRating,
        comment: null,
        createdAt: DateTime.now(),
        updatedAt: null,
        helpfulCount: 0,
        isVerified: false,
        replies: [],
      );

      await _reviewRepository.createReview(review);
      
      if (widget.onRatingChanged != null) {
        widget.onRatingChanged!(_selectedRating);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Avaliação de $_selectedRating estrelas enviada!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(AppDimensions.paddingMedium),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
            ),
          ),
        );
      }
      
      // Analytics
      AnalyticsService.instance.trackEvent(
        'quick_rating_submitted',
        parameters: {
          'restaurant_id': widget.restaurant.id,
          'restaurant_name': widget.restaurant.name,
          'rating': _selectedRating,
        },
      );
      
    } catch (e) {
      debugPrint('Erro ao enviar avaliação rápida: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar avaliação. Tente novamente.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(AppDimensions.paddingMedium),
          ),
        );
      }
    } finally {
      setState(() {
        _selectedRating = 0;
      });
    }
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Muito ruim';
      case 2:
        return 'Ruim';
      case 3:
        return 'Regular';
      case 4:
        return 'Bom';
      case 5:
        return 'Excelente';
      default:
        return '';
    }
  }
}
