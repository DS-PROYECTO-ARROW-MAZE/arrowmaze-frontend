import '../../application/ports/i_registro.dart';

/// Infrastructure adapter: an [IRegistro] that writes to standard output.
///
/// This is the *only* place a printing primitive is used. The application and
/// domain layers depend solely on the [IRegistro] port, so swapping this for a
/// file/remote sink requires no change above the composition root (AC2).
class RegistroConsola implements IRegistro {
  /// Creates a console logger.
  const RegistroConsola();

  @override
  void info(String mensaje) {
    // ignore: avoid_print — this adapter is the sanctioned console sink.
    print('[INFO] $mensaje');
  }

  @override
  void error(String mensaje) {
    // ignore: avoid_print — this adapter is the sanctioned console sink.
    print('[ERROR] $mensaje');
  }
}
