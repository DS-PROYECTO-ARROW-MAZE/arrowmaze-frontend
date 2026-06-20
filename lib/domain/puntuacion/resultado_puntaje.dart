/// The immutable result of computing a level's [puntaje] and [estrellas] (DM-F6).
///
/// Returned by [CalcularPuntuacionUseCase.calcular]. Identical inputs always
/// produce identical outputs, ensuring client–backend agreement (AC5).
class ResultadoPuntaje {
  /// Creates a scoring result.
  const ResultadoPuntaje({required this.puntaje, required this.estrellas});

  /// The final computed score, floored at 0.
  final int puntaje;

  /// The star rating: 0, 1, 2, or 3, determined by the level's thresholds.
  final int estrellas;
}
