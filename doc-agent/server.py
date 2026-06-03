"""
Doc Agent HTTP Server — runs inside plane-aio container on port 8893.

Endpoints:
  GET  /health              liveness + Plane service status
  GET  /api/plane/status    status of all supervisord-managed processes
  POST /api/tasks           AI agent task (called by docker-manager-agent)
  WS   /ws/chat             streaming chat (proxied by orchestrator)
"""
import asyncio
import json
import os
import subprocess
from datetime import datetime
from pathlib import Path

import boto3
import psycopg2
from botocore.client import Config
from dotenv import load_dotenv
from fastapi import FastAPI, File, UploadFile, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse
import anthropic as _anthropic
from pydantic import BaseModel

AGENT_DIR = Path(__file__).parent
load_dotenv(AGENT_DIR / "agent.conf")

app = FastAPI(title="Doc Agent", version="1.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])


# ── Process detection (supervisorctl is broken in Alpine — use ps aux) ────────

_PROCESS_PATTERNS = {
    "nginx":         "nginx: master",
    "frontend":      "node /frontend/server.js",
    "gunicorn":      "gunicorn",
    "celery-worker": "celery.*worker",
    "celery-beat":   "celery.*beat",
}


def _plane_status() -> list[dict]:
    try:
        r = subprocess.run(["ps", "aux"], capture_output=True, text=True, timeout=5)
        ps_output = r.stdout
    except Exception as e:
        return [{"name": "ps", "status": "ERROR", "detail": str(e)}]

    import re
    results = []
    for name, pattern in _PROCESS_PATTERNS.items():
        found = bool(re.search(pattern, ps_output))
        results.append({
            "name":   name,
            "status": "RUNNING" if found else "STOPPED",
            "detail": "",
        })
    return results


def _all_running() -> bool:
    return all(p["status"] == "RUNNING" for p in _plane_status())


# ── Routes ────────────────────────────────────────────────────────────────────

@app.get("/")
def root():
    return RedirectResponse("/docs")


@app.get("/health")
def health():
    processes = _plane_status()
    all_up = all(p["status"] == "RUNNING" for p in processes)
    return {
        "status":    "ok" if all_up else "degraded",
        "agent":     "doc-agent",
        "processes": processes,
        "time":      datetime.utcnow().isoformat(),
    }


@app.get("/api/plane/status")
def plane_status():
    return {"processes": _plane_status()}


@app.post("/api/plane/restart/{process}")
def restart_process(process: str):
    out = _supervisorctl("restart", process)
    return {"output": out}


# ── AI task endpoint ──────────────────────────────────────────────────────────

class TaskRequest(BaseModel):
    task: str

@app.post("/api/tasks")
def run_task(req: TaskRequest):
    api_key = os.getenv("ANTHROPIC_API_KEY", "")
    if not api_key:
        return {"error": "ANTHROPIC_API_KEY not set"}
    client = _anthropic.Anthropic(api_key=api_key)
    status_summary = json.dumps(_plane_status(), indent=2)
    system = (
        "You are a documentation platform agent running inside the plane-aio Docker container. "
        "You can inspect Plane service status (nginx, gunicorn, celery, Next.js frontend). "
        f"Current process status:\n{status_summary}"
    )
    msg = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=1024,
        system=system,
        messages=[{"role": "user", "content": req.task}],
    )
    return {"result": msg.content[0].text}


# ── Paper upload ─────────────────────────────────────────────────────────────

_MINIO_ENDPOINT  = "http://plane-minio:9000"
_MINIO_KEY       = "plane-minio"
_MINIO_SECRET    = "plane_minio_pass"
_MINIO_BUCKET    = "uploads"
_PAPER_OBJECT    = "papers/main.pdf"
_PUBLIC_PDF_URL  = "http://localhost:9000/uploads/papers/main.pdf"

_DB_HOST = "mypostgresql_db-container"
_DB_PORT = 5432
_DB_NAME = "mydocsdb"
_DB_USER = "docs_user"
_DB_PASS = "docs_pass"


