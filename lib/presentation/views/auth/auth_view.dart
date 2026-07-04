import 'package:flutter/material.dart';

import '../../../core/i18n/cadenas_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../viewmodels/auth_view_model.dart';

/// Register / Login screen — a thin View that only draws.
///
/// It owns no auth logic: it observes its [AuthViewModel] (a `ChangeNotifier`)
/// and forwards field changes and button taps to the ViewModel. Every
/// user-facing string is read from [CadenasScope] — no literals in this View
/// (AC3). The design follows the Dark Mode Neón Minimalista palette via theme
/// tokens.
///
/// Navigation is a View concern: once the ViewModel reports an authenticated
/// session — or the user chooses to continue as a guest — the View replaces
/// itself with the screen built by [construirInicio] (the Level Selection menu).
/// The builder is injected by the composition root so this View never references
/// the DI graph.
class AuthView extends StatefulWidget {
  const AuthView({
    required this.viewModel,
    required this.construirInicio,
    super.key,
  });

  final AuthViewModel viewModel;

  /// Builds the first screen shown once the user is authenticated or continues
  /// as a guest (injected by the composition root).
  final WidgetBuilder construirInicio;

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  final _formKey = GlobalKey<FormState>();

  /// Guards against navigating more than once (the ViewModel may notify several
  /// times after the session becomes valid).
  bool _navego = false;

  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_alCambiarEstado);
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_alCambiarEstado);
    widget.viewModel.dispose();
    super.dispose();
  }

  void _alCambiarEstado() {
    if (widget.viewModel.estado.autenticado) {
      _irAlJuego();
    }
  }

  /// Replaces the auth screen with the Level Selection menu. Used both on
  /// successful authentication and for the guest bypass.
  void _irAlJuego() {
    if (_navego || !mounted) return;
    _navego = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: widget.construirInicio),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = CadenasScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: ListenableBuilder(
          listenable: widget.viewModel,
          builder: (context, _) {
            final estado = widget.viewModel.estado;
            return Text(estado.esRegistro ? s.crearCuenta : s.iniciarSesion);
          },
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: ListenableBuilder(
                listenable: widget.viewModel,
                builder: (context, _) {
                  final estado = widget.viewModel.estado;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'ArrowMaze',
                        style: AppTypography.displayLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        estado.esRegistro
                            ? s.crearCuentaSubtitulo
                            : s.iniciarSesionSubtitulo,
                        style: AppTypography.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // Username field (register only)
                      if (estado.esRegistro) ...[
                        TextFormField(
                          decoration: InputDecoration(
                            labelText: s.campoUsuario,
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                          initialValue: estado.username,
                          onChanged: widget.viewModel.cambiarUsername,
                          validator: estado.esRegistro
                              ? (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? s.requerido
                                      : null
                              : null,
                          enabled: !estado.cargando,
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],

                      // Email field
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: s.campoEmail,
                          prefixIcon: const Icon(Icons.email_outlined),
                        ),
                        initialValue: estado.email,
                        onChanged: widget.viewModel.cambiarEmail,
                        validator: (v) =>
                            (v == null || !v.contains('@'))
                                ? s.emailInvalido
                                : null,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !estado.cargando,
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Password field
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: s.campoContrasena,
                          prefixIcon: const Icon(Icons.lock_outline),
                        ),
                        initialValue: estado.password,
                        onChanged: widget.viewModel.cambiarPassword,
                        validator: (v) =>
                            (v == null || v.length < 6)
                                ? s.contrasenaMinima
                                : null,
                        obscureText: true,
                        enabled: !estado.cargando,
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // Error message
                      if (estado.mensajeError != null) ...[
                        Text(
                          estado.mensajeError!,
                          style: const TextStyle(
                            color: AppColors.errorNeon,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],

                      // Submit button
                      FilledButton(
                        onPressed:
                            estado.cargando ? null : _enviar,
                        child: estado.cargando
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.background,
                                ),
                              )
                            : Text(
                                estado.esRegistro
                                    ? s.registrar
                                    : s.iniciarSesion,
                              ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Toggle mode
                      TextButton(
                        onPressed: estado.cargando
                            ? null
                            : widget.viewModel.alternarModo,
                        child: Text(
                          estado.esRegistro
                              ? s.yaTieneCuenta
                              : s.noTieneCuenta,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Guest bypass
                      TextButton(
                        onPressed: estado.cargando ? null : _irAlJuego,
                        child: Text(s.continuarInvitado),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _enviar() async {
    if (_formKey.currentState?.validate() ?? false) {
      await widget.viewModel.enviar();
    }
  }
}
