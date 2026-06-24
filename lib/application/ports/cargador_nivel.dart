import 'definicion_nivel_dto.dart';

abstract interface class CargadorNivel {
  Future<DefinicionNivelDto> cargar(int id);
}
