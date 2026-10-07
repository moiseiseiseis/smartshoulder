import csv
import datetime as dt
import struct

import pytest

from contract import parse_raw_packet, parse_status, to_physical
from recorder import Recorder, Subject


def packet(first, samples):
    return struct.pack("<I", first) + b"".join(struct.pack("<6h", *s) for s in samples)


def read_csv(path):
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.reader(f))


def test_parse_raw_packet_batch():
    s = [(1, -2, 3, -4, 5, -6), (8197, 0, -8197, 1000, 0, -1000)]
    first, out = parse_raw_packet(packet(42, s))
    assert first == 42 and out == s


def test_parse_raw_packet_rejects_bad_length():
    with pytest.raises(ValueError):
        parse_raw_packet(b"\x00" * 15)


def test_parse_status():
    assert parse_status(bytes([1, 1, 0, 1, 0, 8])) == {
        "state": 1, "mode": 1, "arm": 0, "fw": 1, "model": 0, "raw_batch": 8}


def test_to_physical_scales():
    ax, *_, gz = to_physical((8197, 0, 0, 0, 0, 5714))
    assert ax == pytest.approx(1.0, abs=1e-3)      # 1 g
    assert gz == pytest.approx(100.0, abs=0.01)    # 100 dps


@pytest.fixture
def rec(tmp_path):
    r = Recorder(tmp_path)
    r.start(Subject("S01", "F", "165", "R", "R"), dt.date(2026, 10, 8))
    return r


def test_files_and_names(rec, tmp_path):
    assert rec.raw_path == tmp_path / "raw" / "S01_R_2026-10-08.csv"
    rec.stop()
    again = Recorder(tmp_path)
    again.start(Subject("S01", "F", "165", "R", "R"), dt.date(2026, 10, 8))
    assert again.raw_path.name == "S01_R_2026-10-08_2.csv"      # nunca se sobrescribe un crudo
    subjects = read_csv(tmp_path / "subjects.csv")
    assert len(subjects) == 2                                   # encabezado + un sujeto sin duplicar


def test_raw_rows_timestamps_and_gaps(rec):
    rec.add_samples(0, [(0,) * 6] * 3)
    rec.add_samples(5, [(0,) * 6])            # faltan 3 y 4
    rec.stop()
    rows = read_csv(rec.raw_path)
    assert [r[0] for r in rows[1:]] == ["0", "20", "40", "100"]
    assert rec.lost_samples == 2


def test_device_reset_keeps_time_monotonic(rec):
    rec.add_samples(0, [(0,) * 6] * 10)
    rec.add_samples(0, [(0,) * 6] * 2)        # el contador del dispositivo volvió a 0
    rec.stop()
    times = [int(r[0]) for r in read_csv(rec.raw_path)[1:]]
    assert times == sorted(times) and len(set(times)) == len(times)


def test_labels_sets_reps_and_discard(rec):
    rec.add_samples(0, [(0,) * 6] * 50)
    rec.start_set(1, "normal")
    rec.add_samples(50, [(0,) * 6] * 50)
    assert rec.mark_rep() == 1
    rec.add_samples(100, [(0,) * 6] * 50)
    rec.end_set()
    rec.start_set(1, "lenta")
    rec.end_set()
    labels = read_csv(rec.labels_path)
    assert labels[1] == ["980", "2980", "1", "1", "normal", "1980"]
    assert labels[2][3] == "2"                                    # segunda serie del mismo ejercicio
    rec.discard_last()
    assert len(read_csv(rec.labels_path)) == 2
    assert rec.next_set_number(1) == 2
