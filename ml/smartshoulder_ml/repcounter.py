"""Copia exacta de firmware/smartshoulder/repcounter.cpp (contexto/03 §6), en float32.

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


FIRMWARE_PARAMS = RepParams()

IDLE, OUT, BACK = 0, 1, 2


class RepCounter:
    def __init__(self, p: RepParams = FIRMWARE_PARAMS):
        self.p = p
        self.reset()

    def reset(self) -> None:
        self.lp = np.zeros(3, f32)
        self.energy = np.zeros(3, f32)
        self.phase = IDLE
        self.axis = 0
        self.sign = 1
        self.samples_in_rep = 0
        self.samples_since_rep = 1000

    def update(self, gyro_dps: np.ndarray) -> bool:
        """gyro_dps: (3,) en dps. True si con esta muestra se completó una repetición."""
        p = self.p
        g = gyro_dps.astype(f32)
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
    return sum(rc.update(row[3:]) for row in x)
