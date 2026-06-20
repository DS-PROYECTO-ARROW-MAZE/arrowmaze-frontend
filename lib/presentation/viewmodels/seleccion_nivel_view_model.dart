import 'package:flutter/foundation.dart';

import '../../application/generadores/configuracion_generacion.dart';
import '../../application/generadores/generacion_por_archivo_nivel.dart';
import 'seleccion_nivel_view_state.dart';

class SeleccionNivelViewModel extends ChangeNotifier {
  SeleccionNivelViewModel({
    required this.generadorArchivo,
  });

  final GeneracionPorArchivoNivel generadorArchivo;
  late SeleccionNivelViewState _estado;

  SeleccionNivelViewState get estado => _estado;

  void inicializar() {
    _estado = const SeleccionNivelViewState();
    notifyListeners();
  }

  Future<void> cargarNivel(int idNivel) async {
    _estado = _estado.copiarCon(cargando: true, mensajeError: null);
    notifyListeners();

    try {
      final tablero = await generadorArchivo.generarAsync(
        ConfiguracionGeneracion(filas: 0, columnas: 0),
        idNivel: idNivel,
      );

      if (tablero != null) {
        _estado = _estado.copiarCon(
          tablero: tablero,
          cargando: false,
        );
      } else {
        _estado = _estado.copiarCon(
          cargando: false,
          mensajeError: 'El nivel no es resoluble',
        );
      }
    } catch (e) {
      _estado = _estado.copiarCon(
        cargando: false,
        mensajeError: 'Error al cargar el nivel: $e',
      );
    }
    notifyListeners();
  }
}
