/// The narrow, stable contract every use case satisfies (DM-F9).
///
/// A use case maps a single input [E] (entrada) to an output [S] (salida).
/// Keeping it generic and asynchronous lets cross-cutting concerns be added by
/// composition — see [DecoradorCasoDeUso] — instead of editing the use case or
/// scattering framework code through the domain (AOP via SOLID, ADR-0004).
abstract interface class ICasoDeUso<E, S> {
  /// Runs the use case for [entrada] and yields its [S] result.
  Future<S> ejecutar(E entrada);
}
