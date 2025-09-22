import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_icons.dart';
import '../../core/services/ui/interaction_service.dart';
import '../../core/extensions/widget_extensions.dart';
import '../../data/models/restaurant_model.dart';
import '../../services/analytics_service.dart';
import '../providers/favorites_provider.dart';
import 'favorite_button.dart';
import 'cached_image_widget.dart';
import 'rating_widget.dart';

/// Card de restaurante para exibição em lista
class RestaurantCard extends ConsumerStatefulWidget {
  final RestaurantModel restaurant;
  final VoidCallback? onTap;
  final Function(bool)? onFavoriteChanged;
  final Function(int)? onRatingChanged;
  final bool showDistance;
  final bool isCompact;
  final bool showFavoriteButton;
  final bool enableQuickRating;
  final EdgeInsetsGeometry? margin;

  const RestaurantCard({
    super.key,
    required this.restaurant,
    this.onTap,
    this.onFavoriteChanged,
    this.onRatingChanged,
    this.showDistance = true,
    this.isCompact = false,
    this.showFavoriteButton = true,
    this.enableQuickRating = false,
    this.margin,
  });

  @override
  ConsumerState<RestaurantCard> createState() => _RestaurantCardState();
}

class _RestaurantCardState extends ConsumerState<RestaurantCard> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        margin: widget.margin,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.all(Radius.circular(AppDimensions.radiusMedium)),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: widget.isCompact ? _buildCompactContent() : _buildFullContent(),
      ).withTapAnimation(
        onTap: () {
          if (widget.onTap != null) {
            widget.onTap!();
          }
        },
        scaleDown: 0.98,
        enableHaptic: true,
      ),
    );
  }

  Widget _buildFullContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildImageSection(),
        Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: AppDimensions.paddingSmall),
              _buildRatingAndCategory(),
              if (widget.showDistance && widget.restaurant.distance != null) ...[
                const SizedBox(height: AppDimensions.paddingSmall),
                _buildDistanceInfo(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactContent() {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      child: Row(
        children: [
          _buildCompactImage(),
          const SizedBox(width: AppDimensions.paddingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: AppDimensions.paddingSmall),
                _buildRatingAndCategory(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppDimensions.radiusMedium),
            topRight: Radius.circular(AppDimensions.radiusMedium),
          ),
          child: CachedNetworkImage(
            imageUrl: widget.restaurant.imageUrl ?? '',
            width: double.infinity,
            height: 180,
            fit: BoxFit.cover,
            memCacheWidth: 400,
            memCacheHeight: 240,
            maxWidthDiskCache: 800,
            maxHeightDiskCache: 480,
            placeholder: (context, url) => Container(
              width: double.infinity,
              height: 180,
              color: AppColors.background,
              child: const Icon(
                AppIcons.restaurant,
                size: 48,
                color: AppColors.textLight,
              ),
            ),
            errorWidget: (context, url, error) => Container(
              width: double.infinity,
              height: 180,
              color: AppColors.background,
              child: const Icon(
                AppIcons.restaurant,
                size: 48,
                color: AppColors.textLight,
              ),
            ),
          ),
        ),
        if (widget.showFavoriteButton)
          Positioned(
            top: AppDimensions.paddingSmall,
            right: AppDimensions.paddingSmall,
            child: _buildFavoriteButton(),
          ),
        if (!widget.restaurant.isOpen)
          Positioned(
            top: AppDimensions.paddingSmall,
            left: AppDimensions.paddingSmall,
            child: _buildClosedBadge(),
          ),
        if (widget.restaurant.hasPromotion)
          Positioned(
            bottom: AppDimensions.paddingSmall,
            left: AppDimensions.paddingSmall,
            child: _buildPromotionBadge(),
          ),
      ],
    );
  }

  Widget _buildCompactImage() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
          child: CachedNetworkImage(
            imageUrl: widget.restaurant.imageUrl ?? '',
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            memCacheWidth: 120,
            memCacheHeight: 120,
            maxWidthDiskCache: 160,
            maxHeightDiskCache: 160,
            placeholder: (context, url) => Container(
              width: 80,
              height: 80,
              color: AppColors.background,
              child: Icon(
                AppIcons.restaurant,
                size: 24,
                color: AppColors.textLight,
              ),
            ),
            errorWidget: (context, url, error) => Container(
              width: 80,
              height: 80,
              color: AppColors.background,
              child: Icon(
                AppIcons.restaurant,
                size: 24,
                color: AppColors.textLight,
              ),
            ),
          ),
        ),
        if (!widget.restaurant.isOpen)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.shadow.withOpacity(0.7),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
              ),
              child: const Center(
                child: Text(
                  'FECHADO',
                  style: TextStyle(
                    color: AppColors.surface,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.restaurant.name,
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.textDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (widget.restaurant.description?.isNotEmpty == true)
                Text(
                  widget.restaurant.description!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        if (!widget.isCompact && widget.showFavoriteButton)
          _buildFavoriteButton(),
      ],
    );
  }

  Widget _buildRatingAndCategory() {
    return Row(
      children: [
        RatingWidget(
          rating: widget.restaurant.rating,
          reviewCount: widget.restaurant.reviewCount,
          size: RatingSize.small,
        ),
        SizedBox(width: AppDimensions.paddingMedium),
        Expanded(
          child: Text(
            widget.restaurant.category,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textLight,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }


  Widget _buildDistanceInfo() {
    if (widget.restaurant.distance == null) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        Icon(
          AppIcons.location,
          size: AppDimensions.iconSmall,
          color: AppColors.textLight,
        ),
        SizedBox(width: 4),
        Text(
          '${widget.restaurant.distance!.toStringAsFixed(1)} km',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textLight,
          ),
        ),
      ],
    );
  }

  Widget _buildFavoriteButton() {
    if (widget.enableQuickRating) {
      return FavoriteButtonWithQuickRating(
        restaurant: widget.restaurant,
        onFavoriteChanged: widget.onFavoriteChanged,
        onRatingChanged: widget.onRatingChanged,
        showFeedback: true,
      );
    }
    
    final isFavorite = ref.watch(isFavoriteProvider(widget.restaurant.id));
    
    return GestureDetector(
      onTap: _isLoading ? null : _toggleFavorite,
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
                width: AppDimensions.iconSmall,
                height: AppDimensions.iconSmall,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isFavorite ? AppColors.error : AppColors.textLight,
                  ),
                ),
              )
            : Icon(
                isFavorite ? AppIcons.heartFilled : AppIcons.heart,
                size: AppDimensions.iconSmall,
                color: isFavorite ? AppColors.error : AppColors.textLight,
              ),
      ),
    );
  }

  Widget _buildClosedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingSmall,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
      ),
      child: Text(
        'FECHADO',
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.surface,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildPromotionBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingSmall,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.success,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            AppIcons.discount,
            size: 12,
            color: AppColors.surface,
          ),
          SizedBox(width: 4),
          Text(
            'PROMOÇÃO',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.surface,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
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
            'source': 'restaurant_card',
          },
        );

        if (widget.onFavoriteChanged != null) {
          widget.onFavoriteChanged!(isFavorite);
        }
        
        // Mostrar feedback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isFavorite 
                    ? '${widget.restaurant.name} adicionado aos favoritos'
                    : '${widget.restaurant.name} removido dos favoritos',
              ),
              backgroundColor: isFavorite ? AppColors.success : AppColors.warning,
              duration: const Duration(seconds: 2),
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

