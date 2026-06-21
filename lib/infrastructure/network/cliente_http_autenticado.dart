import 'package:http/http.dart' as http;

import '../../application/ports/proveedor_sesion.dart';

/// HTTP interceptor that transparently authenticates outgoing requests (AC3).
///
/// Wraps an inner [http.Client] and, on every request, reads the current
/// session token through the injected [ProveedorSesion] and attaches an
/// `Authorization: Bearer <token>` header. When no token exists (the user is
/// signed out, or the call targets a public route) the request passes through
/// untouched.
///
/// Being an [http.BaseClient], it is a drop-in replacement for `http.Client`:
/// data sources depend on `http.Client` and never learn that auth is happening
/// — the cross-cutting concern lives here, in infrastructure, exactly once.
class ClienteHttpAutenticado extends http.BaseClient {
  /// Creates the authenticated client around an [inner] transport.
  ///
  /// [inner] defaults to a fresh [http.Client]; tests inject a mock.
  ClienteHttpAutenticado({
    required ProveedorSesion proveedorSesion,
    http.Client? inner,
  })  : _proveedorSesion = proveedorSesion,
        _inner = inner ?? http.Client();

  final ProveedorSesion _proveedorSesion;
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final token = await _proveedorSesion.obtenerToken();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
