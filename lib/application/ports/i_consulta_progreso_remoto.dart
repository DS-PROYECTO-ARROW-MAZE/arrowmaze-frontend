import 'progreso_remoto_item.dart';

/// Port for reading server-side progression — `GET /progress` (Ticket 24, AC2).
///
/// Separate from the write-only [IRepositorioProgreso] (`POST /progress/sync`)
/// and from the device-local [ConsultaProgresoLocal]. This port answers "what
/// levels has the authenticated player cleared on the server and with how many
/// stars" so a returning player's progress can be restored on login.
abstract interface class IConsultaProgresoRemoto {
  /// Fetches the authenticated player's progression records from the server.
  ///
  /// Returns a list of items — one per cleared level — or throws if the request
  /// fails (offline, 401, 500, …). The caller is responsible for graceful
  /// degradation.
  Future<List<ProgresoRemotoItem>> obtenerProgreso();
}