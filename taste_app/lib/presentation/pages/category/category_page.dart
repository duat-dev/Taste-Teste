import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../domain/entities/category.dart';
import '../../../data/models/restaurant_model.dart';
import '../../../data/repositories/restaurant_repository.dart';
import '../../../core/di/injection_container.dart';
import '../../providers/category_provider.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/enhanced_error_widget.dart';
import '../../widgets/restaurant_card.dart';
import '../../widgets/empty_state_widget.dart';

/// Página de exploração por categoria temática
class CategoryPage extends ConsumerStatefulWidget {
  final String categoryId;
  final String? categoryName;

  const CategoryPage({
    super.key,
    required this.categoryId,
    this.categoryName,
  });

  @override
  ConsumerState<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends ConsumerState<CategoryPage>
    with TickerProviderStateMixin {
  final RestaurantRepository _restaurantRepository = getIt<RestaurantRepository>();
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  List<RestaurantModel> _restaurants = [];
  String _sortBy = 'rating'; // rating, distance, name, price
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      await _loadRestaurants();
    } catch (e) {
      // Error handling can be done in _loadRestaurants if needed
    }
  }



  Future<void> _loadRestaurants() async {
    try {
      _restaurants = await _restaurantRepository.getRestaurantsByCategory(
        widget.categoryId,
      );
      _sortRestaurants();
    } catch (e) {
      debugPrint('Erro ao carregar restaurantes: $e');
    }
  }



  void _sortRestaurants() {
    switch (_sortBy) {
      case 'rating':
        _restaurants.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'name':
        _restaurants.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'distance':
        // TODO: Implementar ordenação por distância quando disponível
        break;
      case 'price':
        // TODO: Implementar ordenação por preço quando disponível
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryAsync = ref.watch(categoryByIdProvider(widget.categoryId));
    final activeCategoriesAsync = ref.watch(activeCategoriesProvider);

    return categoryAsync.when(
      loading: () => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(widget.categoryName ?? 'Categoria'),
        ),
        body: LoadingWidget.fullScreen(
          message: 'Carregando categoria...',
        ),
      ),
      error: (error, stack) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(widget.categoryName ?? 'Categoria'),
        ),
        body: EnhancedErrorWidget(
          title: 'Erro ao carregar categoria',
          message: error.toString(),
          onRetry: () => ref.invalidate(categoryByIdProvider(widget.categoryId)),
          errorType: ErrorType.general,
        ),
      ),
      data: (category) => Scaffold(
        backgroundColor: AppColors.background,
        body: NestedScrollView(
          controller: _scrollController,
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            _buildSliverAppBar(category),
          ],
          body: Column(
            children: [
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRestaurantsTab(),
                    _buildExploreTab(category, activeCategoriesAsync),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(Category category) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: Color(int.parse(category.color.replaceFirst('#', '0xFF'))),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          category.name,
          style: AppTextStyles.headingMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(int.parse(category.color.replaceFirst('#', '0xFF'))),
                Color(int.parse(category.color.replaceFirst('#', '0xFF'))).withOpacity(0.8),
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 40),
                Icon(
                  _getCategoryIconFromString(category.icon),
                  size: 60,
                  color: Colors.white,
                ),
                SizedBox(height: 8),
                Text(
                  '${_restaurants.length} restaurantes',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.filter_list, color: Colors.white),
          onPressed: () {
            setState(() {
              _showFilters = !_showFilters;
            });
          },
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppColors.surface,
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textLight,
        indicatorColor: AppColors.primary,
        tabs: const [
          Tab(text: 'Restaurantes'),
          Tab(text: 'Explorar'),
        ],
      ),
    );
  }

  Widget _buildRestaurantsTab() {
    return Column(
      children: [
        if (_showFilters) _buildFiltersSection(),
        Expanded(
          child: _restaurants.isEmpty
              ? EmptyStateWidget(
                  emoji: '🍽️',
                  title: 'Nenhum restaurante encontrado',
                  subtitle: 'Não há restaurantes nesta categoria ainda.',
                  actionText: 'Explorar outras categorias',
                  onActionTap: () {
                    _tabController.animateTo(1);
                  },
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                    itemCount: _restaurants.length,
                    itemBuilder: (context, index) {
                      final restaurant = _restaurants[index];
                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppDimensions.paddingMedium,
                        ),
                        child: RestaurantCard(
                          restaurant: restaurant,
                          onTap: () {
                            context.push('/restaurant/${restaurant.id}');
                          },
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ordenar por:',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildSortChip('Avaliação', 'rating'),
              _buildSortChip('Nome', 'name'),
              _buildSortChip('Distância', 'distance'),
              _buildSortChip('Preço', 'price'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, String value) {
    final isSelected = _sortBy == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _sortBy = value;
            _sortRestaurants();
          });
        }
      },
      selectedColor: AppColors.primary.withOpacity(0.2),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textDark,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildExploreTab(Category category, AsyncValue<List<Category>> activeCategoriesAsync) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Categorias Relacionadas'),
          SizedBox(height: AppDimensions.paddingMedium),
          _buildRelatedCategories(activeCategoriesAsync),
          SizedBox(height: AppDimensions.paddingLarge),
          _buildSectionTitle('Dicas da Categoria'),
          SizedBox(height: AppDimensions.paddingMedium),
          _buildCategoryTips(category),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.headingSmall.copyWith(
        color: AppColors.textDark,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildRelatedCategories(AsyncValue<List<Category>> activeCategoriesAsync) {
    return activeCategoriesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, stack) => Center(
        child: Text('Erro ao carregar categorias: $error'),
      ),
      data: (categories) {
        final relatedCategories = categories
            .where((cat) => cat.id != widget.categoryId)
            .take(6)
            .toList();
        
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            crossAxisSpacing: AppDimensions.paddingMedium,
            mainAxisSpacing: AppDimensions.paddingMedium,
          ),
          itemCount: relatedCategories.length,
          itemBuilder: (context, index) {
            final category = relatedCategories[index];
            return _buildCategoryCard(category);
          },
        );
      },
    );
  }

  Widget _buildCategoryCard(Category category) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        onTap: () {
          context.pushReplacement('/category/${category.id}');
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(int.parse(category.color.replaceFirst('#', '0xFF'))),
                Color(int.parse(category.color.replaceFirst('#', '0xFF'))).withOpacity(0.8),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getCategoryIconFromString(category.icon),
                size: 32,
                color: Colors.white,
              ),
              SizedBox(height: 8),
              Text(
                category.name,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTips(Category category) {
    final tips = _getCategoryTips(category);
    return Column(
      children: tips.map((tip) => _buildTipCard(tip)).toList(),
    );
  }

  Widget _buildTipCard(Map<String, String> tip) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingMedium),
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
                _getTipIcon(tip['type']!),
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
                    tip['title']!,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    tip['description']!,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIconFromString(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'pizza':
        return Icons.local_pizza;
      case 'burger':
        return Icons.lunch_dining;
      case 'coffee':
        return Icons.local_cafe;
      case 'dessert':
        return Icons.cake;
      case 'healthy':
        return Icons.eco;
      case 'asian':
        return Icons.ramen_dining;
      case 'mexican':
        return Icons.local_dining;
      case 'italian':
        return Icons.restaurant;
      default:
        return Icons.restaurant;
    }
  }

  IconData _getTipIcon(String type) {
    switch (type) {
      case 'time':
        return Icons.access_time;
      case 'price':
        return Icons.attach_money;
      case 'quality':
        return Icons.star;
      case 'location':
        return Icons.location_on;
      default:
        return Icons.info;
    }
  }

  List<Map<String, String>> _getCategoryTips(Category category) {
    // Dicas específicas baseadas na categoria
    switch (category.name.toLowerCase()) {
      case 'pizza':
        return [
          {
            'type': 'time',
            'title': 'Melhor horário',
            'description': 'Pizzarias costumam ser mais movimentadas entre 19h e 22h',
          },
          {
            'type': 'quality',
            'title': 'Dica de qualidade',
            'description': 'Procure por pizzarias com forno a lenha para sabor autêntico',
          },
        ];
      case 'burger':
        return [
          {
            'type': 'price',
            'title': 'Economia',
            'description': 'Muitas hamburguerias oferecem promoções no meio da semana',
          },
          {
            'type': 'quality',
            'title': 'Freshness',
            'description': 'Prefira lugares que fazem o hambúrguer na hora',
          },
        ];
      default:
        return [
          {
            'type': 'time',
            'title': 'Horário de pico',
            'description': 'Evite horários de almoço (12h-14h) e jantar (19h-21h) para menos espera',
          },
          {
            'type': 'quality',
            'title': 'Avaliações',
            'description': 'Verifique as avaliações recentes para garantir qualidade',
          },
        ];
    }
  }
}
