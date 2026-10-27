"""Prueba guiada del firmware v2 por Bluetooth: ¿cuenta el ejercicio esperado y rechaza los demás?

  python tools/prueba_v2.py                        # flexión esperada, brazo derecho
  python tools/prueba_v2.py --esperado 2 --otro 1  # abducción esperada, flexiones como ejercicio equivocado
  python tools/prueba_v2.py --brazo L

Guion (~90 s): quieto · 5 reps del esperado · descanso · 5 reps de otro ejercicio · quieto.
El reloj solo manda REP cuando acepta la repetición; las rechazadas no llegan (por serial sí se ven).
"""
from __future__ import annotations

import argparse
import asyncio
import struct
import sys
import time
from pathlib import Path

from bleak import BleakClient, BleakScanner

UUID_CONTROL = "0ed80002-8e11-4ac8-bea3-882874982696"
UUID_EVENTS = "0ed80003-8e11-4ac8-bea3-882874982696"
UUID_STATUS = "0ed80005-8e11-4ac8-bea3-882874982696"
UUID_BATTERY = "00002a19-0000-1000-8000-00805f9b34fb"

EXERCISES = {0: "NULO", 1: "Flexión anterior", 2: "Abducción", 3: "Rotación externa", 4: "Rotación interna",
             5: "Extensión de tríceps", 6: "Estabilización escapular"}
EV_REP, EV_CHANGED, EV_END = 1, 2, 3


def phases(expected: int, other: int) -> list[tuple[float, float, str, str]]:
    """(inicio_s, fin_s, clave, instrucción)."""
    return [
        (0, 10, "quieto", "Quédate QUIETO, brazo relajado"),
        (10, 40, "esperado", f"Haz 5 repeticiones de {EXERCISES[expected].upper()} (lento, ~5 s cada una)"),
        (40, 50, "quieto", "DESCANSA, brazo quieto"),
        (50, 80, "otro", f"Ahora 5 repeticiones de {EXERCISES[other].upper()} (deben RECHAZARSE)"),
        (80, 90, "quieto", "Quédate QUIETO"),
    ]


def phase_at(plan, t: float):
    for p in plan:
        if p[0] <= t < p[1]:
            return p
    return None


async def run(a) -> None:
    print("Buscando el reloj (RR-XXXX)...")
    devs = await BleakScanner.discover(timeout=8)
    rr = [d for d in devs if (d.name or "").startswith("RR-") and (not a.nombre or d.name == a.nombre)]
    if not rr:
        print("No encontré el reloj. ¿Está encendido? (presiona reset o conéctalo al USB)")
        return
    dev = rr[0]
    plan = phases(a.esperado, a.otro)
    log = open(a.log, "w", encoding="utf-8")
    reps: list[tuple[float, int, int, int]] = []   # (t_s, ejercicio, rep_index, confianza)
    t_start = [0.0]

    def on_event(_c, data: bytearray):
        typ, ex, idx, conf, _r, ts, seq = struct.unpack("<BBHBBIH", bytes(data[:12]))
        t = time.time() - t_start[0]
        if typ == EV_REP:
            reps.append((t, ex, idx, conf))
            p = phase_at(plan, t)
            print(f"\n    >>> REP {idx} aceptada · {EXERCISES.get(ex, ex)} · confianza {conf / 255:.0%}"
                  f" (fase: {p[2] if p else 'fin'})")
        log.write(f"{t:.2f},ev,{typ},{ex},{idx},{conf},{ts},{seq}\n")
        log.flush()

    async with BleakClient(dev) as c:
        bat = (await c.read_gatt_char(UUID_BATTERY))[0]
        st = await c.read_gatt_char(UUID_STATUS)
        print(f"Conectado a {dev.name} · batería {bat}% · fw {st[3]} · modelo v{st[4]}")
        if st[4] == 0:
            print("Ojo: el reloj no tiene modelo cargado; contará sin verificar el ejercicio.")
        await c.start_notify(UUID_EVENTS, on_event)
        w = lambda *b: c.write_gatt_char(UUID_CONTROL, bytes(b), response=True)
        await w(0x02)                                  # por si quedó una sesión abierta
        await w(0x04, 0)                               # modo inferencia
        await w(0x03, 0 if a.brazo == "R" else 1)
        print(f"\nPonte el reloj en la muñeca {'DERECHA' if a.brazo == 'R' else 'IZQUIERDA'}.")
        for i in range(5, 0, -1):
            print(f"\rEmpezamos en {i}...", end="", flush=True)
            await asyncio.sleep(1)
        t_start[0] = time.time()
        await w(0x01)                                  # START_SESSION
        await w(0x05, a.esperado)                      # SET_EXPECTED
        print(f"\rSesión iniciada · ejercicio esperado: {EXERCISES[a.esperado]}\n")
        shown = None
        while (t := time.time() - t_start[0]) < plan[-1][1]:
            p = phase_at(plan, t)
            if p is not shown:
                print(f"\n[{int(p[0]):2d}–{int(p[1]):2d} s] {p[3]}")
                shown = p
            print(f"\r    {int(p[1] - t):2d} s", end="", flush=True)
            await asyncio.sleep(0.25)
        await w(0x02)                                  # STOP_SESSION
        await asyncio.sleep(1)
    log.close()

    ok = sum(1 for r in reps if phase_at(plan, r[0]) and phase_at(plan, r[0])[2] == "esperado")
    leaked = sum(1 for r in reps if phase_at(plan, r[0]) and phase_at(plan, r[0])[2] == "otro")
    still = len(reps) - ok - leaked
    print("\n\n=== Resultado ===")
    print(f"  {EXERCISES[a.esperado]} contadas: {ok} de 5")
    print(f"  {EXERCISES[a.otro]} aceptadas por error: {leaked} de 5 (ideal 0)")
    print(f"  Repeticiones en reposo: {still} (ideal 0)")
    if reps:
        print(f"  Confianza media: {sum(r[3] for r in reps) / len(reps) / 255:.0%}")
    print(f"  Registro: {Path(a.log).resolve()}")


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("--esperado", type=int, default=1, help="exercise_id que el reloj debe contar")
    ap.add_argument("--otro", type=int, default=2, help="exercise_id que harás y debe rechazarse")
    ap.add_argument("--brazo", choices=["R", "L"], default="R")
    ap.add_argument("--nombre", help="p. ej. RR-54F5, si hay varios relojes")
    ap.add_argument("--log", default="prueba_v2.csv")
    asyncio.run(run(ap.parse_args()))


if __name__ == "__main__":
    main()
