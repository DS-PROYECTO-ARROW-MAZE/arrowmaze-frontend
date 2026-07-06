/// A single server-side progression record returned by `GET /progress`
/// (Ticket 24, backend ticket 18).
///
/// One item per cleared level. Carries the backend level UUID, the star rating
/// (0‑3), and the score so the client can merge with local data keeping the best.
class ProgresoRemotoItem {
  /// Creates a remote progression item from the server's shape.
  const ProgresoRemotoItem({
    required this.nivelId,
    required this.estrellas,
    required this.puntaje,
  });

  /// The backend level UUID (e.g. `"a1b2c3d4-..."`).
  final String nivelId;

  /// Best star rating for this level on the server (0‑3).
  final int estrellas;

  /// Best score for this level on the server.
  final int puntaje;
}