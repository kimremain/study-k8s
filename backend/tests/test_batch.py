import json
from datetime import date

import pytest

from batch.main import build_summary, main, parse_run_date

def test_parse_run_date():
  assert parse_run_date("2026-08-14") == date(2026, 8, 14)

def test_parse_run_date_rejects_invalid_value():
  with pytest.raises(ValueError, match="YYYY-MM-DD"):
    parse_run_date("2026/08/14")

def test_build_summary():
  records = [
    {"source": "orders", "count": 10},
    {"source": "refunds", "count": 2},
  ]

  result = build_summary(date(2026, 8, 14), records)

  assert result["status"] == "success"
  assert result["total_count"] == 12
  assert result["source_count"] == 2

def test_main_outputs_json(capsys):
  assert main(["--run-date", "2026-08-14"]) == 0

  result = json.loads(capsys.readouterr().out)
  assert result["run_date"] == "2026-08-14"
  assert result["total_count"] == 24
