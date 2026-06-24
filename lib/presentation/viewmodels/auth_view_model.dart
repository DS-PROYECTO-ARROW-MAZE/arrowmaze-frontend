import 'package:flutter/foundation.dart';

import '../../application/ports/proveedor_sesion.dart';
import '../../application/use_cases/cerrar_sesion_use_case.dart';
import '../../application/use_cases/iniciar_sesion_use_case.dart';
import '../../application/use_cases/registrar_usuario_use_case.dart';
import '../../application/use_cases/resultado_inicio_sesion.dart';
import '../../application/use_cases/resultado_registro.dart';
import 'auth_view_state.dart';

/// The View's only collaborator for authentication flows.
///
/// Wraps [RegistrarUsuarioUseCase] and [IniciarSesionUseCase], manages form
/// field state, and publishes [AuthViewState] snapshots. Everything is driven
/// through the injected ports — no static accessors, no global state.
class AuthViewModel extends ChangeNotifier {
  AuthViewModel({
    required ProveedorSesion proveedorSesion,
    required CerrarSesionUseCase cerrarSesion,
    RegistrarUsuarioUseCase? registrarUsuario,
    IniciarSesionUseCase? iniciarSesion,
  })  : _proveedorSesion = proveedorSesion,
        _cerrarSesion = cerrarSesion,
        _registroUseCase = registrarUsuario,
        _loginUseCase = iniciarSesion {
    _verificarSesion();
  }

  final ProveedorSesion _proveedorSesion;
  final CerrarSesionUseCase _cerrarSesion;
  final RegistrarUsuarioUseCase? _registroUseCase;
  final IniciarSesionUseCase? _loginUseCase;

  AuthViewState _estado = const AuthViewState();

  /// The current immutable state the View renders.
  AuthViewState get estado => _estado;

  /// Toggles between register and login mode.
  void alternarModo() {
    _estado = _estado.copyWith(
      esRegistro: !_estado.esRegistro,
      mensajeError: null,
    );
    notifyListeners();
  }

  /// Updates the email field.
  void cambiarEmail(String valor) {
    _estado = _estado.copyWith(email: valor, mensajeError: null);
    notifyListeners();
  }

  /// Updates the password field.
  void cambiarPassword(String valor) {
    _estado = _estado.copyWith(password: valor, mensajeError: null);
    notifyListeners();
  }

  /// Updates the username field (register only).
  void cambiarUsername(String valor) {
    _estado = _estado.copyWith(username: valor, mensajeError: null);
    notifyListeners();
  }

  /// Attempts register or login depending on [_estado.esRegistro].
  Future<void> enviar() async {
    if (_estado.cargando) return;

    _estado = _estado.copyWith(cargando: true, mensajeError: null);
    notifyListeners();

    final resultado = _estado.esRegistro
        ? await _registrar()
        : await _iniciarSesion();

    _estado = _estado.copyWith(
      cargando: false,
      autenticado: resultado.exitoso,
      mensajeError: resultado.mensajeError,
    );
    notifyListeners();
  }

  /// Clears the session and signs the user out.
  Future<void> cerrarSesion() async {
    await _cerrarSesion.ejecutar();
    _estado = const AuthViewState(sesionCerrada: true);
    notifyListeners();
  }

  /// Checks on construction whether a session already exists.
  Future<void> _verificarSesion() async {
    final token = await _proveedorSesion.obtenerToken();
    if (token != null) {
      _estado = _estado.copyWith(autenticado: true);
      notifyListeners();
    }
  }

  Future<AuthResultado> _registrar() async {
    final useCase = _registroUseCase;
    if (useCase == null) {
      return AuthResultado(mensajeError: 'Register is not configured');
    }
    final resultado = await useCase.ejecutar(
      email: _estado.email,
      password: _estado.password,
    );
    return switch (resultado) {
      RegistroExitoso() => const AuthResultado(exitoso: true),
      RegistroEmailDuplicado() => const AuthResultado(
          mensajeError: 'That email is already registered.',
        ),
      RegistroError(:final mensaje) => AuthResultado(mensajeError: mensaje),
    };
  }

  Future<AuthResultado> _iniciarSesion() async {
    final useCase = _loginUseCase;
    if (useCase == null) {
      return AuthResultado(mensajeError: 'Login is not configured');
    }
    final resultado = await useCase.ejecutar(
      email: _estado.email,
      password: _estado.password,
    );
    return switch (resultado) {
      InicioSesionExitoso() => const AuthResultado(exitoso: true),
      InicioSesionCredencialesInvalidas() => const AuthResultado(
          mensajeError: 'Invalid email or password.',
        ),
      InicioSesionError(:final mensaje) => AuthResultado(mensajeError: mensaje),
    };
  }
}

/// Internal result type for the ViewModel's auth flows.
class AuthResultado {
  const AuthResultado({this.exitoso = false, this.mensajeError});

  final bool exitoso;
  final String? mensajeError;
}
