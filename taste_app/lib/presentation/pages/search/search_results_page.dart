import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/animations/animation_service.dart';
import '../../../core/extensions/widget_extensions.dart';
import '../../../core/utils/navigation_helper.dart';
import '../../../data/models/restaurant_model.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/location_model.dart';
import '../../../data/services/search/search_service.dart';
import '../../../services/analytics_service.dart';
import '../../../data/repositories/search_repository.dart';
import '../../widgets/widgets.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/search_filters_widget.dart';
import '../../widgets/search_suggestions_widget.dart';
import '../../widgets/enhanced_map_widget.dart';
import '../../widgets/restaurant_card.dart';
import '../../widgets/restaurant_grid_card.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/optimized_list_view.dart';
import '../../widgets/view_mode_loading_widget.dart';
import '../../widgets/no_restaurants_found_widget.dart';

/// Página de resultados de busca com filtros e ordenação
class SearchResultsPage extends ConsumerStatefulWidget {
  final String query;
  final String? categoryId;
  final Map<String, dynamic>? initialFilters;

  const SearchResultsPage({
    super.key,
    required this.query,
    this.categoryId,
    this.initialFilters,
  });

  @override
  ConsumerState<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends ConsumerState<SearchResultsPage>
    with TickerProviderStateMixin {
  final SearchService _searchService = SearchService.instance;
  late final SearchRepository _searchRepository;
  final ScrollController _scrollController = ScrollController();
  late final AnimationController _filterAnimationController;
  late final AnimationController _sortAnimationController;

  List<RestaurantModel> _restaurants = [];
  List<RestaurantModel> _allRestaurants = [];
  List<CategoryModel> _categories = [];
  
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreResults = true;
  bool _showFilters = false;
  bool _showSortOptions = false;
  bool _isViewModeChanging = false;
  
  SearchFilters _currentFilters = const SearchFilters();
  String _currentSortBy = 'relevance';
  String _currentViewMode = 'list'; // 'list', 'grid' ou 'map'
  
  int _currentPage = 1;
  final int _pageSize = 20;
  LocationModel? _userLocation;
  
  // Opções de ordenação
  final List<Map<String, String>> _sortOptions = [
    {'key': 'relevance', 'label': 'Relevância'},
    {'key': 'rating', 'label': 'Avaliação'},
    {'key': 'distance', 'label': 'Distância'},
    {'key': 'delivery_time', 'label': 'Tempo de entrega'},
    {'key': 'delivery_fee', 'label': 'Taxa de entrega'},
    {'key': 'alphabetical', 'label': 'Nome A-Z'},
  ];

  @override
  void initState() {
    super.initState();
    _searchRepository = SearchRepositoryImpl(_searchService);
    _scrollController.addListener(_onScroll);
    
    _filterAnimationController = AnimationController(
      duration: AnimationService.normal,
      vsync: this,
    );
    
    _sortAnimationController = AnimationController(
      duration: AnimationService.normal,
      vsync: this,
    );
    
    // Aplicar filtros iniciais se fornecidos
    if (widget.initialFilters != null) {
      _currentFilters = SearchFilters.fromMap(widget.initialFilters!);
    }
    
    if (widget.categoryId != null) {
      _currentFilters = _currentFilters.copyWith(categoryId: widget.categoryId);
    }
    
    // Carregar dados iniciais
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
      _loadUserLocation();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _filterAnimationController.dispose();
    _sortAnimationController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreResults();
    }
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
    });

    try {
      await Future.wait([
        _loadCategories(),
        _performSearch(reset: true),
      ]);
    } catch (e) {
      _showErrorSnackBar('Erro ao carregar dados: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCategories() async {
    try {
      // TODO: Implementar carregamento real das categorias
      _categories = [
        CategoryModel(
          id: '1',
          name: 'Pizza',
          icon: 'local_pizza',
          color: '#FF6B47',
          isActive: true,
          sortOrder: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        CategoryModel(
          id: '2',
          name: 'Hambúrguer',
          icon: 'fastfood',
          color: '#4CAF50',
          isActive: true,
          sortOrder: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        // Adicionar mais categorias conforme necessário
      ];
    } catch (e) {
      debugPrint('Erro ao carregar categorias: $e');
    }
  }

  Future<void> _performSearch({bool reset = false}) async {
    if (reset) {
      setState(() {
        _currentPage = 1;
        _hasMoreResults = true;
      });
    }

    if (!_hasMoreResults && !reset) return;

    setState(() {
      if (reset) {
        _isLoading = true;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      final results = await _searchService.searchRestaurants(
        query: widget.query,
        categoryId: _currentFilters.categoryId,
        latitude: _currentFilters.latitude,
        longitude: _currentFilters.longitude,
        maxDistance: _currentFilters.maxDistance,
        minRating: _currentFilters.minRating,
        isOpen: _currentFilters.isOpen,
        sortBy: _currentSortBy,
        page: _currentPage,
        pageSize: _pageSize,
      );

      if (results.hasError) {
        throw Exception(results.error);
      }

      setState(() {
        if (reset) {
          _restaurants = results.restaurants;
          _allRestaurants = results.restaurants;
        } else {
          _restaurants.addAll(results.restaurants);
          _allRestaurants.addAll(results.restaurants);
        }
        
        _hasMoreResults = results.restaurants.length == _pageSize;
        _currentPage++;
      });

      // Analytics: rastrear resultados
      AnalyticsService.instance.trackSearch(
        query: widget.query,
        resultsCount: _restaurants.length,
        category: _currentFilters.categoryId,
        filters: _currentFilters.toMap(),
      );
    } catch (e) {
      _showErrorSnackBar('Erro na busca: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMoreResults() async {
    if (!_isLoadingMore && _hasMoreResults) {
      await _performSearch();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchHeader(),
          if (_showFilters) _buildFiltersSection(),
          if (_showSortOptions) _buildSortSection(),
          Expanded(
            child: _buildResultsContent(),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          AppIcons.back,
          color: AppColors.textDark,
        ),
        onPressed: () {
          AnimationService.lightHaptic();
          NavigationHelper.safeGoBack(context);
        },
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resultados para',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textLight,
            ),
          ),
          Text(
            '"${widget.query}"',
            style: AppTextStyles.h3.copyWith(
              color: AppColors.textDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            _getViewModeIcon(),
            color: AppColors.textDark,
          ),
          onPressed: () {
            AnimationService.lightHaptic();
            _toggleViewMode();
          },
          tooltip: _getViewModeTooltip(),
        ),
        IconButton(
          icon: Icon(
            AppIcons.search,
            color: AppColors.textDark,
          ),
          onPressed: () {
            AnimationService.lightHaptic();
            NavigationHelper.safeGoBack(context);
          },
          tooltip: 'Nova busca',
        ),
      ],
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.divider,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_restaurants.length} restaurante${_restaurants.length != 1 ? 's' : ''} encontrado${_restaurants.length != 1 ? 's' : ''}',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textLight,
              ),
            ),
          ),
          _buildFilterButton(),
          SizedBox(width: AppDimensions.paddingSmall),
          _buildSortButton(),
        ],
      ),
    ).fadeIn();
  }

  Widget _buildFilterButton() {
    final hasActiveFilters = _isFiltersActive();
    
    return GestureDetector(
      onTap: () {
        AnimationService.mediumHaptic();
        _toggleFilters();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingMedium,
          vertical: AppDimensions.paddingSmall,
        ),
        decoration: BoxDecoration(
          color: hasActiveFilters ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
          border: Border.all(
            color: hasActiveFilters ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.filter,
              size: AppDimensions.iconSmall,
              color: hasActiveFilters ? AppColors.surface : AppColors.textDark,
            ),
            SizedBox(width: AppDimensions.paddingSmall),
            Text(
              'Filtros',
              style: AppTextStyles.bodySmall.copyWith(
                color: hasActiveFilters ? AppColors.surface : AppColors.textDark,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (hasActiveFilters) ...[
              SizedBox(width: AppDimensions.paddingSmall),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  _getActiveFiltersCount().toString(),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ).scaleIn(delay: const Duration(milliseconds: 100));
  }

  Widget _buildSortButton() {
    final currentSort = _sortOptions.firstWhere(
      (option) => option['key'] == _currentSortBy,
      orElse: () => _sortOptions.first,
    );
    
    return GestureDetector(
      onTap: () {
        AnimationService.mediumHaptic();
        _toggleSortOptions();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingMedium,
          vertical: AppDimensions.paddingSmall,
        ),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.sort,
              size: AppDimensions.iconSmall,
              color: AppColors.textDark,
            ),
            SizedBox(width: AppDimensions.paddingSmall),
            Text(
              currentSort['label']!,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textDark,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: AppDimensions.paddingSmall),
            Icon(
              _showSortOptions ? AppIcons.chevronUp : AppIcons.chevronDown,
              size: AppDimensions.iconSmall,
              color: AppColors.textLight,
            ),
          ],
        ),
      ),
    ).scaleIn(delay: const Duration(milliseconds: 150));
  }

  Widget _buildFiltersSection() {
    return AnimatedBuilder(
      animation: _filterAnimationController,
      builder: (context, child) {
        return SizeTransition(
          sizeFactor: _filterAnimationController,
          child: Container(
            padding: const EdgeInsets.all(AppDimensions.paddingMedium),
            decoration: const BoxDecoration(
              color: AppColors.background,
              border: Border(
                bottom: BorderSide(
                  color: AppColors.divider,
                  width: 1,
                ),
              ),
            ),
            child: SearchFiltersWidget(
              initialFilters: _currentFilters,
              categories: _categories,
              onFiltersChanged: _applyFilters,
              onClearFilters: _clearFilters,
              isCompact: true,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSortSection() {
    return AnimatedBuilder(
      animation: _sortAnimationController,
      builder: (context, child) {
        return SizeTransition(
          sizeFactor: _sortAnimationController,
          child: Container(
            padding: const EdgeInsets.all(AppDimensions.paddingMedium),
            decoration: const BoxDecoration(
              color: AppColors.background,
              border: Border(
                bottom: BorderSide(
                  color: AppColors.divider,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ordenar por',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: AppDimensions.paddingSmall),
                Wrap(
                  spacing: AppDimensions.paddingSmall,
                  runSpacing: AppDimensions.paddingSmall,
                  children: _sortOptions.map((option) {
                    final isSelected = option['key'] == _currentSortBy;
                    
                    return GestureDetector(
                      onTap: () {
                        AnimationService.selectionHaptic();
                        _applySorting(option['key']!);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.paddingMedium,
                          vertical: AppDimensions.paddingSmall,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.divider,
                          ),
                        ),
                        child: Text(
                          option['label']!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isSelected ? AppColors.surface : AppColors.textDark,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultsContent() {
    if (_isLoading) {
      return const LoadingWidget();
    }

    if (_restaurants.isEmpty) {
      return NoRestaurantsFoundWidget(
        onChangeFilters: () {
          _toggleFilters();
        },
        onClearFilters: _isFiltersActive() ? _clearFilters : null,
        hasActiveFilters: _isFiltersActive(),
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => _performSearch(reset: true),
          child: _buildCurrentView(),
        ),
        if (_isViewModeChanging)
          ViewModeLoadingOverlay(
            message: 'Alterando visualização...',
          ),
      ],
    );
  }

  Widget _buildListView() {
    return OptimizedListView<RestaurantModel>(
      items: _restaurants,
      scrollController: _scrollController,
      onLoadMore: _hasMoreResults ? _loadMoreResults : null,
      isLoading: _isLoading,
      isLoadingMore: _isLoadingMore,
      hasMoreItems: _hasMoreResults,
      enableLazyLoading: true,
      enableAnimations: true,
      itemBuilder: (context, restaurant, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.paddingMedium),
          child: RestaurantCard(
            restaurant: restaurant,
            onTap: () => _onRestaurantTap(restaurant),
            showDistance: true,
            showDeliveryInfo: true,
          ),
        );
      },
      emptyWidget: const EmptyStateWidget(
        icon: Icons.search_off,
        title: 'Nenhum resultado encontrado',
        subtitle: 'Tente ajustar sua busca ou filtros',
      ),
    );
  }

  Widget _buildGridView() {
    return OptimizedGridView<RestaurantModel>(
      items: _restaurants,
      scrollController: _scrollController,
      onLoadMore: _hasMoreResults ? _loadMoreResults : null,
      isLoading: _isLoading,
      isLoadingMore: _isLoadingMore,
      hasMoreItems: _hasMoreResults,
      enableLazyLoading: true,
      enableAnimations: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: AppDimensions.paddingMedium,
        mainAxisSpacing: AppDimensions.paddingMedium,
      ),
      itemBuilder: (context, restaurant, index) {
        return RestaurantGridCard(
          restaurant: restaurant,
          onTap: () => _onRestaurantTap(restaurant),
        );
      },
      emptyWidget: const EmptyStateWidget(
        icon: Icons.search_off,
        title: 'Nenhum resultado encontrado',
        subtitle: 'Tente ajustar sua busca ou filtros',
      ),
    );
  }

  // Métodos auxiliares
  void _toggleViewMode() async {
    setState(() {
      _isViewModeChanging = true;
    });
    
    // Pequeno delay para mostrar o loading
    await Future.delayed(const Duration(milliseconds: 300));
    
    setState(() {
      // Ciclo: list -> grid -> map -> list
      switch (_currentViewMode) {
        case 'list':
          _currentViewMode = 'grid';
          break;
        case 'grid':
          _currentViewMode = 'map';
          break;
        case 'map':
          _currentViewMode = 'list';
          break;
        default:
          _currentViewMode = 'list';
      }
    });
    
    // Delay adicional para animação suave
    await Future.delayed(const Duration(milliseconds: 200));
    
    setState(() {
      _isViewModeChanging = false;
    });
    
    // Analytics: rastrear mudança de visualização
    AnalyticsService.instance.trackCustomEvent(
      eventName: 'search_view_mode_changed',
      parameters: {
        'view_mode': _currentViewMode,
        'query': widget.query,
      },
    );
  }
  
  void _loadUserLocation() {
    final locationState = ref.read(locationProvider);
    setState(() {
      _userLocation = locationState.currentLocation;
    });
  }
  
  IconData _getViewModeIcon() {
    switch (_currentViewMode) {
      case 'list':
        return AppIcons.category; // Próximo: grid
      case 'grid':
        return AppIcons.location; // Próximo: map
      case 'map':
        return AppIcons.menu; // Próximo: list
      default:
        return AppIcons.menu;
    }
  }
  
  String _getViewModeTooltip() {
    switch (_currentViewMode) {
      case 'list':
        return 'Visualização em grade';
      case 'grid':
        return 'Visualização em mapa';
      case 'map':
        return 'Visualização em lista';
      default:
        return 'Alterar visualização';
    }
  }
  
  Widget _buildCurrentView() {
    switch (_currentViewMode) {
      case 'list':
        return _buildListView();
      case 'grid':
        return _buildGridView();
      case 'map':
        return _buildMapView();
      default:
        return _buildListView();
    }
  }
  
  Widget _buildMapView() {
    return EnhancedMapWidget(
      userLocation: _userLocation,
      restaurants: _restaurants,
      onRestaurantTap: _onRestaurantTap,
      showUserLocation: true,
      showCustomInfoWindow: true,
      enableClustering: true,
      zoom: 14.0,
    );
  }

  void _toggleFilters() {
    setState(() {
      _showFilters = !_showFilters;
      if (_showFilters) {
        _showSortOptions = false;
        _sortAnimationController.reverse();
        _filterAnimationController.forward();
      } else {
        _filterAnimationController.reverse();
      }
    });
  }

  void _toggleSortOptions() {
    setState(() {
      _showSortOptions = !_showSortOptions;
      if (_showSortOptions) {
        _showFilters = false;
        _filterAnimationController.reverse();
        _sortAnimationController.forward();
      } else {
        _sortAnimationController.reverse();
      }
    });
  }

  void _applyFilters(SearchFilters filters) {
    setState(() {
      _currentFilters = filters;
    });
    
    _performSearch(reset: true);
    _toggleFilters();
    
    // Analytics: rastrear aplicação de filtros
    AnalyticsService.instance.trackCustomEvent(
      eventName: 'search_filters_applied',
      parameters: {
        'query': widget.query,
        'filters': filters.toMap(),
      },
    );
  }

  void _clearFilters() {
    setState(() {
      _currentFilters = const SearchFilters();
    });
    
    _performSearch(reset: true);
    
    // Analytics: rastrear limpeza de filtros
    AnalyticsService.instance.trackCustomEvent(
      eventName: 'search_filters_cleared',
      parameters: {
        'query': widget.query,
      },
    );
  }

  void _applySorting(String sortBy) {
    setState(() {
      _currentSortBy = sortBy;
    });
    
    _performSearch(reset: true);
    _toggleSortOptions();
    
    // Analytics: rastrear mudança de ordenação
    AnalyticsService.instance.trackCustomEvent(
      eventName: 'search_sort_changed',
      parameters: {
        'query': widget.query,
        'sort_by': sortBy,
      },
    );
  }

  void _onRestaurantTap(RestaurantModel restaurant) {
    // Analytics: rastrear visualização de restaurante
    AnalyticsService.instance.trackRestaurantView(
      restaurantId: restaurant.id,
      restaurantName: restaurant.name,
      category: restaurant.category,
      source: 'search_results',
    );
    
    // Navegar para detalhes do restaurante
    context.push('/restaurant/${restaurant.id}');
  }

  bool _isFiltersActive() {
    return _currentFilters.categoryId != null ||
           _currentFilters.maxDistance != null ||
           _currentFilters.minRating != null ||
           _currentFilters.isOpen != null;
  }

  int _getActiveFiltersCount() {
    int count = 0;
    if (_currentFilters.categoryId != null) count++;
    if (_currentFilters.maxDistance != null) count++;
    if (_currentFilters.minRating != null) count++;
    if (_currentFilters.isOpen != null) count++;
    return count;
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
          action: SnackBarAction(
            label: 'Tentar novamente',
            textColor: AppColors.surface,
            onPressed: () => _performSearch(reset: true),
          ),
        ),
      );
    }
  }
}

/// Extensão para SearchFilters
extension SearchFiltersExtension on SearchFilters {
  Map<String, dynamic> toMap() {
    return {
      'categoryId': categoryId,
      'maxDistance': maxDistance,
      'minRating': minRating,
      'isOpen': isOpen,
      'latitude': latitude,
      'longitude': longitude,
      'sortBy': sortBy,
    };
  }
  
  static SearchFilters fromMap(Map<String, dynamic> map) {
    return SearchFilters(
      categoryId: map['categoryId'],
      maxDistance: map['maxDistance']?.toDouble(),
      minRating: map['minRating']?.toDouble(),
      isOpen: map['isOpen'],
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      sortBy: map['sortBy'],
    );
  }
}
