import '../ports/i_caso_de_uso.dart';

/// Base Decorator (GoF) over [ICasoDeUso] (DM-F9).
///
/// Holds the wrapped use case (or inner decorator) and forwards to it by
/// default. Concrete decorators override [ejecutar] to add a single
/// cross-cutting concern around [envuelto] — metrics, logging, security — so
/// behaviour composes by wrapping and the inner use case is never edited
/// (AOP via SOLID, ADR-0004).
abstract class DecoradorCasoDeUso<E, S> implements ICasoDeUso<E, S> {
  /// Wraps [envuelto], the next link in the decorator chain.
  const DecoradorCasoDeUso(this.envuelto);

  /// The decorated use case (a leaf use case or another decorator).
  final ICasoDeUso<E, S> envuelto;

  @override
  Future<S> ejecutar(E entrada) => envuelto.ejecutar(entrada);
}
