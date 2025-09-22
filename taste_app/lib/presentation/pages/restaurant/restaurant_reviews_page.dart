import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/utils/navigation_helper.dart';
import '../../../data/models/review_model.dart';
import '../../../data/models/restaurant_model.dart';
import '../../../data/repositories/review_repository.dart';
import '../../../data/repositories/restaurant_repository.dart';
import '../../../data/datasources/restaurant_remote_datasource.dart';
import '../../../core/services/cache_service.dart';
import '../../../data/services/reviews/review_service.dart';
import '../../widgets/review_card.dart';
import '../../widgets/rating_widget.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/enhanced_error_widget.dart';
import '../../widgets/optimized_list_view.dart';

/// Página para exibir todas as avaliações de um restaurante
class RestaurantReviewsPage extends ConsumerStatefulWidget {
  final String restaurantId;

  const RestaurantReviewsPage({
    super.key,
    required this.restaurantId,
  });

  @override
  ConsumerState<RestaurantReviewsPage> createState() => _RestaurantReviewsPageState();
}

class _RestaurantReviewsPageState extends ConsumerState<RestaurantReviewsPage> {
  final ReviewService _reviewService = ReviewService.instance;
  final RestaurantRepository _restaurantRepository = RestaurantRepository(
    RestaurantRemoteDataSourceImpl(),
    CacheService.instance,
  );
  
  RestaurantModel? _restaurant;
  List<ReviewModel> _reviews = [];
  List<ReviewModel> _filteredReviews = [];
  Map<int, int> _ratingDistribution = {};
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isSubmitting = false;
  String? _error;
  
  // Paginação
  int _currentPage = 1;
  final int _pageSize = 20;
  bool _hasMoreReviews = true;
  
  // Filtros
  int? _selectedRating;
  ReviewSortOption _sortOption = ReviewSortOption.newest;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Carregar restaurante e avaliações em paralelo
      final results = await Future.wait([
        _restaurantRepository.getRestaurantById(widget.restaurantId),
        ReviewService.instance.getRestaurantReviews(widget.restaurantId),
        ReviewService.instance.getRestaurantReviewStats(widget.restaurantId),
      ]);

      _restaurant = results[0] as RestaurantModel?;
      final rawReviews = results[1] as List<ReviewModel>;
      
      // Remover duplicatas baseado no ID da review
      final uniqueReviews = <String, ReviewModel>{};
      for (final review in rawReviews) {
        if (review.id.isNotEmpty) {
          uniqueReviews[review.id] = review;
        }
      }
      _reviews = uniqueReviews.values.toList();
      
      // Extrair distribuição das estatísticas
      final stats = results[2] as Map<String, dynamic>;
      _ratingDistribution = (stats['rating_distribution'] as Map<String, dynamic>?)
          ?.map((key, value) => MapEntry(int.parse(key), value as int)) ?? {};
      
      _applyFiltersAndSort();
      
      debugPrint('✅ Carregadas ${_reviews.length} reviews únicas para o restaurante');
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Erro ao carregar reviews: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _applyFiltersAndSort() {
    var filteredReviews = List<ReviewModel>.from(_reviews);
    
    // Aplicar filtro de rating
    if (_selectedRating != null) {
      filteredReviews = filteredReviews
          .where((review) => review.rating == _selectedRating)
          .toList();
    }
    
    // Aplicar ordenação
    switch (_sortOption) {
      case ReviewSortOption.newest:
        filteredReviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case ReviewSortOption.oldest:
        filteredReviews.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case ReviewSortOption.highestRating:
        filteredReviews.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case ReviewSortOption.lowestRating:
        filteredReviews.sort((a, b) => a.rating.compareTo(b.rating));
        break;
      case ReviewSortOption.mostHelpful:
        filteredReviews.sort((a, b) => b.helpfulCount.compareTo(a.helpfulCount));
        break;
    }
    
    setState(() {
      _filteredReviews = filteredReviews;
    });
  }
  
