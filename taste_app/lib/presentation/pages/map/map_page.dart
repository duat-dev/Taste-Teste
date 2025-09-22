import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'dart:ui' as ui;
import 'dart:typed_data';

import '../../../core/config/advanced_marker_service.dart';
import '../../../core/services/balloon_marker_service.dart';
import '../../../core/utils/category_emoji_mapper.dart';
import '../../widgets/custom_web_marker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/restaurant_model.dart';
import '../../../data/models/location_model.dart';
import '../../providers/location_provider.dart';
import '../../providers/restaurant_provider.dart';
import '../../widgets/enhanced_map_widget.dart';

/// Data class for clustering results
class _ClusterItem {
  final List<RestaurantModel> restaurants;
  final double centerLat;
  final double centerLng;
  final bool isCluster;

  _ClusterItem({
    required this.restaurants,
    required this.centerLat,
    required this.centerLng,
    required this.isCluster,
  });
}

/// Página de mapa com layout da imagem de referência
class MapPage extends ConsumerStatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final String? restaurantId;

  const MapPage({
    super.key,
    this.initialLat,
    this.initialLng,
    this.restaurantId,
  });

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage>
    with TickerProviderStateMixin {
  late AnimationController _bottomSheetController;
  late Animation<double> _bottomSheetAnimation;
  
  RestaurantModel? _selectedRestaurant;
  String? _selectedRestaurantId; // Track selected restaurant for marker styling
  gmaps.GoogleMapController? _mapController;
  Set<gmaps.Marker> _markers = {};
  bool _markersLoaded = false;
  // Removed map key to prevent unnecessary rebuilds
  
  // Cache para evitar recriar o mapa múltiplas vezes
  static gmaps.GoogleMapController? _staticMapController;
  
  // Mapeamento de categoria ID para emoji baseado no banco de dados
  final Map<String, String> _categoryEmojis = {
    '32555c5c-b206-4c31-9e4d-1cf5d68d1e8d': '🍝', // Date night - Italiana
    '948a606b-78ff-4bcd-9d37-f14ec5654e25': '☕', // Happy Hour de Firma - Café
    '0a575266-ee8e-4c72-82e9-2a85359682cb': '🥗', // Com vibe leve - Saudável
    '875498c4-1853-4b84-aa5e-a05a3a902574': '🏛️', // Clássicos POA
    'a945c6bb-0554-4181-831c-17928864ee52': '🍰', // Vontade de Doce - Doceria
    'c9fdb068-aff4-4fe1-84ff-10974d62fba9': '🍽️', // Almoço de Domingo - Buffet
    '3b9168dc-f187-40e3-8921-7780d5195d8b': '🍻', // Happy Hour alternativo
    '1417ab7f-338c-4dd4-96d7-87bcaa8099bf': '🍣', // Sushi fresh - Japonesa
    '45a122d2-d5fd-4e20-ab17-2d1a1699c3e0': '🍔', // Para curar ressaca - Hambúrguer
    'dfadf4da-3c7b-4d85-b6da-5b0bddd60195': '🍕', // Clássicos Curitiba - Pizzaria
  };

  @override
  void initState() {
    super.initState();
    
    _bottomSheetController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _bottomSheetAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _bottomSheetController,
      curve: Curves.easeInOut,
    ));

    // Aguardar carregamento dos dados e então criar markers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('🎯🎯🎯 initState: CORREÇÃO LOCALIZAÇÃO - usando restaurantes reais...');
    });
    
    // TESTE IMEDIATO - para debug
    debugPrint('🏁 MapPage initState executado - página iniciada!');
  }

  @override
  void dispose() {
    _bottomSheetController.dispose();
    super.dispose();
  }

  void _onRestaurantTap(RestaurantModel restaurant) {
    debugPrint('🎯 Restaurante clicado: ${restaurant.name}');
    
    setState(() {
      _selectedRestaurant = restaurant;
      _selectedRestaurantId = restaurant.id;
    });
    
    // Show bottom sheet with restaurant details
    _bottomSheetController.forward();
    
    // Rebuild markers with selected state (scale 1.15 + colored border)
    _rebuildMarkersWithSelection();
    
    // Show tooltip/card overlay
    _showRestaurantTooltip(restaurant);
  }

  /// Shows a tooltip/card overlay for the selected restaurant
  void _showRestaurantTooltip(RestaurantModel restaurant) {
    // Remove any existing overlay
    _hideRestaurantTooltip();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(
              _getRestaurantEmoji(restaurant),
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    restaurant.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (restaurant.rating != null && restaurant.deliveryTime != null)
                    Text(
                      '⭐ ${restaurant.rating!.toStringAsFixed(1)} • ${restaurant.deliveryTime}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF6B73D9),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Hides the restaurant tooltip
  void _hideRestaurantTooltip() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  void _closeBottomSheet() {
    debugPrint('🎯 Fechando seleção de restaurante');
    
    _bottomSheetController.reverse();
    setState(() {
      _selectedRestaurant = null;
      _selectedRestaurantId = null;
    });
    
    // Hide tooltip when closing
    _hideRestaurantTooltip();
    
    // Rebuild markers to clear selected state (back to normal size and border)
    _rebuildMarkersWithSelection();
  }


  void _navigateToRestaurant(RestaurantModel restaurant) {
    context.push('/restaurant/${restaurant.id}');
  }





  @override
  Widget build(BuildContext context) {
    final restaurantState = ref.watch(restaurantProvider);
    
    // Usar localização fixa de Porto Alegre para consistência com os restaurantes
    final portoAlegreLocation = LocationModel(
      latitude: -30.0277,
      longitude: -51.2287,
      address: 'Porto Alegre, RS, Brasil',
    );
    
    // Sempre usar os restaurantes reais do banco de dados
    final nearbyRestaurants = restaurantState.restaurants.isNotEmpty
        ? restaurantState.restaurants
        : <RestaurantModel>[]; // Lista vazia ao invés de dados de amostra
    
    debugPrint('🗺️ MapPage: ${nearbyRestaurants.length} restaurantes disponíveis para o mapa');
    if (nearbyRestaurants.isNotEmpty) {
      debugPrint('🏪 Primeiro restaurante: ${nearbyRestaurants.first.name} (${nearbyRestaurants.first.latitude}, ${nearbyRestaurants.first.longitude})');
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header azul/roxo com gradiente (reduzido para dar mais espaço ao mapa)
          Flexible(
            flex: 2,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF4A5FBF), // Azul
                    Color(0xFF6B73D9), // Roxo claro
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Botão de voltar
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => context.go('/home'),
                            icon: const Icon(
                              Icons.arrow_back_ios,
                              color: Colors.white,
                              size: 24,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.2),
                              padding: const EdgeInsets.all(8),
                              minimumSize: const Size(40, 40),
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Texto explicativo
                      Text(
                        'Veja o que está por perto',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '(ou onde você quiser).',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      
                      SizedBox(height: 16),
                      
                      Text(
                        'Encontre experiências pelo mapa e descubra a cidade com mais intenção.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          height: 1.3,
                        ),
                      ),
                      
                      SizedBox(height: 20),
                      
                      // Campo de busca
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Buscar restaurantes, pratos...',
                            hintStyle: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 16,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.grey[600],
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 15,
                            ),
                          ),
                          onTap: () {
                            // Navegar para a página de busca
                            context.push('/search');
                          },
                          readOnly: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Mapa (expandido para ocupar mais espaço)
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                // Mapa sempre visível, independente do estado dos restaurantes
                _buildDirectGoogleMap(nearbyRestaurants, portoAlegreLocation),
                
                // Overlay de carregamento de restaurantes (não bloqueia o mapa)
                if (restaurantState.isLoading)
                  Positioned(
                    top: 20,
                    right: 20,
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Carregando restaurantes...',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Overlay de erro (não bloqueia o mapa)
                if (restaurantState.hasError)
                  Positioned(
                    top: 20,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade600, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Erro ao carregar restaurantes: ${restaurantState.error ?? 'Erro desconhecido'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade600,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => ref.refresh(restaurantProvider),
                            child: Icon(Icons.refresh, color: Colors.red.shade600, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),


        ],
      ),
    );
  }


  /// Obter restaurantes de amostra perto da localização
  List<RestaurantModel> _getSampleRestaurants(LocationModel? userLocation) {
    // Se não há localização, usar coordenadas padrão de Porto Alegre
    final baseLat = userLocation?.latitude ?? -30.0277;
    final baseLng = userLocation?.longitude ?? -51.2287;
    
    return [
      RestaurantModel(
        id: 'sample-1',
        name: 'Maki Sushi',
        description: 'Comida japonesa autêntica',
        rating: 4.5,
        deliveryTime: '30-45 min',
        deliveryFee: 5.90,
        latitude: baseLat + 0.002,
        longitude: baseLng + 0.002,
        address: 'Rua das Flores, 123',
        emoji: '🍣',
        isOpen: true,
        isFeatured: true,
        category: 'Japonês',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      RestaurantModel(
        id: 'sample-2',
        name: 'Pizzaria Italiana',
        description: 'Pizza tradicional italiana',
        rating: 4.2,
        deliveryTime: '25-40 min',
        deliveryFee: 4.50,
        latitude: baseLat - 0.003,
        longitude: baseLng + 0.001,
        address: 'Av. Central, 456',
        emoji: '🍕',
        isOpen: true,
        isFeatured: false,
        category: 'Pizza',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      RestaurantModel(
        id: 'sample-3',
        name: 'Burguer House',
        description: 'Hambúrgueres artesanais',
        rating: 4.7,
        deliveryTime: '20-35 min',
        deliveryFee: 3.99,
        latitude: baseLat + 0.001,
        longitude: baseLng - 0.002,
        address: 'Rua dos Sabores, 789',
        emoji: '🍔',
        isOpen: true,
        isFeatured: true,
        category: 'Hambúrguer',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      RestaurantModel(
        id: 'sample-4',
        name: 'Cantina do Nono',
        description: 'Comida caseira italiana',
        rating: 4.3,
        deliveryTime: '35-50 min',
        deliveryFee: 6.50,
        latitude: baseLat - 0.001,
        longitude: baseLng - 0.003,
        address: 'Praça da Saudade, 321',
        emoji: '🍝',
        isOpen: true,
        isFeatured: false,
        category: 'Italiano',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      RestaurantModel(
        id: 'sample-5',
        name: 'Açaí da Praia',
        description: 'Açaí e lanches naturais',
        rating: 4.1,
        deliveryTime: '15-25 min',
        deliveryFee: 2.99,
        latitude: baseLat + 0.003,
        longitude: baseLng - 0.001,
        address: 'Rua das Palmeiras, 654',
        emoji: '🥤',
        isOpen: true,
        isFeatured: false,
        category: 'Açaí',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];
  }

  /// Constrói um mapa Google Maps direto com tratamento de erros de rede
  Widget _buildDirectGoogleMap(List<RestaurantModel> restaurants, LocationModel? userLocation) {
    try {
      return gmaps.GoogleMap(
      // No key needed - markers will update naturally
      initialCameraPosition: gmaps.CameraPosition(
        target: userLocation != null
            ? gmaps.LatLng(userLocation.latitude, userLocation.longitude)
            : const gmaps.LatLng(-30.0277, -51.2287), // Porto Alegre como fallback
        zoom: 14,
      ),
      markers: _markers,
      onMapCreated: (gmaps.GoogleMapController controller) {
        _mapController = controller;
        _staticMapController = controller;
        debugPrint('🗺️ Google Maps inicializado sem erros de rede');
        debugPrint('📊 Carregando markers para ${restaurants.length} restaurantes reais...');
        
        // Carregar markers com os restaurantes reais que foram passados
        if (restaurants.isNotEmpty) {
          _loadCustomMarkers(restaurants, userLocation);
        } else {
          debugPrint('⚠️ Nenhum restaurante disponível para criar markers');
        }
      },
      myLocationEnabled: false, // Desabilitado para evitar conflitos
      myLocationButtonEnabled: true,
      zoomControlsEnabled: true,
      mapToolbarEnabled: true,
      onTap: (gmaps.LatLng position) {
        // Fechar qualquer bottom sheet aberto e desmarcar seleção
        debugPrint('🗺️ Clique no mapa - desmarcando seleção');
        _closeBottomSheet();
      },
    );
    } catch (e) {
      debugPrint('❌ Erro ao carregar Google Maps: $e');
      return Container(
        color: Colors.grey[300],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined, size: 64, color: Colors.grey[600]),
              SizedBox(height: 16),
              Text(
                'Erro ao carregar mapa',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'Verifique sua conexão com a internet',
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }
  }

  /// Obtém o emoji da categoria do restaurante
  String _getRestaurantEmoji(RestaurantModel restaurant) {
    return CategoryEmojiMapper.getEmojiByCategory(
      categoryId: restaurant.categoryId,
      categoryName: restaurant.category,
      restaurantEmoji: restaurant.emoji,
    );
  }
  
  /// Cria um ícone customizado usando o novo sistema de balloon markers
  Future<gmaps.BitmapDescriptor> _createCustomMarkerIcon(
    String emoji, {
    bool isSelected = false,
    String? category,
  }) async {
    debugPrint('🎨 Criando ícone balloon customizado para emoji: $emoji (categoria: $category)');
    
    try {
      // Use the new BalloonMarkerService to create beautiful balloon-style markers
      final balloonIcon = await BalloonMarkerService.createBalloonMarker(
        emoji: emoji,
        isSelected: isSelected,
        category: category,
      );
      
      debugPrint('✅ Ícone balloon criado com sucesso para emoji: $emoji');
      return balloonIcon;
    } catch (e) {
      debugPrint('❌ Erro ao criar ícone balloon, usando fallback: $e');
      
      // Fallback to colored markers if balloon creation fails
      const colorMap = {
        '🍝': gmaps.BitmapDescriptor.hueRed,      // Italiana
        '☕': gmaps.BitmapDescriptor.hueOrange,    // Café
        '🥗': gmaps.BitmapDescriptor.hueGreen,     // Saudável  
        '🏛️': gmaps.BitmapDescriptor.hueBlue,     // Clássicos POA
        '🍰': gmaps.BitmapDescriptor.hueMagenta,   // Doceria
        '🍽️': gmaps.BitmapDescriptor.hueYellow,   // Buffet
        '🍻': gmaps.BitmapDescriptor.hueViolet,    // Happy Hour
        '🍣': gmaps.BitmapDescriptor.hueAzure,     // Japonesa
        '🍔': gmaps.BitmapDescriptor.hueOrange,    // Hambúrguer
        '🍕': gmaps.BitmapDescriptor.hueRed,       // Pizza
        '📍': gmaps.BitmapDescriptor.hueCyan,      // Usuário
      };
      
      final hue = colorMap[emoji] ?? gmaps.BitmapDescriptor.hueOrange;
      debugPrint('✅ Usando marker colorido fallback (hue: $hue) para emoji: $emoji');
      return gmaps.BitmapDescriptor.defaultMarkerWithHue(hue);
    }
  }
  
  /// Cria marcadores para os restaurantes diretamente com balloon markers
  Future<Set<gmaps.Marker>> _createMarkersForRestaurants(List<RestaurantModel> restaurants, LocationModel? userLocation) async {
    debugPrint('🏗️ Iniciando criação de ${restaurants.length} markers de restaurantes (Direct Balloon)');
    
    // For debugging, let's disable clustering temporarily and create individual markers
    // This will help us ensure all restaurants appear
    final markers = <gmaps.Marker>{};
    
    debugPrint('📊 Detalhes dos restaurantes recebidos:');
    for (int i = 0; i < restaurants.length; i++) {
      final restaurant = restaurants[i];
      debugPrint('   $i: ${restaurant.name} (${restaurant.latitude}, ${restaurant.longitude}) - ${restaurant.category}');
    }

    // Adicionar marcador da localização do usuário (se disponível)
    if (userLocation != null) {
      debugPrint('👤 Criando marker do usuário...');
      try {
        final userIcon = await BalloonMarkerService.createUserLocationMarker();
        final userMarker = gmaps.Marker(
          markerId: const gmaps.MarkerId('user_location'),
          position: gmaps.LatLng(userLocation.latitude, userLocation.longitude),
          icon: userIcon,
          infoWindow: const gmaps.InfoWindow(
            title: '📍 Você está aqui',
            snippet: 'Sua localização atual',
          ),
        );
        markers.add(userMarker);
        debugPrint('✅ Marker do usuário criado com balloon style');
      } catch (e) {
        debugPrint('❌ Erro ao criar marker do usuário: $e');
        // Fallback to default marker
        markers.add(gmaps.Marker(
          markerId: const gmaps.MarkerId('user_location'),
          position: gmaps.LatLng(userLocation.latitude, userLocation.longitude),
          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueCyan),
          infoWindow: const gmaps.InfoWindow(
            title: '📍 Você está aqui',
            snippet: 'Sua localização atual',
          ),
        ));
      }
    }

    // Criar markers individuais para todos os restaurantes (sem clustering)
    debugPrint('🍽️ Criando ${restaurants.length} markers individuais...');
    for (int i = 0; i < restaurants.length; i++) {
      final restaurant = restaurants[i];
      
      if (restaurant.latitude == null || restaurant.longitude == null) {
        debugPrint('⚠️ Restaurante ${restaurant.name} não tem coordenadas válidas');
        continue;
      }
      
      debugPrint('🔨 Processando restaurante $i: ${restaurant.name}');
      
      try {
        final emoji = _getRestaurantEmoji(restaurant);
        final isSelected = restaurant.id == _selectedRestaurantId;
        debugPrint('   📍 Emoji: $emoji, Selected: $isSelected, Category: ${restaurant.category}');
        
        // Create custom balloon icon
        final balloonIcon = await BalloonMarkerService.createBalloonMarker(
          emoji: emoji,
          isSelected: isSelected,
          category: restaurant.category,
        );
        
        debugPrint('   ✅ Balloon icon criado para ${restaurant.name}');
        
        // Create marker directly with balloon icon
        final marker = gmaps.Marker(
          markerId: gmaps.MarkerId(restaurant.id),
          position: gmaps.LatLng(restaurant.latitude!, restaurant.longitude!),
          icon: balloonIcon, // Direct assignment of balloon icon
          infoWindow: gmaps.InfoWindow(
            title: '$emoji ${restaurant.name}',
            snippet: restaurant.rating != null && restaurant.deliveryTime != null
                ? '⭐ ${restaurant.rating!.toStringAsFixed(1)} • ${restaurant.deliveryTime}'
                : restaurant.description ?? '',
          ),
          onTap: () => _onRestaurantTap(restaurant),
        );
        
        markers.add(marker);
        debugPrint('   ✅ Marker criado e adicionado para ${restaurant.name} (ID: ${restaurant.id})');
        
      } catch (e, stackTrace) {
        debugPrint('❌ Erro ao criar marker para ${restaurant.name}: $e');
        debugPrint('📋 StackTrace: $stackTrace');
        
        // Fallback to colored marker if balloon creation fails
        try {
          final emoji = _getRestaurantEmoji(restaurant);
          const colorMap = {
            '🍝': gmaps.BitmapDescriptor.hueRed,      // Italiana
            '☕': gmaps.BitmapDescriptor.hueOrange,    // Café
            '🥗': gmaps.BitmapDescriptor.hueGreen,     // Saudável  
            '🏛️': gmaps.BitmapDescriptor.hueBlue,     // Clássicos POA
            '🍰': gmaps.BitmapDescriptor.hueMagenta,   // Doceria
            '🍽️': gmaps.BitmapDescriptor.hueYellow,   // Buffet
            '🍸': gmaps.BitmapDescriptor.hueViolet,    // Happy Hour
            '🍣': gmaps.BitmapDescriptor.hueAzure,     // Japonesa
            '🍔': gmaps.BitmapDescriptor.hueOrange,    // Hambúrguer
            '🍕': gmaps.BitmapDescriptor.hueRed,       // Pizza
          };
          
          final hue = colorMap[emoji] ?? gmaps.BitmapDescriptor.hueOrange;
          final fallbackMarker = gmaps.Marker(
            markerId: gmaps.MarkerId(restaurant.id),
            position: gmaps.LatLng(restaurant.latitude!, restaurant.longitude!),
            icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(hue),
            infoWindow: gmaps.InfoWindow(
              title: '$emoji ${restaurant.name}',
              snippet: 'Fallback marker - ${restaurant.category ?? "Restaurante"}',
            ),
            onTap: () => _onRestaurantTap(restaurant),
          );
          
          markers.add(fallbackMarker);
          debugPrint('   🎨 Fallback marker colorido criado para ${restaurant.name}');
        } catch (fallbackError) {
          debugPrint('❌ Erro no fallback para ${restaurant.name}: $fallbackError');
        }
      }
    }
    
    debugPrint('🎯 Total final de markers criados: ${markers.length}');
    debugPrint('📋 Resumo: ${restaurants.length} restaurantes → ${markers.length} markers');
    
    // Log each marker for debugging
    for (final marker in markers) {
      debugPrint('   📍 Marker final: ${marker.markerId.value} em ${marker.position}');
    }
    
    return markers;
  }
  
  /// Rebuilds markers with current selection state
  Future<void> _rebuildMarkersWithSelection() async {
    final restaurantState = ref.read(restaurantProvider);
    if (restaurantState.restaurants.isNotEmpty) {
      final portoAlegreLocation = LocationModel(
        latitude: -30.0277,
        longitude: -51.2287,
        address: 'Porto Alegre, RS, Brasil',
      );
      
      // Reset markers loaded flag to allow rebuilding
      _markersLoaded = false;
      
      debugPrint('🔄 Reconstruindo markers com estado de seleção...');
      await _loadCustomMarkers(restaurantState.restaurants, portoAlegreLocation);
    }
  }

  /// Simple clustering algorithm for restaurants
  List<_ClusterItem> _applySimpleClustering(List<RestaurantModel> restaurants) {
    const double clusterRadius = 0.01; // ~1km clustering radius
    const int minClusterSize = 2;
    
    final List<_ClusterItem> clusters = [];
    final List<RestaurantModel> processed = [];
    
    for (final restaurant in restaurants) {
      if (processed.contains(restaurant) || 
          restaurant.latitude == null || 
          restaurant.longitude == null) {
        continue;
      }
      
      final List<RestaurantModel> nearbyRestaurants = [restaurant];
      processed.add(restaurant);
      
      // Find nearby restaurants
      for (final other in restaurants) {
        if (processed.contains(other) || 
            other.latitude == null || 
            other.longitude == null ||
            other.id == restaurant.id) {
          continue;
        }
        
        final distance = _calculateDistance(
          restaurant.latitude!, restaurant.longitude!,
          other.latitude!, other.longitude!,
        );
        
        if (distance <= clusterRadius) {
          nearbyRestaurants.add(other);
          processed.add(other);
        }
      }
      
      // Calculate cluster center
      final centerLat = nearbyRestaurants
          .map((r) => r.latitude!)
          .reduce((a, b) => a + b) / nearbyRestaurants.length;
      final centerLng = nearbyRestaurants
          .map((r) => r.longitude!)
          .reduce((a, b) => a + b) / nearbyRestaurants.length;
      
      clusters.add(_ClusterItem(
        restaurants: nearbyRestaurants,
        centerLat: centerLat,
        centerLng: centerLng,
        isCluster: nearbyRestaurants.length >= minClusterSize,
      ));
    }
    
    debugPrint('🔗 Clustering aplicado: ${restaurants.length} restaurantes → ${clusters.length} items (${clusters.where((c) => c.isCluster).length} clusters)');
    return clusters;
  }

  /// Calculate distance between two points in degrees (approximate)
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    final dLat = lat1 - lat2;
    final dLng = lng1 - lng2;
    return (dLat * dLat + dLng * dLng); // Simple Euclidean distance in degrees
  }

  /// Handle cluster tap - zoom into the cluster area with enhanced feedback
  void _onClusterTap(List<RestaurantModel> restaurants, double centerLat, double centerLng) {
    debugPrint('🔗 Cluster clicado com ${restaurants.length} restaurantes');
    
    // Clear any existing selection
    _closeBottomSheet();
    
    if (_mapController != null) {
      // Zoom into the cluster with smooth animation
      _mapController!.animateCamera(
        gmaps.CameraUpdate.newLatLngZoom(
          gmaps.LatLng(centerLat, centerLng),
          16.0, // Zoom level to show individual markers
        ),
      );
    }
    
    // Show enhanced info about the cluster
    final restaurantNames = restaurants.take(3).map((r) => r.name).join(', ');
    final additionalCount = restaurants.length > 3 ? ' e mais ${restaurants.length - 3}' : '';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '🔗 ${restaurants.length} restaurantes nesta área',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$restaurantNames$additionalCount',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        backgroundColor: const Color(0xFF6B73D9),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Carrega markers customizados de forma assíncrona
  Future<void> _loadCustomMarkers(List<RestaurantModel> restaurants, LocationModel? userLocation) async {
    debugPrint('🚀 Iniciando carregamento de markers customizados');
    debugPrint('📊 Restaurantes recebidos: ${restaurants.length}');
    debugPrint('📍 Localização do usuário: ${userLocation?.latitude}, ${userLocation?.longitude}');
    
    // Allow reloading markers when rebuilding with selection state
    if (_markersLoaded && !restaurants.any((r) => r.id == _selectedRestaurantId)) {
      debugPrint('⚠️ Markers já foram carregados, ignorando');
      return;
    }
    
    try {
      debugPrint('🔄 Criando markers customizados...');
      final markers = await _createMarkersForRestaurants(restaurants, userLocation);
      debugPrint('✅ ${markers.length} markers criados com sucesso');
      
      // Validate markers were created properly
      if (markers.isEmpty && restaurants.isNotEmpty) {
        debugPrint('⚠️ Aviso: Nenhum marker foi criado para ${restaurants.length} restaurantes');
        return;
      }
      
      if (mounted) {
        debugPrint('🔄 Atualizando estado do mapa...');
        setState(() {
          _markers = markers;
          _markersLoaded = true;
          // No need to force map rebuild with new key
        });
        debugPrint('✅ Estado atualizado - ${_markers.length} markers agora no mapa');
        debugPrint('🎯 Markers atualizados sem reconstruir o mapa');
        
        // Log individual markers for debugging
        for (final marker in markers) {
          debugPrint('📍 Marker ativo: ${marker.markerId.value} em ${marker.position}');
        }
      } else {
        debugPrint('❌ Widget não está montado - não foi possível atualizar estado');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Erro ao carregar markers customizados: $e');
      debugPrint('📋 StackTrace: $stackTrace');
      
      // Fallback to simple colored markers if balloon creation fails
      if (mounted) {
        debugPrint('🔄 Tentando fallback para markers coloridos...');
        try {
          final fallbackMarkers = await _createFallbackMarkers(restaurants, userLocation);
          setState(() {
            _markers = fallbackMarkers;
            _markersLoaded = true;
          });
          debugPrint('✅ Fallback markers carregados: ${fallbackMarkers.length}');
        } catch (fallbackError) {
          debugPrint('❌ Erro no fallback: $fallbackError');
        }
      }
    }
  }

  /// Creates simple colored markers as fallback when balloon markers fail
  Future<Set<gmaps.Marker>> _createFallbackMarkers(List<RestaurantModel> restaurants, LocationModel? userLocation) async {
    debugPrint('🎨 Criando markers de fallback coloridos...');
    final markers = <gmaps.Marker>{};
    
    // Color mapping for categories
    const colorMap = {
      '🍝': gmaps.BitmapDescriptor.hueRed,      // Italiana
      '☕': gmaps.BitmapDescriptor.hueOrange,    // Café
      '🥗': gmaps.BitmapDescriptor.hueGreen,     // Saudável  
      '🏛️': gmaps.BitmapDescriptor.hueBlue,     // Clássicos POA
      '🍰': gmaps.BitmapDescriptor.hueMagenta,   // Doceria
      '🍽️': gmaps.BitmapDescriptor.hueYellow,   // Buffet
      '🍻': gmaps.BitmapDescriptor.hueViolet,    // Happy Hour
      '🍣': gmaps.BitmapDescriptor.hueAzure,     // Japonesa
      '🍔': gmaps.BitmapDescriptor.hueOrange,    // Hambúrguer
      '🍕': gmaps.BitmapDescriptor.hueRed,       // Pizza
    };

    // Add user location marker
    if (userLocation != null) {
      markers.add(gmaps.Marker(
        markerId: const gmaps.MarkerId('user_location'),
        position: gmaps.LatLng(userLocation.latitude, userLocation.longitude),
        icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueCyan),
        infoWindow: const gmaps.InfoWindow(
          title: '📍 Você está aqui',
          snippet: 'Sua localização atual',
        ),
      ));
    }

    // Add restaurant markers
    for (final restaurant in restaurants) {
      if (restaurant.latitude != null && restaurant.longitude != null) {
        final emoji = _getRestaurantEmoji(restaurant);
        final hue = colorMap[emoji] ?? gmaps.BitmapDescriptor.hueOrange;
        
        markers.add(gmaps.Marker(
          markerId: gmaps.MarkerId(restaurant.id),
          position: gmaps.LatLng(restaurant.latitude!, restaurant.longitude!),
          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(hue),
          infoWindow: gmaps.InfoWindow(
            title: '$emoji ${restaurant.name}',
            snippet: restaurant.rating != null && restaurant.deliveryTime != null
                ? '⭐ ${restaurant.rating!.toStringAsFixed(1)} • ${restaurant.deliveryTime}'
                : restaurant.description ?? '',
          ),
          onTap: () => _onRestaurantTap(restaurant),
        ));
      }
    }

    return markers;
  }
}
