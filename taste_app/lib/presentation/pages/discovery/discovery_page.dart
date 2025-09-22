import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'discovery_provider.dart';
import '../../widgets/loading_widget.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../widgets/map_fallback_widget.dart';

class DiscoveryPage extends ConsumerWidget {
  final String categoryId;

  const DiscoveryPage({
    super.key,
    required this.categoryId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(discoveryProvider(categoryId));
    final notifier = ref.read(discoveryProvider(categoryId).notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header azul
            _buildHeader(context, state),
            
            // Conteúdo principal
            Expanded(
              child: _buildContent(context, state, notifier),
            ),
            
            // Barra de navegação inferior
            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, DiscoveryState state) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      decoration: const BoxDecoration(
        color: AppColors.primary,
      ),
      child: Column(
        children: [
          // Header com botão de voltar e logo
          Row(
            children: [
              // Botão de voltar
              GestureDetector(
                onTap: () {
                  debugPrint('🔙 Discovery: Voltando para home');
                  context.go('/home');
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    LucideIcons.arrowLeft,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              
              // Logo centralizado
              Expanded(
                child: Center(
                  child: Text(
                    'tt',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
              ),
              
              // Espaço para manter logo centralizado
              SizedBox(width: 40),
            ],
          ),
          
          SizedBox(height: 10),
          
          // Texto principal
          Text(
            'Encontramos lugares\ncom a sua cara',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w400,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          
          SizedBox(height: 24),
          
          // Mapa pequeno
          _buildMiniMap(state),
          
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMiniMap(DiscoveryState state) {
    return Container(
      height: 200,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.grey[200],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: state.userLocation != null
            ? SafeGoogleMap(
                height: 200,
                fallbackMessage: 'Mapa não disponível\nVerifique sua conexão com a internet',
                mapWidget: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      state.userLocation?.latitude ?? 0.0,
                      state.userLocation?.longitude ?? 0.0,
                    ),
                    zoom: 13,
                  ),
                  markers: {
                    Marker(
                      markerId: const MarkerId('user_location'),
                      position: LatLng(
                        state.userLocation?.latitude ?? 0.0,
                        state.userLocation?.longitude ?? 0.0,
                      ),
                      infoWindow: const InfoWindow(title: 'Sua localização'),
                    ),
                    ...state.restaurants.map(
                      (restaurant) => Marker(
                        markerId: MarkerId(restaurant.id),
                        position: LatLng(
                          restaurant.latitude ?? 0.0,
                          restaurant.longitude ?? 0.0,
                        ),
                        infoWindow: InfoWindow(title: restaurant.name),
                      ),
                    ),
                  },
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  myLocationButtonEnabled: false,
                  compassEnabled: false,
                ),
              )
            : Container(
                color: Colors.grey[200],
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.mapPin,
                        size: 40,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Localização não disponível',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, DiscoveryState state, DiscoveryNotifier notifier) {
    if (state.isLoading) {
      return const Center(child: LoadingWidget());
    }

    if (state.error != null) {
      return _buildErrorState(state.error!, notifier);
    }

    if (!state.hasLocationPermission) {
      return _buildLocationPermissionRequest(notifier);
    }

    if (state.restaurants.isEmpty) {
              return _buildEmptyState();
            }

    return Column(
      children: [
        _buildRecommendationSection(),
        _buildRestaurantsList(context, state, notifier),
      ],
    );
  }

  Widget _buildErrorState(String error, DiscoveryNotifier notifier) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.alertCircle,
              size: 64,
              color: Colors.red,
            ),
            SizedBox(height: 16),
            Text(
              'Ops! Algo deu errado',
              style: AppTextStyles.headingMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              error,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => notifier.retry(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
              child: Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationPermissionRequest(DiscoveryNotifier notifier) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.mapPin,
              size: 64,
              color: AppColors.primary,
            ),
            SizedBox(height: 16),
            Text(
              'Precisamos da sua localização',
              style: AppTextStyles.headingMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Para encontrar restaurantes próximos a você, precisamos acessar sua localização.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => notifier.requestLocationPermission(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
              child: Text('Permitir localização'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      color: AppColors.primary,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Emoji triste
              Text(
                '😞',
                style: TextStyle(
                  fontSize: 64,
                ),
              ),
              
              SizedBox(height: 24),
              
              // Texto principal
              Text(
                'Hmm... não encontramos nada\ncom esse perfil por aqui.',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: 16),
              
              // Texto secundário
              Text(
                'Que tal tentar em outro bairro\nou ajustar sua busca?',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendationSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: AppColors.primary,
      ),
      child: Text(
        'Para você: aqui incluir o que a pessoa procurou - COM IA',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildRestaurantsList(BuildContext context, DiscoveryState state, DiscoveryNotifier notifier) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: ListView.builder(
          itemCount: state.restaurants.length,
          itemBuilder: (context, index) {
            final restaurant = state.restaurants[index];
            final distance = notifier.getDistanceToRestaurant(restaurant);
            
            return _buildCustomRestaurantCard(context, restaurant, distance);
          },
        ),
      ),
    );
  }

  Widget _buildCustomRestaurantCard(BuildContext context, dynamic restaurant, double? distance) {
    return GestureDetector(
      onTap: () => context.push('/restaurant/${restaurant.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagem do restaurante
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[200],
              ),
              child: restaurant.imageUrl != null && restaurant.imageUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        restaurant.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            LucideIcons.utensils,
                            color: Colors.grey,
                            size: 32,
                          );
                        },
                      ),
                    )
                  : Icon(
                      LucideIcons.utensils,
                      color: Colors.grey,
                      size: 32,
                    ),
            ),
            
            SizedBox(width: 12),
            
            // Informações do restaurante
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nome do restaurante com prefixo
                  Text(
                    'Nome do restaurante:',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  
                  SizedBox(height: 2),
                  
                  // Categoria e nome real
                  Text(
                    '(${restaurant.category ?? 'pnt'}) ${restaurant.name ?? 'Bairro'}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  SizedBox(height: 6),
                  
                  // Descrição
                  Text(
                    'Breve descrição (resumida do perfil)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  SizedBox(height: 8),
                  
                  // Avaliação
                  Row(
                    children: [
                      ...List.generate(5, (index) {
                        return Icon(
                          index < (restaurant.rating?.floor() ?? 4)
                              ? LucideIcons.star
                              : LucideIcons.star,
                          size: 14,
                          color: index < (restaurant.rating?.floor() ?? 4)
                              ? Colors.amber
                              : Colors.grey[300],
                        );
                      }),
                      SizedBox(width: 4),
                      Text(
                        restaurant.rating?.toStringAsFixed(1) ?? '4.7',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Builder(
      builder: (context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem(
                icon: LucideIcons.compass,
                label: 'Descubra',
                isActive: true,
                onTap: () {},
              ),
              _buildBottomNavItem(
                icon: LucideIcons.map,
                label: 'Mapa',
                isActive: false,
                onTap: () => _onBottomNavTap(context, 1),
              ),
              _buildBottomNavItem(
                icon: LucideIcons.user,
                label: 'Perfil',
                isActive: false,
                onTap: () => _onBottomNavTap(context, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    const Color orangeColor = Color(0xFFFF6B35);
    
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? orangeColor : Colors.grey,
            size: 24,
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? orangeColor : Colors.grey,
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  void _onBottomNavTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        // Já está na página de descoberta, não faz nada
        break;
      case 1:
        context.go('/search');
        break;
      case 2:
        context.go('/profile');
        break;
    }
  }
}
