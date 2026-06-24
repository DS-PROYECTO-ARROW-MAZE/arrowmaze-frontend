import 'dart:async';

import '../../application/ports/reloj.dart';

/// A [Reloj] backed by a `dart:async` [Timer].
class RelojTimer implements Reloj {
  Timer? _timer;

  @override
  void iniciar(Duration intervalo, void Function() tic) {
    _timer?.cancel();
    _timer = Timer.periodic(intervalo, (_) => tic());
  }

  @override
  void detener() {
    _timer?.cancel();
    _timer = null;
  }
}
