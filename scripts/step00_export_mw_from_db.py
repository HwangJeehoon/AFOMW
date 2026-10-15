"""MW raw DB(*_ResultInfo.db)를 trial별 MW CSV로 내보낸다.

출력: <root>/<subject>/<date>/raw/MW/<BARE|P1|P2|P3>.csv
SAH01/03의 MW CSV(DB를 Excel로 저장한 파일)와 같은 형식을 따른다.
  - UTF-8 BOM, CRLF, DB 컬럼 46개를 그대로 사용
  - p_trainingSaveTime은 Excel 'mm:ss.0' 표시처럼 분:초.0 (0.1 s 단위)
syncEMG 파일이 있으면 MW 시작 시각 - EMG 시작 시각을 출력해 trial 매핑을 확인한다.

사용법: python scripts/step00_export_mw_from_db.py SAH04
"""
import csv
import sqlite3
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# subject -> DB 위치와 날짜별 {p_trainingCompletionNumber: 파일명}
# 파일명 P1~P3는 시행 순서가 아니라 파라미터 번호다.
TARGETS = {
    "SAH04": {
        "db": "rawData_temp/12345673_*/*_ResultInfo.db",
        "trials": {
            "260728": {1: "BARE", 2: "P1", 3: "P2", 4: "P3"},
            "260804": {1: "BARE", 2: "P3", 3: "P2", 4: "P1"},
            "260811": {1: "BARE", 2: "P1", 3: "P2", 4: "P3"},
        },
    },
}

TIME_COL = "p_trainingSaveTime"
TIME_FMT = "%Y-%m-%d %H:%M:%S.%f"
KST = timezone(timedelta(hours=9))


def read_session(con, date, trial):
    """date('YYMMDD')의 trial번째 훈련 기록을 (header, rows)로 반환한다."""
    cur = con.execute(
        "SELECT * FROM patientTrainingResultInfoDB"
        " WHERE p_trainingCompletionYear = ? AND p_trainingCompletionMonth = ?"
        " AND p_trainingCompletionDay = ? AND p_trainingCompletionNumber = ?"
        " ORDER BY p_rowid",
        ("20" + date[:2], str(int(date[2:4])), str(int(date[4:])), trial))
    rows = cur.fetchall()
    if not rows:
        raise ValueError(f"DB에 {date} trial {trial} 기록이 없습니다.")
    return [c[0] for c in cur.description], rows


def format_value(col, v):
    if v is None:
        return ""
    if col == TIME_COL:
        # 정확히 .x50 s이면 내림: SAH03 원본 DB 기준 Excel 저장본과 99.95% 일치
        t = datetime.strptime(v, TIME_FMT) + timedelta(microseconds=49999)
        return f"{t.minute:02d}:{t.second:02d}.{t.microsecond // 100000}"
    if isinstance(v, float):
        return f"{v:.15g}"
    return str(v)


def read_sync(path):
    """syncEMG CSV를 {trial 이름(소문자): EMG 시작 Unix time}으로 읽는다."""
    if not path.exists():
        return {}
    with open(path, encoding="utf-8-sig", newline="") as f:
        return {r["Trial"].lower(): float(r["Time"]) for r in csv.DictReader(f)}


def main(subject):
    cfg = TARGETS[subject]
    [db] = ROOT.glob(cfg["db"])
    con = sqlite3.connect(f"{db.as_uri()}?mode=ro", uri=True)

    for date, trials in cfg["trials"].items():
        sync = read_sync(ROOT / subject / "sync_data" / f"syncEMG_{subject}_{date}.csv")
        out_dir = ROOT / subject / date / "raw" / "MW"
        out_dir.mkdir(parents=True, exist_ok=True)

        for trial, label in trials.items():
            header, rows = read_session(con, date, trial)
            out_path = out_dir / f"{label}.csv"
            if out_path.exists():
                raise FileExistsError(out_path)
            with open(out_path, "w", encoding="utf-8-sig", newline="") as f:
                w = csv.writer(f, lineterminator="\r\n")
                w.writerow(header)
                w.writerows([format_value(c, v) for c, v in zip(header, r)] for r in rows)

            msg = (f"{date} trial {trial} -> {label}.csv: {len(rows)} rows,"
                   f" rowid {rows[0][0]}-{rows[-1][0]}")
            if label.lower() in sync:
                t0 = datetime.strptime(rows[0][header.index(TIME_COL)], TIME_FMT)
                dt = t0.replace(tzinfo=KST).timestamp() - sync[label.lower()]
                msg += f", MW start - EMG start = {dt:+.0f} s"
            print(msg)

    con.close()


if __name__ == "__main__":
    main(sys.argv[1])
