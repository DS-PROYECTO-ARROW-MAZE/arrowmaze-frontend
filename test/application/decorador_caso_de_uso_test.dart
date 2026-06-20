import 'package:arrowmaze/application/decoradores/decorador_metricas_caso_de_uso.dart';
import 'package:arrowmaze/application/decoradores/decorador_registro_caso_de_uso.dart';
import 'package:arrowmaze/application/decoradores/decorador_seguridad_caso_de_uso.dart';
import 'package:arrowmaze/application/decoradores/sesion_requerida_exception.dart';
import 'package:arrowmaze/application/ports/i_caso_de_uso.dart';
import 'package:arrowmaze/application/ports/i_medidor_metricas.dart';
import 'package:arrowmaze/application/ports/i_registro.dart';
import 'package:arrowmaze/application/ports/proveedor_sesion.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _RegistroSpy extends Mock implements IRegistro {}

class _MetricasSpy extends Mock implements IMedidorMetricas {}

class _SesionSpy extends Mock implements ProveedorSesion {}

/// A trivial use case under test: doubles its input. It is the thing decorated.
class _DuplicarUseCase implements ICasoDeUso<int, int> {
  int llamadas = 0;

  @override
  Future<int> ejecutar(int entrada) async {
    llamadas++;
    return entrada * 2;
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  group('DecoradorCasoDeUso stack', () {
    late _RegistroSpy registro;
    late _MetricasSpy metricas;
    late _SesionSpy sesion;
    late _DuplicarUseCase base;

    setUp(() {
      registro = _RegistroSpy();
      metricas = _MetricasSpy();
      sesion = _SesionSpy();
      base = _DuplicarUseCase();
      when(() => sesion.obtenerToken()).thenAnswer((_) async => 'token-123');
    });

    /// Builds the full stack: seguridad → registro → métricas → base.
    ICasoDeUso<int, int> construirStack() {
      return DecoradorSeguridadCasoDeUso<int, int>(
        DecoradorRegistroCasoDeUso<int, int>(
          DecoradorMetricasCasoDeUso<int, int>(
            base,
            metricas: metricas,
            nombre: 'duplicar',
          ),
          registro: registro,
          nombre: 'duplicar',
        ),
        sesion: sesion,
      );
    }

    test('should_return_same_result_when_wrapped_by_decorators', () async {
      // Arrange
      final decorado = construirStack();

      // Act
      final salida = await decorado.ejecutar(21);

      // Assert — identical to the undecorated use case (AC1).
      expect(salida, 42);
      expect(salida, await base.ejecutar(21));
    });

    test('should_invoke_metrics_logging_security_ports_when_executed',
        () async {
      // Arrange
      final decorado = construirStack();

      // Act
      await decorado.ejecutar(5);

      // Assert — every cross-cutting port is exercised (AC1).
      verify(() => sesion.obtenerToken()).called(1);
      verify(() => registro.info(any())).called(greaterThanOrEqualTo(1));
      verify(
        () => metricas.registrar(
          any(),
          duracion: any(named: 'duracion'),
          exito: any(named: 'exito'),
        ),
      ).called(1);
    });

    test('should_read_session_via_injected_ProveedorSesion_when_securing',
        () async {
      // Arrange — security alone, given the injected session port (AC3).
      final decorado = DecoradorSeguridadCasoDeUso<int, int>(base, sesion: sesion);

      // Act
      final salida = await decorado.ejecutar(7);

      // Assert — session was read through the injected port, not a static one.
      expect(salida, 14);
      verify(() => sesion.obtenerToken()).called(1);
    });

    test('should_block_execution_when_no_session_token', () async {
      // Arrange — no token means an unauthenticated caller.
      when(() => sesion.obtenerToken()).thenAnswer((_) async => null);
      final decorado = DecoradorSeguridadCasoDeUso<int, int>(base, sesion: sesion);

      // Act / Assert — the wrapped use case never runs.
      await expectLater(
        () => decorado.ejecutar(7),
        throwsA(isA<SesionRequeridaException>()),
      );
      expect(base.llamadas, 0);
    });
  });
}