  Future<void> _loadMoreReviews() async {
    if (_isLoadingMore || !_hasMoreReviews) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    try {
      final newReviews = await ReviewService.instance.getRestaurantReviews(
        widget.restaurantId,
        limit: _pageSize,
        offset: _currentPage * _pageSize,
      );
      
      if (newReviews.isNotEmpty) {
        // Criar mapa de reviews existentes para evitar duplicatas
        final existingIds = _reviews.map((r) => r.id).toSet();
        final uniqueNewReviews = newReviews
            .where((review) => !existingIds.contains(review.id))
            .toList();
        
        setState(() {
          _reviews.addAll(uniqueNewReviews);
          _currentPage++;
          _hasMoreReviews = newReviews.length == _pageSize;
        });
        _applyFiltersAndSort();
        
        debugPrint('✅ Carregadas ${uniqueNewReviews.length} novas reviews (${newReviews.length - uniqueNewReviews.length} duplicatas ignoradas)');
      } else {
        setState(() {
          _hasMoreReviews = false;
        });
      }
    } catch (e) {
      // Silenciosamente falhar no carregamento de mais reviews
      debugPrint('Erro ao carregar mais reviews: $e');
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _restaurant?.name ?? 'Avaliações',
          style: AppTextStyles.headingMedium.copyWith(
            color: AppColors.textDark,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        actions: [
          IconButton(
            onPressed: _showSortOptions,
            icon: Icon(Icons.sort),
          ),
          IconButton(
            onPressed: _showFilterOptions,
            icon: Icon(Icons.filter_list),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showRatingDialog,
        backgroundColor: AppColors.primary,
        icon: Icon(Icons.star_border, color: AppColors.surface),
        label: Text(
          'Avaliar',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.surface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingWidget();
    }

    if (_error != null) {
      return EnhancedErrorWidget(
        title: 'Erro ao carregar avaliações',
        message: _error!,
        onRetry: _loadData,
        errorType: ErrorType.general,
      );
    }

    return Column(
      children: [
        // Estatísticas de avaliação
        if (_restaurant != null) _buildReviewStats(),
        
        // Filtros ativos
        if (_selectedRating != null || _sortOption != ReviewSortOption.newest)
          _buildActiveFilters(),
        
        // Lista de avaliações
        Expanded(
          child: _filteredReviews.isEmpty
              ? _buildEmptyState()
              : _buildReviewsList(),
        ),
      ],
    );
  }

  Widget _buildReviewStats() {
    return Container(
      margin: const EdgeInsets.all(AppDimensions.paddingMedium),
      child: DetailedRatingWidget(
        rating: _restaurant!.rating,
        reviewCount: _reviews.length,
        ratingDistribution: _ratingDistribution,
      ),
    );
  }

  Widget _buildActiveFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingMedium,
        vertical: AppDimensions.paddingSmall,
      ),
      child: Row(
        children: [
          Text(
            'Filtros:',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textLight,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: AppDimensions.paddingSmall),
          if (_selectedRating != null) ...[
            _buildFilterChip(
              label: '$_selectedRating estrelas',
              onRemove: () {
                setState(() {
                  _selectedRating = null;
                });
                _applyFiltersAndSort();
              },
            ),
            SizedBox(width: AppDimensions.paddingSmall),
          ],
          if (_sortOption != ReviewSortOption.newest)
            _buildFilterChip(
              label: _sortOption.label,
              onRemove: () {
                setState(() {
                  _sortOption = ReviewSortOption.newest;
                });
                _applyFiltersAndSort();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required VoidCallback onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingSmall,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close,
              size: 16,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.message_outlined,
            size: 64,
            color: AppColors.textLight,
          ),
          SizedBox(height: AppDimensions.paddingMedium),
          Text(
            _selectedRating != null
                ? 'Nenhuma avaliação com $_selectedRating estrelas'
                : 'Nenhuma avaliação encontrada',
            style: AppTextStyles.headingMedium,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppDimensions.paddingSmall),
          Text(
            _selectedRating != null
                ? 'Tente remover os filtros para ver mais avaliações'
                : 'Seja o primeiro a avaliar este restaurante',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textLight,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsList() {
    return OptimizedListView<ReviewModel>(
      items: _filteredReviews,
      isLoading: _isLoading,
      isLoadingMore: _isLoadingMore,
      hasMoreItems: _hasMoreReviews,
      onLoadMore: _loadMoreReviews,
      enableLazyLoading: true,
      enableAnimations: true,
      itemExtent: 200, // Altura estimada do ReviewCard
      itemBuilder: (context, review, index) {
        return RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.paddingMedium),
            child: ReviewCard(review: review),
          ),
        );
      },
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _SortOptionsSheet(
        currentOption: _sortOption,
        onOptionSelected: (option) {
          setState(() {
            _sortOption = option;
          });
          _applyFiltersAndSort();
          NavigationHelper.safeGoBack(context);
        },
      ),
    );
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _FilterOptionsSheet(
        currentRating: _selectedRating,
        ratingDistribution: _ratingDistribution,
        onRatingSelected: (rating) {
          setState(() {
            _selectedRating = rating;
          });
          _applyFiltersAndSort();
          NavigationHelper.safeGoBack(context);
        },
      ),
    );
  }

  Future<void> _showRatingDialog() async {
    if (_restaurant == null || _isSubmitting) return;
    
    await showDialog(
      context: context,
      builder: (context) => RatingDialog(
        restaurantName: _restaurant!.name,
        onSubmit: (rating, comment) async {
          // Prevenir submissões múltiplas
          if (_isSubmitting) return;
          
          setState(() {
            _isSubmitting = true;
          });
          
          try {
            // Mostrar loading
            if (mounted) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => Center(
                  child: Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        SizedBox(height: 16),
                        Text('Salvando avaliação...'),
                      ],
                    ),
                  ),
                ),
              );
            }

            // Criar avaliação usando ReviewService
            await ReviewService.instance.createReview(
              restaurantId: _restaurant!.id,
              rating: rating,
              comment: comment.trim(),
            );

            // Fechar loading
            if (mounted) Navigator.of(context).pop();

            // Mostrar sucesso
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Avaliação salva com sucesso!'),
                  backgroundColor: AppColors.success,
                ),
              );
            }

