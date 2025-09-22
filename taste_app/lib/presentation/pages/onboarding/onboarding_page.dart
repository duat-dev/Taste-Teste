import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../widgets/widgets.dart';
import '../../../data/services/onboarding_service.dart';

/// Página de onboarding idêntica à primeira imagem de referência
class OnboardingPage extends StatefulWidget {
  final VoidCallback? onCompleted;
  
  const OnboardingPage({
    super.key,
    this.onCompleted,
  });
  
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  bool _isUIReady = false;
  
  @override
  void initState() {
    super.initState();
    // Aguarda o Flutter engine estar completamente pronto para gestures
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _isUIReady = true;
          });
        }
      });
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF2c3b83),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingLarge,
              vertical: AppDimensions.paddingMedium,
            ),
            child: Column(
              children: [
                const Spacer(flex: 2),
                
                // Logo da aplicação
                Container(
                  height: 80,
                  width: 200,
                  child: Image.asset(
                    'assets/images/logo_bege.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Text(
                        'taste',
                        style: TextStyle(
                          fontFamily: 'Dancing Script',
                          fontSize: 48,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textPrimary,
                          fontStyle: FontStyle.italic,
                        ),
                      );
                    },
                  ),
                ),
                
                SizedBox(height: AppDimensions.paddingLarge),
                
                // Subtítulo principal
                Text(
                  'Sua curadoria de experiências.',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontSize: 18,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                // Segunda linha do subtítulo em amarelo/dourado
                Text(
                  'Tudo em um só lugar',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontSize: 18,
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                SizedBox(height: AppDimensions.paddingXLarge),
                
                // Imagem de comida centralizada
                Container(
                  height: 200,
                  width: 280,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppDimensions.mediumRadius),
                    color: AppColors.primary,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.restaurant_menu,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                ),
                
                SizedBox(height: AppDimensions.paddingXLarge),
                
                // Seção "Busca inteligente"
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Busca inteligente',
                      style: AppTextStyles.h3.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: AppDimensions.paddingSmall),
                    Text(
                      'Você diz o que quer. A gente entende.\nEx: "um jantar romântico no Morumbi" e pronto —\nsugestões com a sua cara.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontSize: 14,
                        color: AppColors.textPrimary.withOpacity(0.9),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
                
                const Spacer(flex: 2),
                
                // Três pontos indicadores
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: AppDimensions.paddingLarge),
                
                // Botões Login e Cadastro divididos verticalmente
                AnimatedOpacity(
                  opacity: _isUIReady ? 1.0 : 0.5,
                  duration: const Duration(milliseconds: 200),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _isUIReady ? () => _navigateToLogin() : null,
                          child: Material(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
                            child: InkWell(
                              onTap: _isUIReady ? () => _navigateToLogin() : null,
                              borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
                              child: Container(
                                height: AppDimensions.buttonHeight,
                                child: Center(
                                  child: _isUIReady 
                                    ? Text(
                                        'Login',
                                        style: AppTextStyles.buttonText.copyWith(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )
                                    : SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 1),
                      Expanded(
                        child: GestureDetector(
                          onTap: _isUIReady ? () => _navigateToRegister() : null,
                          child: Material(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
                            child: InkWell(
                              onTap: _isUIReady ? () => _navigateToRegister() : null,
                              borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
                              child: Container(
                                height: AppDimensions.buttonHeight,
                                child: Center(
                                  child: _isUIReady 
                                    ? Text(
                                        'Cadastro',
                                        style: AppTextStyles.buttonText.copyWith(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )
                                    : SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: AppDimensions.paddingLarge),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  /// Navega para a página de login com verificação robusta
  void _navigateToLogin() {
    _safeNavigate('/login');
  }
  
  /// Navega para a página de cadastro com verificação robusta
  void _navigateToRegister() {
    _safeNavigate('/register');
  }

  /// Método de navegação segura que gerencia GoRouter availability
  Future<void> _safeNavigate(String route) async {
    try {
      // Primeiro, marca o onboarding como completado
      await _markOnboardingCompleted();
      
      // Verifica se o widget ainda está montado
      if (!mounted) return;
      
      // Verifica se o GoRouter está disponível no contexto
      final router = GoRouter.maybeOf(context);
      if (router != null) {
        context.go(route);
      } else {
        // GoRouter não está disponível, tenta novamente após pequeno delay
        debugPrint('🔀 GoRouter não disponível, tentando novamente...');
        await Future.delayed(const Duration(milliseconds: 100));
        
        if (mounted) {
          // Segunda tentativa
          final retryRouter = GoRouter.maybeOf(context);
          if (retryRouter != null) {
            context.go(route);
          } else {
            // Fallback final após mais um delay
            debugPrint('🔀 Segunda tentativa falhou, usando fallback...');
            await Future.delayed(const Duration(milliseconds: 200));
            
            if (mounted) {
              // Tentativa final
              try {
                context.go(route);
              } catch (e) {
                debugPrint('❌ Erro na navegação: $e');
                // Se mesmo assim falhar, tenta push como fallback
                try {
                  context.push(route);
                } catch (pushError) {
                  debugPrint('❌ Erro no push fallback: $pushError');
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Erro na navegação segura: $e');
      // Em caso de erro, tenta navegar diretamente como último recurso
      if (mounted) {
        try {
          context.go(route);
        } catch (fallbackError) {
          debugPrint('❌ Erro no fallback final: $fallbackError');
        }
      }
    }
  }
  
  Future<void> _markOnboardingCompleted() async {
    try {
      await OnboardingService.setOnboardingCompleted();
      if (widget.onCompleted != null) {
        widget.onCompleted!();
      }
    } catch (e) {
      debugPrint('❌ Erro ao marcar onboarding como completo: $e');
    }
  }
}
