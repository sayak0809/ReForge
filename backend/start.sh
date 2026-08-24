#!/bin/sh
set -e
python -u create_tables.py
exec uvicorn app.main:app --host 0.0.0.0 --port "$PORT"
