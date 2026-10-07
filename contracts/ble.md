# Contrato BLE — SmartShoulder v1

**Fuente de verdad** del protocolo entre la XIAO, la app Flutter y la herramienta de captura.
Cualquier cambio aquí se refleja en el mismo commit en:
`firmware/smartshoulder/config.h`, `tools/capture/contract.py` y `app/lib/core/contract/ble_contract.dart`.

Todos los enteros son **little-endian**.

## Identidad

- Nombre de advertising: `SS-XXXX` (XXXX = últimos 2 bytes de la MAC en hex). Es el código corto que se imprime en la carcasa y que ve el fisio.
- UUID base: `0ed8XXXX-8e11-4ac8-bea3-882874982696`

| Elemento | UUID | Propiedades |
|---|---|---|
| Servicio SmartShoulder | `0ed80001-8e11-4ac8-bea3-882874982696` | — |
| `CONTROL` | `0ed80002-8e11-4ac8-bea3-882874982696` | Write, Write without response |
| `EVENTS` | `0ed80003-8e11-4ac8-bea3-882874982696` | Notify |
| `RAW_STREAM` | `0ed80004-8e11-4ac8-bea3-882874982696` | Notify |
| `STATUS` | `0ed80005-8e11-4ac8-bea3-882874982696` | Read, Notify |
| Battery Service | `0x180F` / Battery Level `0x2A19` | Read, Notify (%) |

## `CONTROL`: `[cmd:u8][payload…]`

| cmd | Nombre | Payload | Efecto |
|---|---|---|---|
| `0x01` | `START_SESSION` | opcional `u8 raw_batch` (1–8) | Inferencia: inicia sesión (reinicia `seq` y reloj). Captura: empieza a transmitir `RAW_STREAM` desde `sample_index = 0`, con `raw_batch` muestras por paquete. El central lo calcula con su MTU: `min(8, (mtu − 7) / 12)`; si no lo manda, se usa 1 (cabe en el MTU mínimo de 23) |
| `0x02` | `STOP_SESSION` | — | Termina la sesión o la transmisión; en inferencia emite `SESSION_END` |
| `0x03` | `SET_ARM` | `u8` 0 = derecho, 1 = izquierdo | Brazo que se rehabilita (espejado de ejes) |
| `0x04` | `SET_MODE` | `u8` 0 = inferencia, 1 = captura | Solo se acepta fuera de sesión |
| `0x05` | `SET_EXPECTED` | `u8 exercise_id` (0 = ninguno) | La app indica el ejercicio de la serie actual; el dispositivo solo cuenta repeticiones si el clasificador coincide |
| `0x06` | `SYNC_EVENTS` | `u16 from_seq` | Reenvía por `EVENTS` los eventos con `seq ≥ from_seq` guardados en el búfer |
| `0x07` | `IDENTIFY` | — | Parpadea el LED azul 3 s (para encontrar el reloj correcto en consulta) |

## `EVENTS` (12 bytes)

```
u8  type          1 = REP, 2 = EXERCISE_CHANGED, 3 = SESSION_END
u8  exercise_id   catálogo abajo
u16 rep_index     REP: número de repetición dentro de la serie actual
u8  confidence    softmax × 255
u8  reserved
u32 timestamp_ms  desde START_SESSION
u16 seq           consecutivo desde 0; huecos = eventos perdidos → SYNC_EVENTS
```

## `RAW_STREAM` (solo modo captura)

```
u32 first_sample_index          índice de la primera muestra del paquete (50 Hz → t_ms = index × 20)
N × { i16 ax, ay, az, gx, gy, gz }   valores crudos del LSM6DS3, N = (len − 4) / 12
```

Escalas (fijas; si cambian hay que reentrenar):
- Acelerómetro ±4 g → `g = raw × 0.000122`
- Giroscopio ±500 dps → `dps = raw × 0.0175`

## `STATUS` (6 bytes)

```
u8 state      0 = IDLE, 1 = SESSION_ACTIVE, 2 = LOW_BATTERY
u8 mode       0 = inferencia, 1 = captura
u8 arm        0 = derecho, 1 = izquierdo
u8 fw_ver
u8 model_ver  0 = sin modelo
u8 raw_batch  muestras por paquete de RAW_STREAM
```

## Catálogo de `exercise_id`

| ID | Ejercicio |
|---|---|
| 0 | NULO (no ejercicio) |
| 1 | Flexión anterior |
| 2 | Abducción |
| 3 | Rotación externa |
| 4 | Rotación interna |
| 5 | Extensión de tríceps |
| 6 | Estabilización escapular |

## Consola serial (desarrollo y respaldo de captura)

115200 baud. Comandos de texto terminados en `\n`: `start`, `stop`, `mode capture`, `mode inference`, `arm R`, `arm L`, `status`.
En captura, cada muestra se imprime como `D,<sample_index>,<ax>,<ay>,<az>,<gx>,<gy>,<gz>` (valores crudos).
Las líneas que empiezan con `#` son mensajes informativos.
