"""SmartShoulder — herramienta de captura del dataset (contexto/05 §3).

Uso:  python app.py [carpeta_dataset]      (por defecto: ../../dataset)

Teclas:  ESPACIO = iniciar / terminar serie    R = marcar repetición
"""
from __future__ import annotations

import queue
import sys
import time
import tkinter as tk
from collections import deque
from pathlib import Path
from tkinter import messagebox, ttk

import matplotlib
matplotlib.use("TkAgg")
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
from matplotlib.figure import Figure

import contract as c
from recorder import Recorder, Subject
from transport import BleSource, SerialSource

SPEEDS = [("normal", "Normal"), ("lenta", "Lenta"), ("rapida", "Rápida")]
NULO_SPEED = "natural"
PLOT_SECONDS = 10
PLOT_POINTS = PLOT_SECONDS * 50


class CaptureApp:
    def __init__(self, root: tk.Tk, dataset_dir: Path):
        self.root = root
        self.q: queue.Queue = queue.Queue()
        self.ble = BleSource(self.q)
        self.serial = SerialSource(self.q)
        self.source = None
        self.recorder = Recorder(dataset_dir)
        self.dataset_dir = dataset_dir
        self.connected = False
        self.selected: tuple[int, str] = (1, "normal")
        self.plot_t = deque(maxlen=PLOT_POINTS)
        self.plot_v = [deque(maxlen=PLOT_POINTS) for _ in range(6)]
        self.rate_window: deque = deque()
        self.last_plot = 0.0
        self.device_status: dict | None = None
        self.battery: int | None = None

        root.title("SmartShoulder — Captura de dataset")
        root.geometry("1400x860")
        self._build_ui()
        root.bind("<space>", self._on_space)
        root.bind("<KeyPress-r>", self._on_rep)
        root.bind("<KeyPress-R>", self._on_rep)
        root.protocol("WM_DELETE_WINDOW", self._on_close)
        self._refresh()
        root.after(30, self._poll)

    # ================= UI =================
    def _build_ui(self):
        style = ttk.Style()
        style.configure("Big.TButton", font=("Segoe UI", 16, "bold"), padding=12)
        style.configure("Cell.TButton", padding=4)
        style.configure("Done.TButton", padding=4, foreground="#1a7f37")
        style.configure("Sel.TButton", padding=4, foreground="#0550ae", font=("Segoe UI", 9, "bold"))

        left = ttk.Frame(self.root, padding=8)
        left.pack(side="left", fill="y")
        right = ttk.Frame(self.root, padding=8)
        right.pack(side="right", fill="both", expand=True)

        # --- Conexión ---
        f = ttk.LabelFrame(left, text="1. Reloj", padding=6)
        f.pack(fill="x", pady=4)
        self.transport_var = tk.StringVar(value="ble")
        ttk.Radiobutton(f, text="Bluetooth", variable=self.transport_var, value="ble",
                        command=self._on_transport).grid(row=0, column=0, sticky="w")
        ttk.Radiobutton(f, text="Cable USB", variable=self.transport_var, value="serial",
                        command=self._on_transport).grid(row=0, column=1, sticky="w")
        self.device_combo = ttk.Combobox(f, width=18, state="readonly")
        self.device_combo.grid(row=1, column=0, columnspan=2, sticky="we", pady=2)
        self.btn_scan = ttk.Button(f, text="Buscar", command=self._on_scan)
        self.btn_scan.grid(row=1, column=2, padx=2)
        self.btn_connect = ttk.Button(f, text="Conectar", command=self._on_connect)
        self.btn_connect.grid(row=2, column=0, sticky="we")
        self.btn_identify = ttk.Button(f, text="Identificar (LED)", command=lambda: self.source and self.source.identify())
        self.btn_identify.grid(row=2, column=1, columnspan=2, sticky="we")
        self.device_info = ttk.Label(f, text="Sin conexión", foreground="#666")
        self.device_info.grid(row=3, column=0, columnspan=3, sticky="w")

        # --- Sujeto ---
        f = ttk.LabelFrame(left, text="2. Participante", padding=6)
        f.pack(fill="x", pady=4)
        self.subj = {k: tk.StringVar(value=v) for k, v in
                     dict(id=self._next_subject_id(), sex="F", height="", dom="R", arm="R").items()}
        row = 0
        for label, key, widget in [("ID anónimo", "id", "entry"), ("Sexo", "sex", ("F", "M", "Otro")),
                                   ("Estatura (cm)", "height", "entry"), ("Brazo dominante", "dom", ("R", "L")),
                                   ("Brazo que se graba", "arm", ("R", "L"))]:
            ttk.Label(f, text=label).grid(row=row, column=0, sticky="w")
            if widget == "entry":
                ttk.Entry(f, textvariable=self.subj[key], width=10).grid(row=row, column=1, sticky="w")
            else:
                ttk.Combobox(f, textvariable=self.subj[key], values=widget, width=7,
                             state="readonly").grid(row=row, column=1, sticky="w")
            row += 1
        self.btn_record = ttk.Button(f, text="Iniciar grabación", command=self._on_record)
        self.btn_record.grid(row=row, column=0, columnspan=2, sticky="we", pady=(6, 0))
        self.file_label = ttk.Label(f, text="", foreground="#666", wraplength=330)
        self.file_label.grid(row=row + 1, column=0, columnspan=2, sticky="w")

        # --- Protocolo ---
        f = ttk.LabelFrame(left, text="3. Protocolo (clic para elegir)", padding=6)
        f.pack(fill="x", pady=4)
        self.cells: dict[tuple[int, str], ttk.Button] = {}
        for col, (_, title) in enumerate(SPEEDS):
            ttk.Label(f, text=title).grid(row=0, column=col + 1)
        for r, ex in enumerate(range(1, 7), start=1):
            ttk.Label(f, text=f"{ex}. {c.EXERCISES[ex]}").grid(row=r, column=0, sticky="w")
            for col, (speed, _) in enumerate(SPEEDS):
                b = ttk.Button(f, width=6, command=lambda k=(ex, speed): self._select(k))
                b.grid(row=r, column=col + 1, padx=1, pady=1)
                self.cells[(ex, speed)] = b
        ttk.Label(f, text="0. NULO (3–5 min)").grid(row=7, column=0, sticky="w")
        b = ttk.Button(f, width=6, command=lambda: self._select((0, NULO_SPEED)))
        b.grid(row=7, column=1, padx=1, pady=1)
        self.cells[(0, NULO_SPEED)] = b

        # --- Serie ---
        f = ttk.LabelFrame(left, text="4. Serie", padding=6)
        f.pack(fill="x", pady=4)
        self.set_label = ttk.Label(f, text="", font=("Segoe UI", 12, "bold"), wraplength=330)
        self.set_label.pack(fill="x")
        self.btn_set = ttk.Button(f, text="", style="Big.TButton", command=self._toggle_set)
        self.btn_set.pack(fill="x", pady=4)
        self.btn_rep = ttk.Button(f, text="R · Marcar repetición", command=self._mark_rep)
        self.btn_rep.pack(fill="x")
        row = ttk.Frame(f)
        row.pack(fill="x", pady=(4, 0))
        ttk.Button(row, text="Cancelar serie", command=self._cancel_set).pack(side="left", expand=True, fill="x")
        ttk.Button(row, text="Descartar última", command=self._discard_last).pack(side="left", expand=True, fill="x")

        # --- Estado ---
        self.stats = ttk.Label(left, text="", font=("Consolas", 9), justify="left")
        self.stats.pack(fill="x", pady=4)

        # --- Gráfica y bitácora ---
        self.fig = Figure(figsize=(9, 6.5), dpi=100)
        self.ax_acc = self.fig.add_subplot(211)
        self.ax_gyr = self.fig.add_subplot(212, sharex=self.ax_acc)
        colors = ["#d1242f", "#1a7f37", "#0969da"]
        self.lines_acc = [self.ax_acc.plot([], [], color=col, lw=1, label=n)[0] for col, n in zip(colors, "xyz")]
        self.lines_gyr = [self.ax_gyr.plot([], [], color=col, lw=1, label=n)[0] for col, n in zip(colors, "xyz")]
        self.ax_acc.set_ylabel("Acelerómetro (g)")
        self.ax_acc.set_ylim(-4.2, 4.2)
        self.ax_gyr.set_ylabel("Giroscopio (dps)")
        self.ax_gyr.set_ylim(-520, 520)
        self.ax_gyr.set_xlabel("tiempo (s)")
        for ax in (self.ax_acc, self.ax_gyr):
            ax.grid(alpha=0.3)
            ax.legend(loc="upper left", fontsize=8)
        self.span_acc = self.span_gyr = None
        self.fig.tight_layout()
        self.canvas = FigureCanvasTkAgg(self.fig, master=right)
        self.canvas.get_tk_widget().pack(fill="both", expand=True)
        self.log_box = tk.Text(right, height=9, font=("Consolas", 9), state="disabled")
        self.log_box.pack(fill="x")

    # ================= Acciones =================
    def _on_transport(self):
        self.device_combo.set("")
        if self.transport_var.get() == "serial":
            self.device_combo["values"] = SerialSource.ports()
        else:
            self.device_combo["values"] = []

    def _on_scan(self):
        if self.transport_var.get() == "serial":
            self._on_transport()
            return
        self.log("Buscando relojes SmartShoulder…")
        self.ble.scan(lambda names: self.q.put(("scan", names)))

    def _on_connect(self):
        if self.connected:
            if self.recorder.recording and not messagebox.askyesno("Desconectar", "Hay una grabación en curso. ¿Desconectar?"):
                return
            self.source.disconnect()
            return
        target = self.device_combo.get()
        if not target:
            messagebox.showinfo("Reloj", "Primero busca y elige un reloj (o un puerto COM).")
            return
        self.source = self.serial if self.transport_var.get() == "serial" else self.ble
        self.source.connect(target)

    def _on_record(self):
        if self.recorder.recording:
            self.source.stop_capture()
            self.recorder.stop()
            self.log(f"Grabación terminada: {self.recorder.total_samples} muestras, "
                     f"{self.recorder.lost_samples} perdidas, {len(self.recorder.labels)} series")
            self.subj["id"].set(self._next_subject_id())
            self._refresh()
            return
        if not self.connected:
            messagebox.showinfo("Grabación", "Conecta el reloj primero.")
            return
        s = self.subj
        if not s["id"].get().strip():
            messagebox.showinfo("Grabación", "Falta el ID del participante.")
            return
        subject = Subject(s["id"].get().strip().upper(), s["sex"].get(), s["height"].get().strip(),
                          s["dom"].get(), s["arm"].get())
        path = self.recorder.start(subject)
        self.source.start_capture(c.ARM_LEFT if subject.recorded_arm == "L" else c.ARM_RIGHT)
        self.plot_t.clear()
        for d in self.plot_v:
            d.clear()
        self.log(f"Grabando {subject.subject_id} brazo {subject.recorded_arm} → {path}")
        self._select(self._next_pending() or (1, "normal"))
        self._refresh()

    def _select(self, key):
        if self.recorder.current:
            return                      # no cambiar de ejercicio a mitad de una serie
        self.selected = key
        self._refresh()

    def _toggle_set(self):
        if not self.recorder.recording:
            return
        if self.recorder.current:
            done = self.recorder.end_set()
            dur = (done.end_ms - done.start_ms) / 1000
            self.log(f"✓ {c.EXERCISES[done.exercise_id]} · {done.speed} · serie {done.set} · "
                     f"{dur:.1f} s · {len(done.rep_markers)} marcas")
            nxt = self._next_pending()
            if nxt:
                self.selected = nxt
        else:
            if self.recorder.total_samples == 0:
                messagebox.showwarning("Serie", "No están llegando datos del reloj.")
                return
            ex, speed = self.selected
            self.recorder.start_set(ex, speed)
        self._refresh()

    def _mark_rep(self):
        n = self.recorder.mark_rep()
        if n:
            self._refresh()

    def _cancel_set(self):
        self.recorder.cancel_set()
        self.log("Serie cancelada (no se guardó)")
        self._refresh()

    def _discard_last(self):
        if self.recorder.current or not self.recorder.labels:
            return
        last = self.recorder.labels[-1]
        if messagebox.askyesno("Descartar", f"¿Descartar {c.EXERCISES[last.exercise_id]} · {last.speed} · serie {last.set}?"):
            self.recorder.discard_last()
            self.selected = (last.exercise_id, last.speed)
            self.log("Última serie descartada (el crudo se conserva; solo se borra la etiqueta)")
            self._refresh()

    def _on_space(self, event):
        if isinstance(event.widget, (tk.Entry, ttk.Entry, ttk.Combobox)):
            return
        self._toggle_set()
        return "break"

    def _on_rep(self, event):
        if isinstance(event.widget, (tk.Entry, ttk.Entry)):
            return
        self._mark_rep()

    def _on_close(self):
        if self.recorder.recording:
            if not messagebox.askyesno("Salir", "Hay una grabación en curso. ¿Terminarla y salir?"):
                return
            self.source.stop_capture()
            self.recorder.stop()
        self.root.destroy()

    # ================= Datos =================
    def _poll(self):
        try:
            while True:
                self._handle(self.q.get_nowait())
        except queue.Empty:
            pass
        now = time.monotonic()
        if now - self.last_plot > 0.15:
            self.last_plot = now
            self._redraw()
            self._update_stats()
        self.root.after(30, self._poll)

    def _handle(self, msg):
        kind = msg[0]
        if kind == "samples":
            _, first, samples = msg
            self.recorder.add_samples(first, samples)
            for i, raw in enumerate(samples):
                self.plot_t.append((first + i) * c.SAMPLE_PERIOD_MS / 1000)
                for ch, v in enumerate(c.to_physical(raw)):
                    self.plot_v[ch].append(v)
            self.rate_window.append((time.monotonic(), len(samples)))
        elif kind == "conn":
            self.connected = msg[1]
            if not self.connected and self.recorder.recording:
                self.log("⚠ Se perdió la conexión durante la grabación. Reconecta y vuelve a iniciar la grabación "
                         "(se crea un archivo nuevo; las series ya guardadas no se pierden).")
                self.recorder.stop()
            self._refresh()
        elif kind == "status":
            st = msg[1]
            self.device_status = st
            self._refresh()
        elif kind == "battery":
            self.battery = msg[1]
            self._refresh()
        elif kind == "scan":
            names = msg[1]
            self.device_combo["values"] = names
            if names:
                self.device_combo.set(names[0])
            self.log(f"Encontrados: {', '.join(names) or 'ninguno'}")
        elif kind == "log":
            self.log(msg[1])

    def _measured_hz(self) -> float:
        now = time.monotonic()
        while self.rate_window and now - self.rate_window[0][0] > 2.0:
            self.rate_window.popleft()
        return sum(n for _, n in self.rate_window) / 2.0

    # ================= Refresco de pantalla =================
    def _refresh(self):
        rec = self.recorder
        self.btn_connect.config(text="Desconectar" if self.connected else "Conectar")
        info = "Conectado" if self.connected else "Sin conexión"
        if self.connected and self.device_status:
            st = self.device_status
            info += f" · fw {st['fw']} · lote {st['raw_batch']}"
        if self.connected and self.battery is not None:
            info += f" · batería {self.battery}%"
        self.device_info.config(text=info)

        self.btn_record.config(text="Terminar grabación" if rec.recording else "Iniciar grabación")
        self.file_label.config(text=str(rec.raw_path.relative_to(self.dataset_dir.parent)) if rec.recording else "")

        done = {(l.exercise_id, l.speed) for l in rec.labels} if rec.recording else set()
        for key, b in self.cells.items():
            mark = "✓" if key in done else "·"
            b.config(text=mark, style="Sel.TButton" if key == self.selected else
                     ("Done.TButton" if key in done else "Cell.TButton"))

        ex, speed = self.selected
        if rec.current:
            cur = rec.current
            self.set_label.config(text=f"● GRABANDO  {c.EXERCISES[cur.exercise_id]} · {cur.speed} · serie {cur.set}"
                                       f"   —   {len(cur.rep_markers)} marcas", foreground="#cf222e")
            self.btn_set.config(text="ESPACIO · Terminar serie")
        else:
            nxt = rec.next_set_number(ex) if rec.recording else 1
            self.set_label.config(text=f"Siguiente: {c.EXERCISES[ex]} · {speed} · serie {nxt}", foreground="")
            self.btn_set.config(text="ESPACIO · Iniciar serie")
        state = "normal" if rec.recording else "disabled"
        self.btn_set.config(state=state)
        self.btn_rep.config(state="normal" if rec.current else "disabled")

    def _update_stats(self):
        rec = self.recorder
        hz = self._measured_hz()
        dur = rec.now_ms / 1000 if rec.recording else 0
        warn = "  ⚠ revisa" if rec.recording and (hz < 45 or rec.lost_samples > 0) else ""
        self.stats.config(text=f"Frecuencia: {hz:5.1f} Hz (meta 50){warn}\n"
                               f"Muestras:   {rec.total_samples}   perdidas: {rec.lost_samples}\n"
                               f"Duración:   {int(dur // 60)}:{int(dur % 60):02d}   series: {len(rec.labels)}")

    def _redraw(self):
        if not self.plot_t:
            return
        t = list(self.plot_t)
        for i, line in enumerate(self.lines_acc):
            line.set_data(t, list(self.plot_v[i]))
        for i, line in enumerate(self.lines_gyr):
            line.set_data(t, list(self.plot_v[3 + i]))
        t1 = t[-1]
        self.ax_acc.set_xlim(max(0, t1 - PLOT_SECONDS), max(PLOT_SECONDS, t1))
        for span in (self.span_acc, self.span_gyr):
            if span:
                span.remove()
        self.span_acc = self.span_gyr = None
        if self.recorder.current:
            t0 = self.recorder.current.start_ms / 1000
            self.span_acc = self.ax_acc.axvspan(t0, t1, color="#cf222e", alpha=0.08)
            self.span_gyr = self.ax_gyr.axvspan(t0, t1, color="#cf222e", alpha=0.08)
        self.canvas.draw_idle()

    # ================= Utilidades =================
    def _next_pending(self):
        done = {(l.exercise_id, l.speed) for l in self.recorder.labels}
        order = [(ex, sp) for ex in range(1, 7) for sp, _ in SPEEDS] + [(0, NULO_SPEED)]
        return next((k for k in order if k not in done), None)

    def _next_subject_id(self) -> str:
        raw = self.dataset_dir / "raw"
        ids = {p.name.split("_")[0] for p in raw.glob("S*_*.csv")} if raw.exists() else set()
        nums = [int(i[1:]) for i in ids if i[1:].isdigit()]
        return f"S{(max(nums) + 1) if nums else 1:02d}"

    def log(self, text: str):
        self.log_box.config(state="normal")
        self.log_box.insert("end", f"{time.strftime('%H:%M:%S')}  {text}\n")
        self.log_box.see("end")
        self.log_box.config(state="disabled")


def main():
    dataset = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[2] / "dataset"
    root = tk.Tk()
    CaptureApp(root, dataset)
    root.mainloop()


if __name__ == "__main__":
    main()
