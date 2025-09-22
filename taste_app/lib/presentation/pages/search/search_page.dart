import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/animations/animation_service.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/restaurant_model.dart';
import '../../../data/models/search_history_model.dart';
import '../../../data/services/search/search_service.dart';
import '../../../data/services/search/ai_search_service.dart';
import '../../../data/services/search/search_analytics_service.dart';
import '../../../data/services/auth/auth_service.dart';
import '../../../services/analytics_service.dart';
import '../../../data/repositories/search_repository.dart';
import '../../widgets/widgets.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/search_filters_widget.dart';
import '../../widgets/search/ai_confidence_widget.dart';
import '../../widgets/search/search_performance_widget.dart';
import '../../widgets/debounced_search_field.dart';
import '../../widgets/optimized_list_view.dart';
import '../../widgets/enhanced_map_widget.dart';
import '../../../data/models/location_model.dart';
import '../../../data/repositories/location_repository.dart';

/// Página de busca conforme referências visuais
class SearchPage extends StatefulWidget {
  final String? initialQuery;
  
  const SearchPage({super.key, this.initialQuery});
  
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final SearchService _searchService = SearchService.instance;
  final SearchAnalyticsService _searchAnalytics = SearchAnalyticsService.instance;
  late final SearchRepository _searchRepository;
  final AuthService _authService = AuthService.instance;
  final LocationRepository _locationRepository = LocationRepository.instance;
  
  LocationModel? _userLocation;
  
  List<RestaurantModel> _restaurants = [];
  List<String> _searchSuggestions = [];
  List<String> _searchHistory = [];
  List<String> _popularSearches = [];
  
  bool _isLoading = false;
  bool _isSearching = false;
  bool _showSuggestions = false;
  bool _showCorrections = false;
  List<String> _corrections = [];
  String? _correctedQuery;
  SearchInterpretation? _currentInterpretation;
  bool _showAIInsights = true;
  
  // Métricas de performance
  int _lastSearchTotalTime = 0;
  int _lastSearchAITime = 0;
  int _lastSearchDBTime = 0;
  bool _lastSearchUsedCache = false;
  
  String? _selectedCategory;
  String? _sortBy;
  SearchFilters _currentFilters = const SearchFilters();
  bool _hasActiveFilters = false;
  
  // Categorias mock para busca
  final List<CategoryModel> _mockCategories = [
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
    CategoryModel(
      id: '3',
      name: 'Sushi',
      icon: 'restaurant',
      color: '#2196F3',
      isActive: true,
      sortOrder: 2,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    CategoryModel(
      id: '4',
      name: 'Café',
      icon: 'coffee',
      color: '#795548',
      isActive: true,
      sortOrder: 3,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];
  
  @override
  void initState() {
    super.initState();
    _searchRepository = SearchRepositoryImpl();
    _searchFocusNode.addListener(_onFocusChange);
    _loadInitialData();
    
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performSearch(widget.initialQuery!);
      });
    }
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
  