def _ensure_bucket_public(s3):
    try:
        s3.head_bucket(Bucket=_MINIO_BUCKET)
    except Exception:
        s3.create_bucket(Bucket=_MINIO_BUCKET)
    try:
        s3.put_bucket_policy(Bucket=_MINIO_BUCKET, Policy=json.dumps({
            "Version": "2012-10-17",
            "Statement": [{
                "Effect": "Allow", "Principal": "*",
                "Action": "s3:GetObject",
                "Resource": f"arn:aws:s3:::{_MINIO_BUCKET}/*"
            }]
        }))
    except Exception:
        pass


def _upload_to_minio(pdf_bytes: bytes):
    s3 = boto3.client(
        "s3",
        endpoint_url=_MINIO_ENDPOINT,
        aws_access_key_id=_MINIO_KEY,
        aws_secret_access_key=_MINIO_SECRET,
        config=Config(signature_version="s3v4"),
        region_name="us-east-1",
    )
    _ensure_bucket_public(s3)
    s3.put_object(
        Bucket=_MINIO_BUCKET,
        Key=_PAPER_OBJECT,
        Body=pdf_bytes,
        ContentType="application/pdf",
    )


def _update_page(pdf_url: str):
    html = (
        f'<p><a href="{pdf_url}" target="_blank">📄 Download compiled paper (PDF)</a></p>'
        f'<p><iframe src="{pdf_url}" width="100%" height="900" style="border:none;"></iframe></p>'
    )
    stripped = f"Compiled paper PDF — {pdf_url}"
    conn = psycopg2.connect(
        host=_DB_HOST, port=_DB_PORT,
        dbname=_DB_NAME, user=_DB_USER, password=_DB_PASS,
    )
    try:
        cur = conn.cursor()
        cur.execute(
            """UPDATE pages
               SET description_html=%s, description_stripped=%s,
                   description_binary=NULL, updated_at=NOW()
               WHERE name='output_paper'""",
            (html, stripped),
        )
        conn.commit()
        cur.close()
    finally:
        conn.close()


@app.post("/api/plane/upload-paper")
async def upload_paper(file: UploadFile = File(...)):
    if not file.filename.endswith(".pdf"):
        return {"error": "only PDF files accepted"}
    pdf_bytes = await file.read()
    try:
        _upload_to_minio(pdf_bytes)
    except Exception as e:
        return {"error": f"minio upload failed: {e}"}
    try:
        _update_page(_PUBLIC_PDF_URL)
    except Exception as e:
        return {"error": f"page update failed: {e}"}
    return {
        "status": "ok",
        "pdf_url": _PUBLIC_PDF_URL,
        "page": "output_paper",
        "plane_url": "http://localhost:8080",
    }


# ── WebSocket chat ────────────────────────────────────────────────────────────

@app.websocket("/ws/chat")
async def ws_chat(ws: WebSocket):
    await ws.accept()
    api_key = os.getenv("ANTHROPIC_API_KEY", "")
    client  = _anthropic.Anthropic(api_key=api_key) if api_key else None
    history: list = []
    try:
        while True:
            text = await ws.receive_text()
            history.append({"role": "user", "content": text})
            if not client:
                await ws.send_text(json.dumps({"type": "text", "text": "ANTHROPIC_API_KEY not set."}))
                await ws.send_text(json.dumps({"type": "done"}))
                continue
            loop = asyncio.get_event_loop()
            status_summary = await loop.run_in_executor(None, lambda: json.dumps(_plane_status(), indent=2))
            system = (
                "You are a documentation platform agent running inside the plane-aio Docker container. "
                "Help diagnose Plane service issues (nginx, gunicorn, celery, Next.js). "
                f"Current process status:\n{status_summary}"
            )
            with client.messages.stream(
                model="claude-haiku-4-5-20251001",
                max_tokens=2048,
                system=system,
                messages=history,
            ) as stream:
                full = ""
                for chunk in stream.text_stream:
                    full += chunk
                    await ws.send_text(json.dumps({"type": "text", "text": chunk}))
            history.append({"role": "assistant", "content": full})
            await ws.send_text(json.dumps({"type": "done"}))
    except WebSocketDisconnect:
        pass
