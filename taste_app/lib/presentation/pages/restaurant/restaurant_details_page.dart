import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/utils/navigation_helper.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../data/models/restaurant_model.dart';
import '../../../data/models/review_model.dart';
import '../../../data/models/menu_item_model.dart';
import '../../../data/repositories/review_repository.dart';
import '../../../data/repositories/menu_repository.dart';
import '../../../data/repositories/restaurant_repository.dart';
import '../../../core/di/injection_container.dart';
import '../../widgets/widgets.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/enhanced_error_widget.dart';
import '../../widgets/favorite_button.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/review_card.dart';
import '../../widgets/rating_widget.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/menu_item_card.dart';
import '../../widgets/reusable_map_view.dart';
import '../../providers/cart_provider.dart';
import '../../../core/enums/delivery_type.dart';
import '../../widgets/connectivity_banner.dart';
import '../../widgets/enhanced_error_widget.dart';
import '../../../data/services/auth/auth_service.dart';

/// Página de detalhes do restaurante
class RestaurantDetailsPage extends ConsumerStatefulWidget {
  final String restaurantId;
  final RestaurantModel? restaurant;

  const RestaurantDetailsPage({
    super.key,
    required this.restaurantId,
    this.restaurant,
  });

  @override
  ConsumerState<RestaurantDetailsPage> createState() => _RestaurantDetailsPageState();
}

