"""Copia exacta de firmware/rumbo/repcounter.cpp (contexto/03 §6), en float32.

Si cambias un parámetro o la lógica aquí, cámbialo igual en el firmware (y viceversa).
Sirve para calibrar los umbrales con el dataset antes de flashearlos.
"""
from __future__ import annotations

from dataclasses import dataclass

import numpy as np

f32 = np.float32


@dataclass(frozen=True)
class RepParams:
    lp_alpha: float = 0.25        # pasa-bajas de 1er orden (~2–3 Hz)
    energy_alpha: float = 0.02    # ventana lenta (~1 s) para el eje dominante
    t_high: float = 25.0          # dps: inicio de movimiento (30 no alcanzaba rotaciones lentas de ~60°)
    t_low: float = 10.0           # dps: reposo (histéresis)
    min_rep: int = 40             # 0.8 s
    max_rep: int = 500            # 10 s
    refractory: int = 15          # 0.3 s
    accel: bool = False           # señal: giroscopio (dps) o acelerómetro sin gravedad (cg = g × 100)


FIRMWARE_PARAMS = RepParams()
BASE_ALPHA = 0.005               # línea base del acelerómetro (~4 s a 50 Hz)

# Umbrales por ejercicio (el reloj sabe cuál toca por SET_EXPECTED). Calibrados con S01 el 20 oct 2026
# (python -m rumbo_ml.calibrate). La escapular gira poco: se cuenta con el acelerómetro.
EXERCISE_PARAMS = {
    1: RepParams(t_high=40.0, t_low=16.0, min_rep=25),               # Flexión anterior
    2: RepParams(t_high=25.0, t_low=10.0, min_rep=40),               # Abducción
    3: RepParams(t_high=10.0, t_low=3.0, min_rep=25),                # Rotación externa
    4: RepParams(t_high=30.0, t_low=18.0, min_rep=25),               # Rotación interna
    5: RepParams(t_high=40.0, t_low=12.0, min_rep=25),               # Extensión de tríceps
    6: RepParams(t_high=8.0, t_low=2.4, min_rep=25, accel=True),     # Estabilización escapular
}


def params_for(exercise_id: int) -> RepParams:
    return EXERCISE_PARAMS.get(exercise_id, FIRMWARE_PARAMS)

IDLE, OUT, BACK = 0, 1, 2


class RepCounter:
    def __init__(self, p: RepParams = FIRMWARE_PARAMS):
        self.p = p
        self.reset()

    def reset(self) -> None:
        self.base = np.zeros(3, f32)
        self.warm = 0
        self.lp = np.zeros(3, f32)
        self.energy = np.zeros(3, f32)
        self.phase = IDLE
        self.axis = 0
        self.sign = 1
        self.samples_in_rep = 0
        self.samples_since_rep = 1000

    def update(self, sample: np.ndarray) -> bool:
        """sample: (6,) físico (g, dps). True si con esta muestra se completó una repetición."""
        p = self.p
        if p.accel:
            # Quita la gravedad con una línea base lenta (~4 s); arranca en la primera muestra.
            a = sample[:3].astype(f32)
            self.base = a.copy() if self.warm == 0 else self.base + f32(BASE_ALPHA) * (a - self.base)
            self.warm = 1
            g = (a - self.base) * f32(100.0)
        else:
            g = sample[3:].astype(f32)
        self.lp = self.lp + f32(p.lp_alpha) * (g - self.lp)
        self.energy = self.energy + f32(p.energy_alpha) * (self.lp * self.lp - self.energy)
        self.samples_since_rep += 1

        if self.phase == IDLE:
            if self.samples_since_rep < p.refractory:
                return False
            best = int(np.argmax(self.energy))   # empates → el primero, igual que el bucle en C
            if abs(self.lp[best]) > p.t_high:
                self.axis = best
                self.sign = 1 if self.lp[best] > 0 else -1
                self.phase = OUT
                self.samples_in_rep = 0
            return False

        self.samples_in_rep += 1
        if self.samples_in_rep > p.max_rep:
            self.phase = IDLE
            return False
        if self.phase == OUT:
            if self.lp[self.axis] * -self.sign > p.t_high:
                self.phase = BACK
            return False
        # BACK
        if abs(self.lp[self.axis]) < p.t_low:
            self.phase = IDLE
            if self.samples_in_rep < p.min_rep:
                return False
            self.samples_since_rep = 0
            return True
        return False


def count_reps(x: np.ndarray, params: RepParams = FIRMWARE_PARAMS) -> int:
    """x: (n, 6) físico. Repeticiones contadas en el segmento."""
    rc = RepCounter(params)
    return sum(rc.update(row) for row in x)
