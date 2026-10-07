import 'package:flutter_test/flutter_test.dart';
import 'package:smartshoulder/core/contract.dart';
import 'package:smartshoulder/core/models.dart';
import 'package:smartshoulder/features/session/session_engine.dart';

const flex = PlanExercise(exerciseId: 1, name: 'Flexión anterior', instructions: '', sets: 2, reps: 3, restSec: 2);
const abd = PlanExercise(exerciseId: 2, name: 'Abducción', instructions: '', sets: 1, reps: 2, restSec: 0);

void main() {
  group('sesión verificada', () {
    test('cuenta solo reps del ejercicio esperado y solo durante la serie', () {
      final e = SessionEngine([flex, abd], verified: true)..start();
      expect(e.onDeviceRep(2), isEmpty); // no es el ejercicio esperado
      e.onDeviceRep(1);
      e.onDeviceRep(1);
      expect(e.repsInSet, 2);
      final ev = e.onDeviceRep(1);
      expect(ev, containsAll([EngineEvent.repCounted, EngineEvent.setCompleted, EngineEvent.restStarted]));
      expect(e.phase, Phase.rest);
      expect(e.onDeviceRep(1), isEmpty); // en descanso no cuenta
      expect(e.results[0].repsDone, 3);
    });

    test('el descanso termina solo y arranca la siguiente serie, luego el siguiente ejercicio', () {
      final e = SessionEngine([flex, abd], verified: true)..start();
      for (var i = 0; i < 3; i++) {
        e.onDeviceRep(1);
      }
      e.tick();
      expect(e.tick(), [EngineEvent.setStarted]);
      expect(e.setIndex, 1);
      for (var i = 0; i < 3; i++) {
        e.onDeviceRep(1);
      }
      expect(e.skipRest(), [EngineEvent.exerciseStarted, EngineEvent.setStarted]);
      expect(e.current.exerciseId, 2);
    });

    test('descanso de 0 s pasa directo y la última serie termina la sesión', () {
      final e = SessionEngine([abd], verified: true)..start();
      e.onDeviceRep(2);
      expect(e.onDeviceRep(2), contains(EngineEvent.finished));
      expect(e.phase, Phase.finished);
      expect(e.endedEarly, isFalse);
      expect(e.totalDone, 2);
    });

    test('"Terminé la serie" no inventa reps: conserva lo que contó el reloj', () {
      final e = SessionEngine([flex], verified: true)..start();
      e.onDeviceRep(1);
      e.finishSetManually(reps: 99);
      expect(e.results[0].repsDone, 1);
      expect(e.results[0].setsDone, 1);
    });
  });

  group('sesión reportada', () {
    test('marcar la serie registra las reps prescritas o las que diga el paciente', () {
      final e = SessionEngine([flex], verified: false)..start();
      e.finishSetManually();
      e.skipRest();
      e.finishSetManually(reps: 2);
      expect(e.phase, Phase.finished);
      expect(e.results[0].repsDone, 5);
      expect(e.results[0].setsDone, 2);
    });
  });

  test('terminar antes de tiempo queda marcado', () {
    final e = SessionEngine([flex, abd], verified: true)..start();
    e.onDeviceRep(1);
    e.endEarly();
    expect(e.endedEarly, isTrue);
    expect(e.results.map((r) => r.toJson()).first, {'exerciseId': 1, 'setsDone': 0, 'repsDone': 1});
  });

  test('saltar ejercicio conserva lo hecho', () {
    final e = SessionEngine([flex, abd], verified: true)..start();
    e.onDeviceRep(1);
    e.skipExercise();
    expect(e.current.exerciseId, 2);
    expect(e.results[0].repsDone, 1);
  });

  group('contrato BLE', () {
    test('EVENTS de 12 bytes little-endian', () {
      final ev = DeviceEvent.parse([1, 3, 7, 0, 230, 0, 0x10, 0x27, 0, 0, 5, 1]);
      expect(ev.type, EventType.rep);
      expect(ev.exerciseId, 3);
      expect(ev.repIndex, 7);
      expect(ev.confidence, 230);
      expect(ev.timestampMs, 10000);
      expect(ev.seq, 261);
    });
    test('EVENTS corto se rechaza', () {
      expect(() => DeviceEvent.parse([1, 2, 3]), throwsFormatException);
    });
  });
}