            // Recarregar dados
            await _loadData();
          } catch (e) {
            // Fechar loading
            if (mounted) Navigator.of(context).pop();

            // Mostrar erro
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Erro ao salvar avaliação: $e'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          } finally {
            // Sempre resetar flag de submissão
            if (mounted) {
              setState(() {
                _isSubmitting = false;
              });
            }
          }
        },
      ),
    );
  }
}

/// Enum para opções de ordenação
enum ReviewSortOption {
  newest('Mais recentes'),
  oldest('Mais antigas'),
  highestRating('Maior avaliação'),
  lowestRating('Menor avaliação'),
  mostHelpful('Mais úteis');

  const ReviewSortOption(this.label);
  final String label;
}

/// Sheet para opções de ordenação
class _SortOptionsSheet extends StatelessWidget {
  final ReviewSortOption currentOption;
  final Function(ReviewSortOption) onOptionSelected;

  const _SortOptionsSheet({
    required this.currentOption,
    required this.onOptionSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ordenar por',
            style: AppTextStyles.headingMedium,
          ),
          SizedBox(height: AppDimensions.paddingMedium),
          ...ReviewSortOption.values.map((option) => ListTile(
            title: Text(option.label),
            trailing: currentOption == option
                ? Icon(Icons.check, color: AppColors.primary)
                : null,
            onTap: () => onOptionSelected(option),
          )),
        ],
      ),
    );
  }
}

/// Sheet para opções de filtro
class _FilterOptionsSheet extends StatelessWidget {
  final int? currentRating;
  final Map<int, int> ratingDistribution;
  final Function(int?) onRatingSelected;

  const _FilterOptionsSheet({
    required this.currentRating,
    required this.ratingDistribution,
    required this.onRatingSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filtrar por avaliação',
            style: AppTextStyles.headingMedium,
          ),
          SizedBox(height: AppDimensions.paddingMedium),
          ListTile(
            title: Text('Todas as avaliações'),
            trailing: currentRating == null
                ? Icon(Icons.check, color: AppColors.primary)
                : null,
            onTap: () => onRatingSelected(null),
          ),
          ...List.generate(5, (index) {
            final rating = 5 - index;
            final count = ratingDistribution[rating] ?? 0;
            
            return ListTile(
              title: Row(
                children: [
                  ...List.generate(rating, (i) => Icon(
                    Icons.star,
                    size: 16,
                    color: AppColors.warning,
                  )),
                  ...List.generate(5 - rating, (i) => Icon(
                    Icons.star_border,
                    size: 16,
                    color: AppColors.textLight,
                  )),
                  SizedBox(width: AppDimensions.paddingSmall),
                  Text(
                    '($count)',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
              trailing: currentRating == rating
                  ? Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: count > 0 ? () => onRatingSelected(rating) : null,
              enabled: count > 0,
            );
          }),
        ],
      ),
    );
  }
}