class _RestaurantDetailsPageState extends ConsumerState<RestaurantDetailsPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  final PageController _imagePageController = PageController();
  
  final ReviewRepository _reviewRepository = ReviewRepository();
  final MenuRepository _menuRepository = MenuRepository();
  final RestaurantRepository _restaurantRepository = getIt<RestaurantRepository>();

  RestaurantModel? _restaurant;
  List<ReviewModel> _reviews = [];
  List<MenuCategoryModel> _menuCategories = [];
  bool _isLoading = true;
  bool _showAppBarTitle = false;
  int _currentImageIndex = 0;
  String? _error;
  bool _isLoadingMenu = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _restaurant = widget.restaurant;
    _scrollController.addListener(_onScroll);
    _loadRestaurantDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _imagePageController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final showTitle = _scrollController.offset > 200;
    if (showTitle != _showAppBarTitle) {
      setState(() {
        _showAppBarTitle = showTitle;
      });
    }
  }

  Future<void> _loadRestaurantDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Se não temos o restaurante, buscar pelos dados
      if (_restaurant == null) {
        final restaurant = await _restaurantRepository.getRestaurantById(widget.restaurantId);
        if (restaurant == null) {
          throw Exception('Restaurante não encontrado');
        }
        _restaurant = restaurant;
      }

      // Carregar reviews e menu
      await Future.wait([
        _loadReviews(),
        _loadMenu(),
      ]);
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadReviews() async {
    try {
      // Usar método combinado que busca local e servidor
      final reviews = await _reviewRepository.getReviewsByRestaurantCombined(widget.restaurantId);
      
      setState(() {
        _reviews = reviews;
      });
    } catch (e) {
      // Log do erro mas não quebra o carregamento da página
      debugPrint('Erro ao carregar avaliações: $e');
      setState(() {
        _reviews = [];
      });
    }
  }

  Future<void> _loadMenu() async {
    try {
      setState(() {
        _isLoadingMenu = true;
      });
      
      final menuCategories = await _menuRepository.getMenuByRestaurant(widget.restaurantId);
      
      setState(() {
        _menuCategories = menuCategories;
        _isLoadingMenu = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar cardápio: $e');
      setState(() {
        _menuCategories = [];
        _isLoadingMenu = false;
      });
    }
  }

  void _onFavoriteToggle() {
    // Mostrar feedback quando favorito é alterado
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Favorito atualizado'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showRatingDialog() {
    if (_restaurant == null) return;
    
    showDialog(
      context: context,
      builder: (context) => RatingDialog(
        restaurantName: _restaurant!.name,
        onSubmit: _submitReview,
      ),
    );
  }

  Future<void> _submitReview(int rating, String comment) async {
    try {
      // Validar se usuário está autenticado
      final userId = AuthService.instance.userId;
      if (userId == null || userId == 'anonymous') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Faça login para enviar uma avaliação'),
              backgroundColor: AppColors.warning,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Mostrar loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enviando avaliação...'),
          duration: Duration(seconds: 1),
        ),
      );

      // Criar nova avaliação
      final newReview = ReviewModel(
        id: '', // Será gerado no repositório
        userId: userId,
        restaurantId: widget.restaurantId,
        userName: AuthService.instance.userEmail?.split('@').first ?? 'Usuário',
        userAvatar: null,
        rating: rating,
        comment: comment.isNotEmpty ? comment : null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isVerified: false,
        helpfulCount: 0,
        replies: [],
      );

      // Salvar no repositório (local e servidor)
      final savedReview = await _reviewRepository.createReview(newReview);

      // Atualizar lista local imediatamente
      setState(() {
        _reviews = [savedReview, ..._reviews];
      });

      // Mostrar sucesso
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Avaliação enviada com sucesso!'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao enviar avaliação: $e');
      
      // Mostrar erro mais específico
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar avaliação. Tente novamente.'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Tentar novamente',
              textColor: Colors.white,
              onPressed: () => _showRatingDialog(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _shareRestaurant() async {
    if (_restaurant == null) return;
    
    final text = 'Confira o ${_restaurant!.name}! '
        'Avaliação: ${_restaurant!.rating.toStringAsFixed(1)} ⭐\n'
        'Entrega: ${_restaurant!.deliveryTime} min\n'
        'https://taste.app/restaurant/${_restaurant!.id}';
    
    await Share.share(text, subject: 'Restaurante ${_restaurant!.name}');
  }

  Future<void> _callRestaurant() async {
    if (_restaurant?.phone == null) {
      _showErrorSnackBar('Telefone não disponível');
      return;
    }
    
    final phoneUrl = Uri.parse('tel:${_restaurant!.phone}');
    if (await canLaunchUrl(phoneUrl)) {
      await launchUrl(phoneUrl);
    } else {
      _showErrorSnackBar('Não foi possível fazer a ligação');
    }
  }

  Future<void> _getDirections() async {
    if (_restaurant?.latitude == null || _restaurant?.longitude == null) {
      _showErrorSnackBar('Localização não disponível');
      return;
    }
    
    final mapsUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${_restaurant!.latitude},${_restaurant!.longitude}'
    );
    
    if (await canLaunchUrl(mapsUrl)) {
      await launchUrl(mapsUrl, mode: LaunchMode.externalApplication);
    } else {
      _showErrorSnackBar('Não foi possível abrir o mapa');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _makeOrder() {
    if (_restaurant == null) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.4,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimensions.radiusLarge),
          ),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: AppDimensions.paddingMedium),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Como você gostaria de fazer o pedido?',
                    style: AppTextStyles.headingMedium,
                  ),
                  SizedBox(height: AppDimensions.paddingLarge),
                  
                  // Opção Delivery
                  _buildOrderOption(
                    icon: Icons.delivery_dining,
                    title: 'Delivery',
                    subtitle: 'Entrega em ${_restaurant!.deliveryTime} min • Taxa: ${_restaurant!.deliveryFee == 0 ? 'Grátis' : 'R\$ ${_restaurant!.deliveryFee.toStringAsFixed(2)}'}',
                    onTap: () {
                      NavigationHelper.safeGoBack(context);
                      _startDeliveryOrder();
                    },
                  ),
                  
                  SizedBox(height: AppDimensions.paddingMedium),
                  
                  // Opção Retirada
                  _buildOrderOption(
                    icon: Icons.store,
                    title: 'Retirada',
                    subtitle: 'Retire no restaurante • Sem taxa de entrega',
                    onTap: () {
                      NavigationHelper.safeGoBack(context);
                      _startPickupOrder();
                    },
                  ),
                  
                  SizedBox(height: AppDimensions.paddingLarge),
                  
                  // Botão de cancelar
                  SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      text: 'Cancelar',
                      onPressed: () {
                        NavigationHelper.safeGoBack(context);
                      },
                      isOutlined: true,
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

  Widget _buildOrderOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.paddingMedium),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppDimensions.paddingSmall),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
              ),
              child: Icon(
                icon,
                color: AppColors.primary,
                size: AppDimensions.iconMedium,
              ),
            ),
            SizedBox(width: AppDimensions.paddingMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: AppDimensions.iconSmall,
              color: AppColors.textLight,
            ),
          ],
        ),
      ),
    );
  }

  void _startDeliveryOrder() {
    // Configurar tipo de entrega no carrinho
    final cartService = ref.read(cartServiceProvider);
    cartService.setDeliveryType(DeliveryType.delivery);
    
    // Navegar para o cardápio completo
    context.push('/restaurant/${_restaurant!.id}/menu');
  }

  void _startPickupOrder() {
    // Configurar tipo de retirada no carrinho
    final cartService = ref.read(cartServiceProvider);
    cartService.setDeliveryType(DeliveryType.pickup);
    
    // Navegar para o cardápio completo
    context.push('/restaurant/${_restaurant!.id}/menu');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: LoadingWidget(),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Erro'),
        ),
        body: ConnectivityBanner(
          child: _buildErrorContent(),
        ),
      );
    }

    if (_restaurant == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Não encontrado'),
        ),
        body: const ConnectivityBanner(
          child: EnhancedErrorWidget.notFound(
            title: 'Restaurante não encontrado',
            message: 'O restaurante que você está procurando não existe ou foi removido.',
          ),
        ),
      );
    }

    return Scaffold(
      body: ConnectivityBanner(
        child: NestedScrollView(
          controller: _scrollController,
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              _buildSliverAppBar(),
            ];
          },
          body: Column(
            children: [
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildReviewsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildErrorContent() {
    // Se estiver offline, tentar mostrar dados em cache
    if (ConnectivityService.instance.status == ConnectivityStatus.disconnected) {
      return EnhancedErrorWidget(
        title: 'Sem conexão',
        message: 'Não foi possível carregar os dados do restaurante',
        errorType: ErrorType.network,
        onRetry: _loadRestaurantDetails,
        enableAutoRetry: true,
        autoRetryDelay: const Duration(seconds: 5),
        maxRetryAttempts: 3,
      );
    }

    return EnhancedErrorWidget(
      title: 'Erro ao carregar restaurante',
      message: _error!,
      onRetry: _loadRestaurantDetails,
      errorType: ErrorType.general,
      enableAutoRetry: true,
    );
  }

  Widget _buildSliverAppBar() {
    final images = [_restaurant!.imageUrl].where((url) => url != null).cast<String>().toList();

    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: AppColors.primary,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: Colors.white,
        ),
        onPressed: () {
          NavigationHelper.safeGoBack(context);
        },
      ),
      title: _showAppBarTitle 
          ? Text(
              _restaurant!.name,
              style: AppTextStyles.headingMedium.copyWith(
                color: AppColors.surface,
              ),
            )
          : null,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: FavoriteButtonEnhanced(
            restaurant: _restaurant!,
            onFavoriteChanged: (isFavorite) => _onFavoriteToggle(),
            showLabel: false,
            showQuickActions: false,
            showFeedback: false,
          ),
        ),
        IconButton(
          onPressed: () => _shareRestaurant(),
          icon: Icon(
            Icons.share,
            color: AppColors.surface,
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _imagePageController,
              onPageChanged: (index) {
                setState(() {
                  _currentImageIndex = index;
                });
              },
              itemCount: images.length,
              itemBuilder: (context, index) {
                return Image.network(
                  images[index],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: AppColors.surface,
                      child: Icon(
                        Icons.image,
                        size: 64,
                        color: AppColors.textLight,
                      ),
                    );
                  },
                );
              },
            ),
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.3),
                  ],
                ),
              ),
            ),
            // Image indicators
            if (images.length > 1)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: images.asMap().entries.map((entry) {
                    return Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentImageIndex == entry.key
                            ? AppColors.surface
                : AppColors.surface.withOpacity(0.5),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
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
          Tab(text: 'Visão Geral'),
          Tab(text: 'Avaliações'),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Informações básicas
          _buildBasicInfo(),
          SizedBox(height: AppDimensions.paddingLarge),
          
          // Horário de funcionamento
          _buildOpeningHours(),
          SizedBox(height: AppDimensions.paddingLarge),
          
          // Localização
          _buildLocation(),
          SizedBox(height: AppDimensions.paddingLarge),
          
        ],
      ),
    );
  }

  Widget _buildBasicInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _restaurant!.name,
                style: AppTextStyles.h1,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingSmall,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: _restaurant!.isOpen ? AppColors.timeHighlight : AppColors.error,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
              ),
              child: Text(
                _restaurant!.isOpen ? 'Aberto' : 'Fechado',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.surface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: AppDimensions.paddingSmall),
        
        if (_restaurant!.description != null) ...[
          Text(
            _restaurant!.description!,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textLight,
            ),
          ),
          SizedBox(height: AppDimensions.paddingMedium),
        ],
        
        Row(
          children: [
            Icon(
              Icons.star,
              size: AppDimensions.iconSmall,
              color: AppColors.warning,
            ),
            SizedBox(width: 4),
            Text(
              _restaurant!.rating.toStringAsFixed(1),
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 4),
            Text(
              '(${_reviews.length} avaliações)',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textLight,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.access_time,
              size: AppDimensions.iconSmall,
              color: AppColors.textLight,
            ),
            SizedBox(width: 4),
            Text(
              '${_restaurant!.deliveryTime} min',
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOpeningHours() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Horário de Funcionamento',
          style: AppTextStyles.headingMedium,
        ),
        SizedBox(height: AppDimensions.paddingMedium),
        
        // Mock data - em produção viria do modelo
        ...[
          'Segunda a Sexta: 11:00 - 23:00',
          'Sábado: 11:00 - 00:00',
          'Domingo: 12:00 - 22:00',
        ].map((hour) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.paddingSmall),
            child: Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: AppDimensions.iconSmall,
                  color: AppColors.timeHighlight,
                ),
                SizedBox(width: AppDimensions.paddingSmall),
                Text(
                  hour,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.timeHighlight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildLocation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Localização',
          style: AppTextStyles.headingMedium,
        ),
        SizedBox(height: AppDimensions.paddingMedium),
        
        Row(
          children: [
            Icon(
              Icons.location_on,
              size: AppDimensions.iconSmall,
              color: AppColors.primary,
            ),
            SizedBox(width: AppDimensions.paddingSmall),
            Expanded(
              child: Text(
                _restaurant!.address ?? 'Endereço não informado',
                style: AppTextStyles.bodyMedium,
              ),
            ),
          ],
        ),
        
        SizedBox(height: AppDimensions.paddingMedium),
        
        // Mapa do restaurante
        if (_restaurant!.latitude != null && _restaurant!.longitude != null)
          ReusableMapView(
            height: 150,
            restaurants: [_restaurant!],
            userLocation: null, // TODO: Implementar localização do usuário
            enableInteraction: true,
            showUserLocation: false,
            showInfoWindows: false,
            showAdvancedMarkers: false,
            showMapControls: false,
            showMyLocationButton: false,
            showZoomControls: false,
            zoom: 15.0,
            onRestaurantTap: (restaurant) {
              // Já estamos na página do restaurante
            },
          )
        else
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              border: Border.all(color: AppColors.divider),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_off,
                    size: 48,
                    color: AppColors.textLight,
                  ),
                  SizedBox(height: AppDimensions.paddingSmall),
                  Text(
                    'Localização não disponível',
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDeliveryInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Informações de Entrega',
          style: AppTextStyles.headingMedium,
        ),
        SizedBox(height: AppDimensions.paddingMedium),
        
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                icon: Icons.local_shipping,
                title: 'Taxa de Entrega',
                value: _restaurant!.deliveryFee == 0 
                    ? 'Grátis' 
                    : 'R\$ ${_restaurant!.deliveryFee.toStringAsFixed(2)}',
              ),
            ),
            SizedBox(width: AppDimensions.paddingMedium),
            Expanded(
              child: _buildInfoCard(
                icon: Icons.access_time,
                title: 'Tempo de Entrega',
                value: '${_restaurant!.deliveryTime} min',
              ),
            ),
          ],
        ),
        
        SizedBox(height: AppDimensions.paddingMedium),
        
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                icon: Icons.attach_money,
                title: 'Pedido Mínimo',
                value: 'R\$ 15,00',
              ),
            ),
            SizedBox(width: AppDimensions.paddingMedium),
            Expanded(
              child: _buildInfoCard(
                icon: Icons.credit_card,
                title: 'Pagamento',
                value: 'Cartão, PIX, Dinheiro',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: AppDimensions.iconMedium,
            color: AppColors.primary,
          ),
          SizedBox(height: AppDimensions.paddingSmall),
          Text(
            title,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textLight,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTab() {
    if (_isLoadingMenu) {
      return const Center(
        child: LoadingWidget(),
      );
    }

    if (_menuCategories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 64,
              color: AppColors.textLight,
            ),
            SizedBox(height: AppDimensions.paddingMedium),
            Text(
              'Cardápio não disponível',
              style: AppTextStyles.headingMedium,
            ),
            SizedBox(height: AppDimensions.paddingSmall),
            Text(
              'Este restaurante ainda não\ncadastrou seu cardápio',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        
        // Lista de categorias do menu
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMedium),
            itemCount: _menuCategories.length,
            itemBuilder: (context, index) {
              final category = _menuCategories[index];
              
              return MenuCategorySection(
                category: category,
                onItemTap: _showMenuItemDetails,
                onAddToCart: _addToCart,
              );
            },
          ),
        ),
      ],
    );
  }

  void _showMenuItemDetails(MenuItemModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppDimensions.radiusLarge),
              ),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(
                    vertical: AppDimensions.paddingMedium,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Imagem
                        if (item.imageUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusMedium,
                            ),
                            child: Image.network(
                              item.imageUrl!,
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: double.infinity,
                                  height: 200,
                                  color: AppColors.surface,
                                  child: Icon(
                                    Icons.image,
                                    size: 64,
                                    color: AppColors.textLight,
                                  ),
                                );
                              },
                            ),
                          ),
                        
                        SizedBox(height: AppDimensions.paddingMedium),
                        
                        // Nome e preço
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: AppTextStyles.headingMedium,
                              ),
                            ),
                            Text(
                              item.formattedPrice,
                              style: AppTextStyles.headingMedium.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        
                        SizedBox(height: AppDimensions.paddingSmall),
                        
                        // Descrição
                        if (item.description != null)
                          Text(
                            item.description!,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textLight,
                            ),
                          ),
                        
                        SizedBox(height: AppDimensions.paddingMedium),
                        
                        // Alérgenos
                        if (item.allergens.isNotEmpty) ...[
                          Text(
                            'Alérgenos',
                            style: AppTextStyles.headingSmall,
                          ),
                          SizedBox(height: AppDimensions.paddingSmall),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: item.allergens.map((allergen) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusSmall,
                                  ),
                                  border: Border.all(
                                    color: AppColors.warning.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  allergen,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.warning,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          SizedBox(height: AppDimensions.paddingMedium),
                        ],
                        
                        // Disponibilidade
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.paddingSmall,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: item.isAvailable 
                                ? AppColors.success.withOpacity(0.1)
                                : AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusSmall,
                            ),
                          ),
                          child: Text(
                            item.isAvailable ? 'Disponível' : 'Indisponível',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: item.isAvailable 
                                  ? AppColors.success
                                  : AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        
                        SizedBox(height: AppDimensions.paddingLarge),
                        
                        // Botão adicionar
                        SizedBox(
                          width: double.infinity,
                          child: CustomButton(
                            text: 'Adicionar ao Carrinho',
                            onPressed: item.isAvailable 
                                ? () {
                                    NavigationHelper.safeGoBack(context);
                                    _addToCart(item);
                                  }
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _addToCart(MenuItemModel item) async {
    if (!item.isAvailable) {
      _showErrorSnackBar('Item não disponível');
      return;
    }
    
    try {
      final cartNotifier = ref.read(cartNotifierProvider.notifier);
      await cartNotifier.addItem(menuItem: item);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: AppColors.surface,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text('${item.name} adicionado ao carrinho'),
              ),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  context.push('/cart');
                },
                child: Text(
                  'Ver Carrinho',
                  style: TextStyle(color: AppColors.surface),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      _showErrorSnackBar('Erro ao adicionar item: $e');
    }
  }
  
  void _navigateToFullMenu() {
    if (_restaurant == null) return;
    
    // Navegar para página de cardápio completo
    context.push('/restaurant/${_restaurant!.id}/menu');
  }

  Widget _buildReviewsTab() {
    return Column(
      children: [
        // Header com estatísticas e botão de avaliar
        Container(
          padding: const EdgeInsets.all(AppDimensions.paddingMedium),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(
              bottom: BorderSide(color: AppColors.divider),
            ),
          ),
          child: Column(
            children: [
              if (_reviews.isNotEmpty) ...[
                // Estatísticas de avaliação
                _buildReviewStats(),
                SizedBox(height: AppDimensions.paddingMedium),
              ],
              // Botão para avaliar
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: 'Avaliar Restaurante',
                  onPressed: _showRatingDialog,
                  isOutlined: true,
                  icon: Icons.star_border,
                ),
              ),
            ],
          ),
        ),
        // Lista de avaliações
        Expanded(
          child: _reviews.isEmpty
              ? _buildEmptyReviews()
              : _buildReviewsList(),
        ),
      ],
    );
  }

  Widget _buildEmptyReviews() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.message,
            size: 64,
            color: AppColors.textLight,
          ),
          SizedBox(height: AppDimensions.paddingMedium),
          Text(
            'Nenhuma avaliação ainda',
            style: AppTextStyles.headingMedium,
          ),
          SizedBox(height: AppDimensions.paddingSmall),
          Text(
            'Seja o primeiro a avaliar este restaurante',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsList() {
    // Limitar a 5 reviews iniciais para melhor performance
    final displayReviews = _reviews.take(5).toList();
    final hasMoreReviews = _reviews.length > 5;
    
    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      itemCount: displayReviews.length + (hasMoreReviews ? 1 : 0),
      itemExtent: 200, // Altura estimada do ReviewCard
      itemBuilder: (context, index) {
        if (index < displayReviews.length) {
          final review = displayReviews[index];
          return RepaintBoundary(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.paddingMedium),
              child: ReviewCard(review: review),
            ),
          );
        } else {
          // Botão "Ver todas as avaliações"
          return RepaintBoundary(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.paddingMedium),
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: InkWell(
                  onTap: () {
                    context.push('/restaurant/${_restaurant!.id}/reviews');
                  },
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.visibility,
                        color: AppColors.primary,
                        size: AppDimensions.iconSmall,
                      ),
                      SizedBox(width: AppDimensions.paddingSmall),
                      Text(
                        'Ver todas as ${_reviews.length} avaliações',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildReviewStats() {
    if (_reviews.isEmpty) return const SizedBox.shrink();
    
    final averageRating = _restaurant!.rating;
    final totalReviews = _reviews.length;
    
    // Calcular distribuição de ratings
    final ratingDistribution = <int, int>{};
    for (final review in _reviews) {
      ratingDistribution[review.rating] = 
          (ratingDistribution[review.rating] ?? 0) + 1;
    }
    
    return DetailedRatingWidget(
      rating: averageRating,
      reviewCount: totalReviews,
      ratingDistribution: ratingDistribution,
      onTap: () {
        context.push('/restaurant/${_restaurant!.id}/reviews');
      },
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.divider),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Botões de ação rápida
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.phone,
                  label: 'Ligar',
                  onPressed: _callRestaurant,
                ),
              ),
              SizedBox(width: AppDimensions.paddingSmall),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.directions,
                  label: 'Como Chegar',
                  onPressed: _getDirections,
                ),
              ),
              SizedBox(width: AppDimensions.paddingSmall),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.share,
                  label: 'Compartilhar',
                  onPressed: _shareRestaurant,
                ),
              ),
            ],
          ),
          SizedBox(height: AppDimensions.paddingMedium),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppDimensions.paddingSmall,
          horizontal: AppDimensions.paddingSmall,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: AppDimensions.iconMedium,
              color: AppColors.primary,
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
