import '../../core/models.dart';

enum Phase { ready, active, rest, finished }

/// Lo que pasó como consecuencia de una acción (la pantalla lo convierte en voz y animación).
enum EngineEvent { exerciseStarted, setStarted, repCounted, setCompleted, restStarted, finished }

class ExerciseResult {
  final int exerciseId;
  int setsDone = 0;
  int repsDone = 0;
  ExerciseResult(this.exerciseId);

  Map<String, dynamic> toJson() => {'exerciseId': exerciseId, 'setsDone': setsDone, 'repsDone': repsDone};
}

/// Flujo de la sesión: ejercicio → series → descanso → siguiente. Sin Flutter, para poder probarlo.
///
/// - Verificada: las repeticiones llegan del reloj y solo cuentan si son del ejercicio esperado.
/// - Reportada: el paciente marca "Terminé la serie".
/// Al completar las repeticiones de la serie empieza solo el descanso; al acabar el descanso, sola la siguiente serie.
class SessionEngine {
  final List<PlanExercise> plan;
  final bool verified;
  late final List<ExerciseResult> results = [for (final e in plan) ExerciseResult(e.exerciseId)];

  Phase phase = Phase.ready;
  int exIndex = 0;
  int setIndex = 0; // 0-based
  int repsInSet = 0;
  int restLeft = 0;
  bool endedEarly = false;
  DateTime? startedAt;
  DateTime? endedAt;

  SessionEngine(this.plan, {required this.verified}) {
    if (plan.isEmpty) throw ArgumentError('La sesión necesita al menos un ejercicio');
  }

  PlanExercise get current => plan[exIndex];
  PlanExercise? get next {
    if (setIndex + 1 < current.sets) return current;
    return exIndex + 1 < plan.length ? plan[exIndex + 1] : null;
  }

  int get totalPrescribed => plan.fold(0, (a, e) => a + e.sets * e.reps);
  int get totalDone => results.fold(0, (a, r) => a + r.repsDone);

  List<EngineEvent> start([DateTime? now]) {
    if (phase != Phase.ready) return const [];
    startedAt = now ?? DateTime.now();
    phase = Phase.active;
    return const [EngineEvent.exerciseStarted, EngineEvent.setStarted];
  }

  /// Repetición del reloj. Solo cuenta durante una serie y si es del ejercicio esperado.
  List<EngineEvent> onDeviceRep(int exerciseId) {
    if (phase != Phase.active || exerciseId != current.exerciseId) return const [];
    repsInSet++;
    results[exIndex].repsDone++;
    if (repsInSet >= current.reps) return [EngineEvent.repCounted, ..._completeSet()];
    return const [EngineEvent.repCounted];
  }

  /// "Terminé la serie". En modo reportado registra las reps que dice el paciente (por defecto, las prescritas).
  /// En modo verificado solo cierra la serie con lo que contó el reloj.
  List<EngineEvent> finishSetManually({int? reps}) {
    if (phase != Phase.active) return const [];
    if (!verified) {
      final r = (reps ?? current.reps).clamp(0, 99);
      repsInSet = r;
      results[exIndex].repsDone += r;
    }
    return _completeSet();
  }

  List<EngineEvent> _completeSet() {
    results[exIndex].setsDone++;
    final last = setIndex + 1 >= current.sets && exIndex + 1 >= plan.length;
    if (last) return [EngineEvent.setCompleted, ..._finish(early: false)];
    phase = Phase.rest;
    restLeft = current.restSec;
    if (restLeft <= 0) return [EngineEvent.setCompleted, ..._advance()];
    return const [EngineEvent.setCompleted, EngineEvent.restStarted];
  }

  /// Un segundo de reloj de pared.
  List<EngineEvent> tick() {
    if (phase != Phase.rest) return const [];
    restLeft--;
    return restLeft <= 0 ? _advance() : const [];
  }

  List<EngineEvent> skipRest() => phase == Phase.rest ? _advance() : const [];

  /// Saltar el resto del ejercicio actual (lo hecho se conserva).
  List<EngineEvent> skipExercise() {
    if (phase == Phase.finished || phase == Phase.ready) return const [];
    if (exIndex + 1 >= plan.length) return _finish(early: true);
    exIndex++;
    setIndex = 0;
    repsInSet = 0;
    phase = Phase.active;
    return const [EngineEvent.exerciseStarted, EngineEvent.setStarted];
  }

  List<EngineEvent> _advance() {
    repsInSet = 0;
    if (setIndex + 1 < current.sets) {
      setIndex++;
      phase = Phase.active;
      return const [EngineEvent.setStarted];
    }
    exIndex++;
    setIndex = 0;
    phase = Phase.active;
    return const [EngineEvent.exerciseStarted, EngineEvent.setStarted];
  }

  /// El paciente toca "Terminar" antes de acabar.
  List<EngineEvent> endEarly() => phase == Phase.finished ? const [] : _finish(early: true);

  List<EngineEvent> _finish({required bool early}) {
    phase = Phase.finished;
    endedEarly = early;
    endedAt = DateTime.now();
    return const [EngineEvent.finished];
  }
}
