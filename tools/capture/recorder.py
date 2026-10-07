"""Escritura del dataset con el formato de contexto/05-specs-ejercicios-protocolo.md §3.5.

dataset/
  raw/S01_R_2026-10-08.csv     timestamp_ms, ax, ay, az, gx, gy, gz   (g y dps)
  labels/S01_R_2026-10-08.csv  start_ms, end_ms, exercise_id, set, speed, rep_markers
  subjects.csv                 subject_id, sex, height_cm, dominant_arm, recorded_arm

El crudo nunca se reescribe: se agrega fila por fila. Las etiquetas sí se reescriben completas
en cada cambio (para poder descartar la última serie).
"""
from __future__ import annotations

import csv
import datetime as dt
from dataclasses import dataclass, field
from pathlib import Path

from contract import SAMPLE_PERIOD_MS, to_physical

RAW_HEADER = ["timestamp_ms", "ax", "ay", "az", "gx", "gy", "gz"]
LABEL_HEADER = ["start_ms", "end_ms", "exercise_id", "set", "speed", "rep_markers"]
SUBJECT_HEADER = ["subject_id", "sex", "height_cm", "dominant_arm", "recorded_arm"]


@dataclass
class Label:
    start_ms: int
    end_ms: int | None
    exercise_id: int
    set: int
    speed: str
    rep_markers: list[int] = field(default_factory=list)

    def row(self) -> list:
        return [self.start_ms, self.end_ms, self.exercise_id, self.set, self.speed,
                ";".join(str(m) for m in self.rep_markers)]


@dataclass
class Subject:
    subject_id: str
    sex: str
    height_cm: str
    dominant_arm: str   # R / L
    recorded_arm: str   # R / L


class Recorder:
    def __init__(self, root: Path):
        self.root = Path(root)
        self.raw_file = None
        self.raw_writer = None
        self.labels: list[Label] = []
        self.current: Label | None = None
        self.subject: Subject | None = None
        self.raw_path: Path | None = None
        self.labels_path: Path | None = None
        self.last_index = -1
        self.index_offset = 0       # si el dispositivo se reinicia, el tiempo sigue avanzando
        self.lost_samples = 0
        self.total_samples = 0

    # ---------- sesión ----------
    @property
    def recording(self) -> bool:
        return self.raw_file is not None

    @property
    def now_ms(self) -> int:
        return max(self.last_index, 0) * SAMPLE_PERIOD_MS

    def start(self, subject: Subject, date: dt.date | None = None) -> Path:
        date = date or dt.date.today()
        (self.root / "raw").mkdir(parents=True, exist_ok=True)
        (self.root / "labels").mkdir(parents=True, exist_ok=True)
        stem = f"{subject.subject_id}_{subject.recorded_arm}_{date.isoformat()}"
        n = 1
        while (self.root / "raw" / f"{stem}.csv").exists():
            n += 1
            stem = f"{subject.subject_id}_{subject.recorded_arm}_{date.isoformat()}_{n}"
        self.raw_path = self.root / "raw" / f"{stem}.csv"
        self.labels_path = self.root / "labels" / f"{stem}.csv"
        self.raw_file = open(self.raw_path, "w", newline="", encoding="utf-8")
        self.raw_writer = csv.writer(self.raw_file)
        self.raw_writer.writerow(RAW_HEADER)
        self.subject = subject
        self.labels = []
        self.current = None
        self.last_index = -1
        self.index_offset = 0
        self.lost_samples = 0
        self.total_samples = 0
        self._write_labels()
        self._register_subject(subject)
        return self.raw_path

    def stop(self) -> None:
        if self.current:
            self.end_set()
        if self.raw_file:
            self.raw_file.close()
        self.raw_file = None
        self.raw_writer = None

    # ---------- datos ----------
    def add_samples(self, first_index: int, samples: list[tuple[int, ...]]) -> None:
        """Agrega muestras crudas; detecta huecos y reinicios del dispositivo."""
        if not self.recording:
            return
        index = first_index + self.index_offset
        if self.last_index >= 0 and index <= self.last_index:
            # El dispositivo reinició su contador: se continúa después de la última muestra.
            self.index_offset += self.last_index + 1 - index
            index = self.last_index + 1
        if self.last_index >= 0 and index > self.last_index + 1:
            self.lost_samples += index - self.last_index - 1
        for i, raw in enumerate(samples):
            t = (index + i) * SAMPLE_PERIOD_MS
            self.raw_writer.writerow([t] + [f"{v:.5f}" for v in to_physical(raw)])
        self.last_index = index + len(samples) - 1
        self.total_samples += len(samples)
        self.raw_file.flush()

    # ---------- etiquetas ----------
    def next_set_number(self, exercise_id: int) -> int:
        return 1 + sum(1 for l in self.labels if l.exercise_id == exercise_id)

    def start_set(self, exercise_id: int, speed: str) -> Label:
        if self.current:
            self.end_set()
        self.current = Label(self.now_ms, None, exercise_id, self.next_set_number(exercise_id), speed)
        return self.current

    def mark_rep(self) -> int | None:
        if not self.current:
            return None
        self.current.rep_markers.append(self.now_ms)
        return len(self.current.rep_markers)

    def end_set(self) -> Label | None:
        if not self.current:
            return None
        self.current.end_ms = self.now_ms
        done = self.current
        self.labels.append(done)
        self.current = None
        self._write_labels()
        return done

    def cancel_set(self) -> None:
        self.current = None

    def discard_last(self) -> Label | None:
        if not self.labels:
            return None
        removed = self.labels.pop()
        self._write_labels()
        return removed

    def _write_labels(self) -> None:
        with open(self.labels_path, "w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            w.writerow(LABEL_HEADER)
            for l in self.labels:
                w.writerow(l.row())

    def _register_subject(self, s: Subject) -> None:
        path = self.root / "subjects.csv"
        rows = []
        if path.exists():
            with open(path, newline="", encoding="utf-8") as f:
                rows = list(csv.DictReader(f))
        key = (s.subject_id, s.recorded_arm)
        rows = [r for r in rows if (r["subject_id"], r["recorded_arm"]) != key]
        rows.append({"subject_id": s.subject_id, "sex": s.sex, "height_cm": s.height_cm,
                     "dominant_arm": s.dominant_arm, "recorded_arm": s.recorded_arm})
        with open(path, "w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=SUBJECT_HEADER)
            w.writeheader()
            w.writerows(sorted(rows, key=lambda r: (r["subject_id"], r["recorded_arm"])))