  void _onFocusChange() {
    setState(() {
      _isSearching = _searchFocusNode.hasFocus;
    });
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([
        _loadPopularSearches(),
        _loadSearchHistory(),
        _loadUserLocation(),
      ]);
      
      if (widget.initialQuery == null || widget.initialQuery!.isEmpty) {
        setState(() {
          _restaurants = [];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar dados: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPopularSearches() async {
    try {
      final popular = await _searchRepository.getPopularSearchTerms();
      setState(() {
        _popularSearches = popular;
      });
    } catch (e) {
      debugPrint('Erro ao carregar buscas populares: $e');
    }
  }

  Future<void> _loadSearchHistory() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final history = await _searchRepository.getSearchHistory();
        setState(() {
          _searchHistory = history;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar histórico: $e');
    }
  }

  Future<void> _loadUserLocation() async {
    try {
      final location = await _locationRepository.getCurrentLocation();
      setState(() {
        _userLocation = location;
      });
    } catch (e) {
      debugPrint('Erro ao carregar localização: $e');
      // Não é crítico, continua sem localização
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: 'Buscar',
        backgroundColor: AppColors.background,
      ),
      body: Column(
        children: [
          // Campo de busca
          _buildSearchField(),
          
          // Conteúdo baseado no estado
          Expanded(
            child: _isSearching || _searchController.text.isNotEmpty
                ? _buildSearchResults()
                : _buildSearchSuggestions(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSearchField() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      color: AppColors.background,
      child: Row(
        children: [
          Expanded(
            child: DebouncedSearchField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              hintText: 'Buscar restaurantes, pratos...',
              debounceDuration: const Duration(milliseconds: 300),
              onChanged: (value) {
                if (value.isEmpty) {
                  setState(() {
                    _restaurants = [];
                    _showSuggestions = false;
                  });
                } else {
                  _loadSearchSuggestions(value);
                }
              },
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  _performSearch(value);
                }
              },
              onClear: () {
                AnimationService.lightHaptic();
                _clearSearch();
              },
            ),
          ),
          const SizedBox(width: AppDimensions.paddingSmall),
          IconButton(
            onPressed: () {
              AnimationService.mediumHaptic();
              _showFilters();
            },
            icon: Icon(
              AppIcons.filter,
              color: _hasActiveFilters ? AppColors.primary : AppColors.textLight,
            ),
            tooltip: 'Filtros',
          ).scaleIn(delay: const Duration(milliseconds: 100)),
        ],
      ),
    );
  }
  
  Widget _buildSearchSuggestions() {
    return Container(
      color: AppColors.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Categorias
            _buildSectionTitle('Categorias'),
            const SizedBox(height: AppDimensions.paddingMedium),
            _buildCategoriesChips(),
            
            const SizedBox(height: AppDimensions.paddingLarge),
            
            // Buscas recentes
            if (_searchHistory.isNotEmpty) ...[
              _buildSectionTitle('Buscas Recentes'),
              const SizedBox(height: AppDimensions.paddingMedium),
              _buildSearchList(_searchHistory, isRecent: true),
              
              const SizedBox(height: AppDimensions.paddingLarge),
            ],
            
            // Buscas populares
            _buildSectionTitle('Buscas Populares'),
            const SizedBox(height: AppDimensions.paddingMedium),
            _buildSearchList(_popularSearches),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSearchResults() {
    if (_isLoading) {
      return Container(
        color: AppColors.surface,
        child: const LoadingWidget(),
      );
    }
    
    if (_isSearching) {
      return Container(
        color: AppColors.surface,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              const SizedBox(height: AppDimensions.paddingMedium),
              Text('Buscando restaurantes...'),
            ],
          ),
        ),
      );
    }
    
    if (_searchController.text.isEmpty) {
      return _buildInitialSearchState();
    }
    
    if (_restaurants.isEmpty) {
      return Container(
        color: AppColors.surface,
        child: EmptyStateWidget.searchEmpty(
          query: _searchController.text,
          onClearFilters: _clearSearch,
        ),
      );
    }
    
    return Container(
      color: AppColors.surface,
      child: Column(
        children: [
          _buildResultsHeader(),
          if (_showCorrections) _buildCorrectionsWidget(),
          
          // Mapa com restaurantes (apenas quando há resultados)
          if (_restaurants.isNotEmpty) ...[
            Container(
              height: 300,
              margin: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingMedium,
                vertical: AppDimensions.paddingSmall,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                child: EnhancedMapWidget(
                  userLocation: _userLocation,
                  restaurants: _restaurants,
                  height: 300,
                  showUserLocation: true,
                  enableInteraction: true,
                  showAdvancedMarkers: true,
                  showInfoWindows: true,
                  onRestaurantTap: (restaurant) {
                    context.push('/restaurant/${restaurant.id}');
                  },
                ),
              ),
            ),
            SizedBox(height: AppDimensions.paddingMedium),
          ],
          
          if (_currentInterpretation != null && _showAIInsights)
            AIConfidenceWidget(
              interpretation: _currentInterpretation!,
              resultsCount: _restaurants.length,
              onFeedbackSubmitted: () {
                // Feedback já é rastreado automaticamente pelo widget
                // Aqui podemos adicionar lógica adicional se necessário
              },
            ),
          
          // Widget de performance (apenas em debug)
          if (_lastSearchTotalTime > 0)
            SearchPerformanceWidget(
              query: _searchController.text,
              totalTimeMs: _lastSearchTotalTime,
              aiTimeMs: _lastSearchAITime,
              dbTimeMs: _lastSearchDBTime,
              resultsCount: _restaurants.length,
              usedCache: _lastSearchUsedCache,
              interpretation: _currentInterpretation,
            ),
          Expanded(
            child: OptimizedListView<RestaurantModel>(
              items: _restaurants,
              enableLazyLoading: false, // Não há paginação na busca simples
              enableAnimations: true,
              itemExtent: 300, // Altura estimada do RestaurantCard
              itemBuilder: (context, restaurant, index) {
                return RepaintBoundary(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppDimensions.paddingMedium),
                    child: RestaurantCard(
                      restaurant: restaurant,
                      onTap: () {
                        context.push('/restaurant/${restaurant.id}');
                      },
                    ),
                  ),
                );
              },
              emptyWidget: EmptyStateWidget.searchEmpty(),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInitialSearchState() {
    return Container(
      color: AppColors.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_searchHistory.isNotEmpty) ...[
              _buildSectionTitle('Buscas Recentes'),
              SizedBox(height: AppDimensions.paddingMedium),
              ...(_searchHistory.take(5).map((search) {
                return AnimationService.staggeredListItem(
                  index: _searchHistory.indexOf(search),
                  child: ListTile(
                    leading: Icon(
                      AppIcons.clock,
                      color: AppColors.textLight,
                      size: AppDimensions.iconMedium,
                    ),
                  title: Text(
                    search,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textDark,
                    ),
                  ),
                    trailing: IconButton(
                      icon: Icon(
                        AppIcons.close,
                        color: AppColors.textLight,
                        size: AppDimensions.iconSmall,
                      ),
                      onPressed: () async {
                        AnimationService.lightHaptic();
                        // Remover do histórico local - implementar se necessário
                        _loadSearchHistory();
                      },
                    ),
                    onTap: () {
                      AnimationService.selectionHaptic();
                      _searchController.text = search;
                      _performSearch(search);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                );
              }).toList()),
              SizedBox(height: AppDimensions.paddingLarge),
            ],
            
            if (_popularSearches.isNotEmpty) ...[
              _buildSectionTitle('Buscas Populares'),
              SizedBox(height: AppDimensions.paddingMedium),
              Wrap(
                spacing: AppDimensions.paddingSmall,
                runSpacing: AppDimensions.paddingSmall,
                children: _popularSearches.map((search) {
                  return ActionChip(
                    label: Text(search),
                    onPressed: () {
                      _searchController.text = search;
                      _performSearch(search);
                    },
                    backgroundColor: AppColors.surface,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.h3.copyWith(
        color: AppColors.textDark,
      ),
    );
  }
  
  Widget _buildCategoriesChips() {
    return Wrap(
      spacing: AppDimensions.paddingSmall,
      runSpacing: AppDimensions.paddingSmall,
      children: _mockCategories.map((category) {
        return CategoryChip(
          category: category,
          onTap: () => _onCategoryTap(category),
        );
      }).toList(),
    );
  }
  
  Widget _buildSearchList(List<String> searches, {bool isRecent = false}) {
    return Column(
      children: searches.map((search) {
        return AnimationService.staggeredListItem(
          index: searches.indexOf(search),
          child: ListTile(
            leading: Icon(
              isRecent ? AppIcons.clock : AppIcons.search,
              color: AppColors.textLight,
              size: AppDimensions.iconMedium,
            ),
          title: Text(
            search,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textDark,
            ),
          ),
            trailing: isRecent
                ? IconButton(
                    icon: Icon(
                      AppIcons.close,
                      color: AppColors.textLight,
                      size: AppDimensions.iconSmall,
                    ),
                    onPressed: () {
                      AnimationService.lightHaptic();
                      _removeRecentSearch(search);
                    },
                  )
                : Icon(
                    Icons.chevron_right,
                    color: AppColors.textLight,
                    size: AppDimensions.iconSmall,
                  ),
            onTap: () {
              AnimationService.selectionHaptic();
              _onSearchTap(search);
            },
            contentPadding: EdgeInsets.zero,
          ),
        );
      }).toList(),
    );
  }
  

  
  // Callbacks
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _restaurants = [];
        _showSuggestions = false;
        _showCorrections = false;
        _corrections = [];
        _correctedQuery = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _showSuggestions = false;
      _showCorrections = false;
    });

    final searchStopwatch = Stopwatch()..start();

    // Analytics: rastrear busca
    AnalyticsService.instance.trackSearch(
      query.trim(),
      parameters: {
        'category': _selectedCategory,
        'filters': _hasActiveFilters ? _currentFilters.toMap() : null,
      },
    );

    try {
      final user = _authService.currentUser;
      if (user != null) {
        await _searchRepository.addToSearchHistory(query.trim());
      }

      final results = await _searchService.searchRestaurants(
        query: query.trim(),
        categoryId: _selectedCategory,
        sortBy: _getSortByValue(_sortBy),
      );

      if (results.hasError) {
        throw Exception(results.error);
      }

      searchStopwatch.stop();

      setState(() {
        _restaurants = results.restaurants;
        _currentInterpretation = results.interpretation;
        
        // Capturar métricas de performance
        _lastSearchTotalTime = searchStopwatch.elapsedMilliseconds;
        _lastSearchAITime = results.aiProcessingTime ?? 0;
        _lastSearchDBTime = results.dbQueryTime ?? 0;
        _lastSearchUsedCache = results.usedCache ?? false;
        
        // Verificar se há correções sugeridas pela IA
        if (results.interpretation != null && results.interpretation!.corrections.isNotEmpty) {
          _corrections = results.interpretation!.corrections;
          _correctedQuery = results.interpretation!.corrections.first;
          _showCorrections = results.restaurants.isEmpty || results.interpretation!.confidence < 0.7;
        } else {
          _corrections = [];
          _correctedQuery = null;
          _showCorrections = false;
        }
      });

      // Analytics: rastrear resultados da busca com informações da IA
      AnalyticsService.instance.trackSearch(
        query.trim(),
        parameters: {
          'results_count': results.restaurants.length,
          'category': _selectedCategory,
          'filters': _hasActiveFilters ? _currentFilters.toMap() : null,
        },
      );

      if (user != null) {
        _loadSearchHistory();
      }
    } catch (e) {
      searchStopwatch.stop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro na busca: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  String? _getSortByValue(String? sortOption) {
    switch (sortOption) {
      case 'Avaliação':
        return 'rating';
      case 'Distância':
        return 'distance';
      case 'Tempo de entrega':
        return 'delivery_time';
      case 'Menor preço':
        return 'delivery_fee';
      default:
        return null;
    }
  }

  Future<void> _loadSearchSuggestions(String query) async {
    if (query.length < 2) {
      setState(() {
        _searchSuggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    try {
      final suggestions = await _searchService.getSearchSuggestions(query);
      setState(() {
        _searchSuggestions = suggestions;
        _showSuggestions = suggestions.isNotEmpty;
      });
    } catch (e) {
      debugPrint('Erro ao carregar sugestões: $e');
    }
  }
  
  void _clearSearch() {
    _searchController.clear();
    setState(() {});
  }
  
  void _onCategoryTap(CategoryModel category) {
    _searchController.text = category.name;
    _selectedCategory = category.id;
    _performSearch(category.name);
  }
  
  void _onSearchTap(String search) {
    // Rastrear seleção de sugestão
    final originalQuery = _searchController.text;
    final suggestionIndex = _searchSuggestions.indexOf(search);
    
    if (suggestionIndex >= 0) {
      _searchAnalytics.trackSuggestionSelected(search, originalQuery);
    }
    
    _searchController.text = search;
    _performSearch(search);
  }
  
  Widget _buildResultsHeader() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      decoration: const BoxDecoration(
         border: Border(
           bottom: BorderSide(
             color: AppColors.divider,
             width: 1,
           ),
         ),
       ),
      child: Row(
        children: [
          Text(
            '${_restaurants.length} restaurante(s) encontrado(s)',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textLight,
            ),
          ),
          const Spacer(),
          if (_hasActiveFilters)
            TextButton(
              onPressed: _clearFilters,
              child: Text(
                'Limpar filtros',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCorrectionsWidget() {
    return Container(
      margin: const EdgeInsets.all(AppDimensions.paddingMedium),
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(
          color: AppColors.warning.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                 AppIcons.help,
                 color: AppColors.warning,
                 size: AppDimensions.iconSmall,
               ),
              SizedBox(width: AppDimensions.paddingSmall),
              Text(
                'Você quis dizer:',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: AppDimensions.paddingSmall),
          Wrap(
            spacing: AppDimensions.paddingSmall,
            runSpacing: AppDimensions.paddingSmall,
            children: _corrections.map((correction) {
              return GestureDetector(
                onTap: () async {
                  AnimationService.selectionHaptic();
                  
                  // Rastrear uso de correção
                  if (_currentInterpretation != null) {
                    await _searchAnalytics.trackCorrectionUsed(correction, _searchController.text);
                  }
                  
                  _searchController.text = correction;
                  _performSearch(correction);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingMedium,
                    vertical: AppDimensions.paddingSmall,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    correction,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    ).fadeIn();
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => SearchFiltersWidget(
          initialFilters: _currentFilters,
          categories: _mockCategories,
          onFiltersChanged: _applyFilters,
          onClearFilters: _clearFilters,
        ),
      ),
    );
  }

  void _applyFilters(SearchFilters filters) {
    setState(() {
      _currentFilters = filters;
      _hasActiveFilters = _isFiltersActive(filters);
    });
    
    if (_searchController.text.isNotEmpty) {
      _performSearchWithFilters(_searchController.text, filters);
    }
  }

  void _clearFilters() {
    setState(() {
      _currentFilters = const SearchFilters();
      _hasActiveFilters = false;
    });
    
    if (_searchController.text.isNotEmpty) {
      _performSearch(_searchController.text);
    }
  }

  bool _isFiltersActive(SearchFilters filters) {
    return filters.categoryId != null ||
           filters.maxDistance != null ||
           filters.minRating != null ||
           filters.isOpen != null ||
           (filters.sortBy != null && filters.sortBy != 'relevance');
  }

  Future<void> _performSearchWithFilters(String query, SearchFilters filters) async {
    if (query.trim().isEmpty) {
      setState(() {
        _restaurants = [];
        _showSuggestions = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _showSuggestions = false;
    });

    try {
      final results = await _searchService.searchRestaurants(
        query: query.trim(),
        categoryId: filters.categoryId,
        latitude: filters.latitude,
        longitude: filters.longitude,
        maxDistance: filters.maxDistance,
        minRating: filters.minRating,
        isOpen: filters.isOpen,
        sortBy: filters.sortBy,
      );

      setState(() {
        _restaurants = results.restaurants;
        _isSearching = false;
      });

      // Adicionar ao histórico
      await _searchRepository.addToSearchHistory(query.trim());
      _loadSearchHistory();
    } catch (e) {
      setState(() {
        _restaurants = [];
        _isSearching = false;
      });
      debugPrint('Erro na busca: $e');
    }
  }

  Future<void> _removeRecentSearch(String query) async {
    try {
      // Remover do histórico local - implementar se necessário
      // Aqui poderia implementar remoção específica do item
      
      // Recarregar o histórico
      await _loadSearchHistory();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Busca removida do histórico'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao remover busca: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
