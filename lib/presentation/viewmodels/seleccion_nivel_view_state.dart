import '../../domain/tablero.dart';

class SeleccionNivelViewState {
  const SeleccionNivelViewState({
    this.tablero,
    this.cargando = false,
    this.mensajeError,
  });

  final Tablero? tablero;
  final bool cargando;
  final String? mensajeError;

  SeleccionNivelViewState copiarCon({
    Tablero? tablero,
    bool? cargando,
    String? mensajeError,
  }) {
    return SeleccionNivelViewState(
      tablero: tablero ?? this.tablero,
      cargando: cargando ?? this.cargando,
      mensajeError: mensajeError ?? this.mensajeError,
    );
  }
}