/// Card de restaurante para exibição em grade
class RestaurantGridCard extends ConsumerStatefulWidget {
  final RestaurantModel restaurant;
  final VoidCallback? onTap;
  final Function(bool)? onFavoriteChanged;
  final bool showFavoriteButton;

  const RestaurantGridCard({
    super.key,
    required this.restaurant,
    this.onTap,
    this.onFavoriteChanged,
    this.showFavoriteButton = true,
  });

  @override
  ConsumerState<RestaurantGridCard> createState() => _RestaurantGridCardState();
}

class _RestaurantGridCardState extends ConsumerState<RestaurantGridCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        InteractionService.lightHaptic();
        _animationController.forward().then((_) {
          _animationController.reverse();
        });
        
        if (widget.onTap != null) {
          widget.onTap!();
        }
      },
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 - (_animationController.value * 0.02),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildImageSection(),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.paddingSmall),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),
                          SizedBox(height: 4),
                          _buildRatingAndCategory(),
                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildImageSection() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppDimensions.radiusMedium),
            topRight: Radius.circular(AppDimensions.radiusMedium),
          ),
          child: CachedImageWidget(
            imageUrl: widget.restaurant.imageUrl,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            placeholder: Container(
              width: double.infinity,
              height: double.infinity,
              color: AppColors.background,
              child: Icon(
                AppIcons.restaurant,
                size: 32,
                color: AppColors.textLight,
              ),
            ),
          ),
        ),
        Positioned(
          top: AppDimensions.paddingSmall,
          right: AppDimensions.paddingSmall,
          child: _buildFavoriteButton(),
        ),
        if (!widget.restaurant.isOpen)
          Positioned(
            top: AppDimensions.paddingSmall,
            left: AppDimensions.paddingSmall,
            child: _buildClosedBadge(),
          ),
        if (widget.restaurant.hasPromotion)
          Positioned(
            bottom: AppDimensions.paddingSmall,
            left: AppDimensions.paddingSmall,
            child: _buildPromotionBadge(),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return Text(
      widget.restaurant.name,
      style: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.textDark,
        fontWeight: FontWeight.w600,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildRatingAndCategory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RatingWidget(
          rating: widget.restaurant.rating,
          reviewCount: widget.restaurant.reviewCount,
          size: RatingSize.small,
        ),
        SizedBox(height: 2),
        Text(
          widget.restaurant.category,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textLight,
            fontSize: 11,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }


  Widget _buildFavoriteButton() {
    final isFavorite = ref.watch(isFavoriteProvider(widget.restaurant.id));
    
    return GestureDetector(
      onTap: _isLoading ? null : _toggleFavorite,
      child: Container(
        padding: const EdgeInsets.all(6),
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
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isFavorite ? AppColors.error : AppColors.textLight,
                  ),
                ),
              )
            : Icon(
                isFavorite ? AppIcons.heartFilled : AppIcons.heart,
                size: 12,
                color: isFavorite ? AppColors.error : AppColors.textLight,
              ),
      ),
    );
  }

  Widget _buildClosedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'FECHADO',
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.surface,
          fontWeight: FontWeight.bold,
          fontSize: 8,
        ),
      ),
    );
  }

  Widget _buildPromotionBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.success,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            AppIcons.discount,
            size: 8,
            color: AppColors.surface,
          ),
          SizedBox(width: 2),
          Text(
            'PROMO',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.surface,
              fontWeight: FontWeight.bold,
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
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
            'source': 'restaurant_grid_card',
          },
        );

        if (widget.onFavoriteChanged != null) {
          widget.onFavoriteChanged!(isFavorite);
        }
      }
    } catch (e) {
      debugPrint('Erro ao alterar favorito: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
