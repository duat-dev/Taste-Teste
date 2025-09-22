import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../data/services/onboarding_service.dart';
import '../../../data/services/auth/auth_service.dart';
import '../../../data/services/location/location_service.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/config/supabase_config.dart';
import '../../widgets/widgets.dart';

/// Página de splash screen com verificações iniciais
class SplashPage extends StatefulWidget {
  final VoidCallback? onInitializationComplete;
  
  const SplashPage({
    super.key,
    this.onInitializationComplete,
  });
  
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  String _currentStatus = 'Inicializando...';
  bool _hasError = false;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  
  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeApp();
  }
  
  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
    ));
    
    _animationController.forward();
  }
  
  Future<void> _initializeApp() async {
    try {
      // Verificação 1: Configurações básicas e dependências críticas
      await _updateStatus('Verificando configurações...');
      await _validateCriticalDependencies();
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Verificação 2: Conectividade detalhada com retry
      await _updateStatus('Verificando conectividade...');
      await _initializeConnectivity();
      
      // Verificação 3: Autenticação e sessão com validação
      await _updateStatus('Verificando autenticação...');
      await _initializeAuthentication();
      await Future.delayed(const Duration(milliseconds: 400));
      
      // Verificação 4: Permissões e serviços de localização
      await _updateStatus('Verificando localização...');
      await _initializeLocationServices();
      await Future.delayed(const Duration(milliseconds: 400));
      
      // Verificação 5: Cache e configurações locais
      await _updateStatus('Carregando configurações...');
      await _loadLocalConfigurations();
      await Future.delayed(const Duration(milliseconds: 400));
      
      // Verificação 6: Pré-carregamento de dados críticos
      await _updateStatus('Preparando dados...');
      await _preloadCriticalData();
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Verificação 7: Finalização
      await _updateStatus('Quase pronto...');
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Aguarda animação completar
      if (mounted && _animationController.status != AnimationStatus.completed) {
        await _animationController.forward();
      }
      
      // Pequena pausa antes de navegar
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (mounted) {
        await _navigateToNextScreen();
      }
    } catch (error) {
      debugPrint('Erro na inicialização: $error');
      if (mounted) {
        setState(() {
          _hasError = true;
          _currentStatus = 'Erro ao inicializar. Toque para tentar novamente.';
        });
      }
    }
  }
  
  Future<void> _updateStatus(String status) async {
    if (mounted) {
      setState(() {
        _currentStatus = status;
      });
    }
  }

  /// Valida dependências críticas do sistema
  Future<void> _validateCriticalDependencies() async {
    try {
      // Verifica se o Supabase está inicializado
      if (!SupabaseConfig.isInitialized) {
        throw Exception('Supabase não inicializado');
      }
      
      // Verifica SharedPreferences
      await SharedPreferences.getInstance();
      
      debugPrint('✅ Dependências críticas validadas');
    } catch (e) {
      debugPrint('❌ Erro na validação de dependências: $e');
      throw Exception('Falha na validação de dependências críticas');
    }
  }

  /// Inicializa serviços de conectividade com retry
  Future<void> _initializeConnectivity() async {
    try {
      await ConnectivityService.instance.initialize();
      final connectivityResult = await ConnectivityService.instance.checkConnectivity();
      
      if (!ConnectivityService.instance.hasInternetConnection) {
        await _updateStatus('Sem conexão com internet');
        
        // Tenta reconectar uma vez
        await Future.delayed(const Duration(milliseconds: 1000));
        await ConnectivityService.instance.checkConnectivity();
        
        if (ConnectivityService.instance.hasInternetConnection) {
          await _updateStatus('Conectado: ${ConnectivityService.instance.getConnectionDescription()}');
        } else {
          await _updateStatus('Modo offline ativado');
        }
      } else {
        await _updateStatus('Conectado: ${ConnectivityService.instance.getConnectionDescription()}');
      }
      
      await Future.delayed(const Duration(milliseconds: 400));
    } catch (e) {
      debugPrint('Erro na inicialização de conectividade: $e');
      await _updateStatus('Modo offline ativado');
    }
  }

  /// Inicializa autenticação com validação de sessão
  Future<void> _initializeAuthentication() async {
    try {
      await AuthService.instance.initialize();
      
      if (AuthService.instance.isAuthenticated) {
        await _updateStatus('Usuário autenticado');
        
        // Verifica se a sessão é válida
        if (!AuthService.instance.hasValidSession) {
          await _updateStatus('Atualizando sessão...');
          try {
            await AuthService.instance.refreshSessionIfNeeded();
            await _updateStatus('Sessão atualizada');
          } catch (e) {
            debugPrint('Erro ao atualizar sessão: $e');
            await _updateStatus('Sessão expirada - modo visitante');
          }
        } else {
          await _updateStatus('Sessão válida');
        }
      } else {
        await _updateStatus('Modo visitante');
      }
    } catch (e) {
      debugPrint('Erro na inicialização de autenticação: $e');
      await _updateStatus('Modo visitante');
    }
  }

  /// Inicializa serviços de localização
  Future<void> _initializeLocationServices() async {
    try {
      final locationEnabled = await LocationService.instance.isLocationServiceEnabled();
      final permissionStatus = await LocationService.instance.hasLocationPermission();
      
      if (!locationEnabled) {
        await _updateStatus('Serviço de localização desabilitado');
      } else if (permissionStatus != PermissionStatus.granted) {
        await _updateStatus('Permissão de localização necessária');
      } else {
        await _updateStatus('Localização configurada');
        
        // Tenta obter localização atual com timeout
        try {
          await _updateStatus('Obtendo localização atual...');
          final position = await LocationService.instance.getCurrentPosition()
              .timeout(const Duration(seconds: 10));
          
          if (position != null) {
            await _updateStatus('Localização obtida');
          } else {
            await _updateStatus('Localização indisponível');
          }
        } catch (e) {
          debugPrint('Erro ao obter localização: $e');
          await _updateStatus('Localização indisponível');
        }
      }
    } catch (e) {
      debugPrint('Erro na inicialização de localização: $e');
      await _updateStatus('Localização indisponível');
    }
  }

  /// Carrega configurações locais
  Future<void> _loadLocalConfigurations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Carrega configurações de tema, idioma, etc.
      final isDarkMode = prefs.getBool('dark_mode') ?? false;
      final language = prefs.getString('language') ?? 'pt';
      
      debugPrint('Configurações carregadas: tema=${isDarkMode ? 'escuro' : 'claro'}, idioma=$language');
      
      // Aqui podemos aplicar as configurações se necessário
      
    } catch (e) {
      debugPrint('Erro ao carregar configurações: $e');
      // Continua com configurações padrão
    }
  }

  /// Pré-carrega dados críticos
  Future<void> _preloadCriticalData() async {
    try {
      // Pré-carrega dados essenciais para melhor UX
      // Por exemplo: categorias, configurações do app, etc.
      
      if (ConnectivityService.instance.hasInternetConnection) {
        // Pré-carrega dados que precisam de internet
        debugPrint('Pré-carregando dados online...');
      } else {
        // Carrega dados do cache local
        debugPrint('Carregando dados do cache local...');
      }
      
    } catch (e) {
      debugPrint('Erro no pré-carregamento: $e');
      // Não é crítico, continua normalmente
    }
  }
  
  void _retryInitialization() {
    if (_retryCount >= _maxRetries) {
      setState(() {
        _currentStatus = 'Muitas tentativas falharam. Verifique sua conexão e reinicie o app.';
      });
      return;
    }
    
    _retryCount++;
    setState(() {
      _hasError = false;
      _currentStatus = 'Tentando novamente... (${_retryCount}/$_maxRetries)';
    });
    
    // Aguardar um pouco antes de tentar novamente (backoff)
    Future.delayed(Duration(seconds: _retryCount), () {
      if (mounted) {
        _initializeApp();
      }
    });
  }
  
  Future<void> _navigateToNextScreen() async {
    try {
      // Verificar se deve mostrar onboarding
      final shouldShowOnboarding = await OnboardingService.shouldShowOnboarding();
      
      // Aguardar um pouco para garantir que o router esteja completamente inicializado
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (mounted) {
        // Verificar se o GoRouter está disponível no contexto antes de navegar
        if (GoRouter.maybeOf(context) == null) {
          debugPrint('GoRouter não está disponível no contexto, aguardando...');
          await Future.delayed(const Duration(milliseconds: 500));
        }
        
        if (widget.onInitializationComplete != null) {
          widget.onInitializationComplete!();
        } else {
          // Navegação segura
          if (shouldShowOnboarding) {
            _safeNavigate('/onboarding');
          } else {
            _safeNavigate('/home');
          }
        }
      }
    } catch (e) {
      debugPrint('Erro na navegação do splash: $e');
      // Fallback para home
      if (mounted) {
        _safeNavigate('/home');
      }
    }
  }

  /// Método para navegação segura que tenta múltiplas vezes se necessário
  void _safeNavigate(String path) {
    try {
      if (GoRouter.maybeOf(context) != null) {
        context.go(path);
      } else {
        // Tentar novamente após um delay
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            _safeNavigate(path);
          }
        });
      }
    } catch (e) {
      debugPrint('Erro na navegação segura: $e');
      // Tentar novamente após um delay maior
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _safeNavigate(path);
        }
      });
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingLarge),
            child: Column(
              children: [
                const Spacer(flex: 2),
                
                // Logo e animação
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Opacity(
                        opacity: _fadeAnimation.value,
                        child: _buildLogo(),
                      ),
                    );
                  },
                ),
                
                SizedBox(height: AppDimensions.paddingXLarge),
                
                // Nome do app
                AnimatedBuilder(
                  animation: _fadeAnimation,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fadeAnimation.value,
                      child: Text(
                        'Taste',
                        style: AppTextStyles.h1.copyWith(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    );
                  },
                ),
                
                SizedBox(height: AppDimensions.paddingMedium),
                
                // Slogan
                AnimatedBuilder(
                  animation: _fadeAnimation,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fadeAnimation.value * 0.8,
                      child: Text(
                        'Descubra sabores únicos',
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    );
                  },
                ),
                
                const Spacer(flex: 3),
                
                // Status e loading
        _buildStatusSection(),
                
                SizedBox(height: AppDimensions.paddingXXLarge),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.largeRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Image.asset(
          'assets/images/logo_bege.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.restaurant_menu,
              size: 60,
              color: AppColors.primary,
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildStatusSection() {
    if (_hasError) {
      return GestureDetector(
        onTap: _retryInitialization,
        child: Column(
          children: [
            Icon(
              Icons.refresh,
              color: AppColors.textPrimary,
              size: AppDimensions.iconLarge,
            ),
            SizedBox(height: AppDimensions.paddingMedium),
            Text(
              _currentStatus,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    return Column(
      children: [
        LoadingWidget.simple(
          size: AppDimensions.iconLarge,
          color: AppColors.textPrimary,
        ),
        SizedBox(height: AppDimensions.paddingMedium),
        Text(
          _currentStatus,
          style: AppTextStyles.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Widget de splash simples para casos específicos
class SimpleSplashScreen extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? logo;
  final Duration duration;
  final VoidCallback? onComplete;
  
  const SimpleSplashScreen({
    super.key,
    this.title,
    this.subtitle,
    this.logo,
    this.duration = const Duration(seconds: 3),
    this.onComplete,
  });
  
  @override
  Widget build(BuildContext context) {
    // Auto-complete após duração
    if (onComplete != null) {
      Future.delayed(duration, onComplete!);
    }
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (logo != null) logo!,
              if (title != null) ...[
                SizedBox(height: AppDimensions.paddingLarge),
                Text(
                  title!,
                  style: AppTextStyles.h1,
                  textAlign: TextAlign.center,
                ),
              ],
              if (subtitle != null) ...[
                SizedBox(height: AppDimensions.paddingMedium),
                Text(
                  subtitle!,
                  style: AppTextStyles.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
