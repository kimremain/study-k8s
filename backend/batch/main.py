import argparse
import json
import os
from datetime import date, datetime, timezone
from typing import Sequence

SAMPLE_RECORDS = [
  {"source": "orders", "count": 12},
  {"source": "payments", "count": 11},
  {"source": "refunds", "count": 1},
]

def parse_run_date(value: str) -> date:
  try:
    return date.fromisoformat(value)
  except ValueError as exc:
    raise ValueError(
      f"잘못된 날짜 형식입니다: {value}. YYYY-MM-DD 형식을 사용하세요."
    ) from exc

def build_summary(run_date: date, records: Sequence[dict]) -> dict:
  return {
    "status": "success",
    "run_date": run_date.isoformat(),
    "source_count": len(records),
    "total_count": sum(record["count"] for record in records),
    "sources": list(records),
    "processed_at": datetime.now(timezone.utc).isoformat(),
  }

def main(argv: Sequence[str] | None = None) -> int:
  parser = argparse.ArgumentParser(description="GKE 배치 처리 파일럿")
  parser.add_argument(
    "--run-date",
    default=os.environ.get("RUN_DATE"),
    help="처리 기준일(YYYY-MM-DD)",
  )
  args = parser.parse_args(argv)

  if not args.run_date:
    parser.error("--run-date 인수 또는 RUN_DATE 환경변수가 필요합니다.")

  try:
    run_date = parse_run_date(args.run_date)
  except ValueError as exc:
    parser.error(str(exc))

  print(
    json.dumps(
      build_summary(run_date, SAMPLE_RECORDS),
      ensure_ascii=False,
      sort_keys=True,
    )
  )
  return 0

if __name__ == "__main__":
  raise SystemExit(main())
