import '../ports/i_caso_de_uso.dart';

/// Adapts a plain function into an [ICasoDeUso] so existing use cases can be
/// wrapped by the decorator stack **without being edited** (ADR-0004).
///
/// The composition root lifts a use case method (e.g. `obtenerTop`) into this
/// adapter, then layers metrics/logging/security decorators around it. The use
/// case itself stays free of any cross-cutting concern.
class CasoDeUsoAccion<E, S> implements ICasoDeUso<E, S> {
  /// Wraps [accion] — the work the leaf use case performs for an [E] input.
  const CasoDeUsoAccion(this._accion);

  final Future<S> Function(E entrada) _accion;

  @override
  Future<S> ejecutar(E entrada) => _accion(entrada);
}
