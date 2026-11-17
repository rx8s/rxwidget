#!/usr/bin/env python3
"""ตรวจโครงสร้างข้อมูลของ provider บนเครื่องจริง (ไม่พิมพ์ token/secret)

ใช้: python3 scripts/probe_providers.py
อ่านอย่างเดียว: ไม่ refresh token และไม่เขียนไฟล์ใดๆ
"""
import glob
import json
import os
import subprocess
from datetime import datetime, timezone

MAX_BODY = 3000


def ts(ms):
    if not isinstance(ms, (int, float)) or ms <= 0:
        return f"{ms!r} (ไม่มีค่า)"
    sec = ms / 1000 if ms > 1e12 else ms
    return f"{ms} → {datetime.fromtimestamp(sec, timezone.utc).isoformat()}"


def get(url, headers):
    """เรียกผ่าน /usr/bin/curl (ใช้ cert ของระบบ) ส่ง header ทาง stdin เพื่อไม่ให้ token โผล่ใน ps"""
    config = "".join(f'header = "{k}: {v}"\n' for k, v in headers.items())
    config += f'url = "{url}"\n'
    try:
        out = subprocess.run(
            ["/usr/bin/curl", "-sS", "--max-time", "20", "-w", "\n%{http_code}", "-K", "-"],
            input=config, capture_output=True, text=True)
    except Exception as e:  # noqa: BLE001
        return None, f"{type(e).__name__}: {e}"
    if out.returncode != 0:
        return None, out.stderr.strip()
    body, _, code = out.stdout.rpartition("\n")
    return int(code), body


def show(status, body):
    print("  HTTP:", status)
    print("  body:", body[:MAX_BODY])


def claude():
    print("== Claude subscription ==")
    print("  CLAUDE_CODE_OAUTH_TOKEN ตั้งไว้:", bool(os.environ.get("CLAUDE_CODE_OAUTH_TOKEN")))
    try:
        raw = subprocess.run(
            ["/usr/bin/security", "find-generic-password", "-s", "Claude Code-credentials", "-w"],
            capture_output=True, text=True, check=True).stdout
    except subprocess.CalledProcessError as e:
        print("  อ่าน Keychain ไม่ได้:", e.stderr.strip())
        return
    o = json.loads(raw).get("claudeAiOauth", {})
    token = o.get("accessToken") or ""
    print("  accessToken ยาว:", len(token), "| prefix:", token[:10] + "…" if token else "(ว่าง)")
    print("  refreshToken ยาว:", len(o.get("refreshToken") or ""))
    print("  expiresAt:", ts(o.get("expiresAt")))
    print("  refreshTokenExpiresAt:", ts(o.get("refreshTokenExpiresAt")))
    print("  scopes:", o.get("scopes"), "| sub:", o.get("subscriptionType"), "| tier:", o.get("rateLimitTier"))
    if not token:
        return
    show(*get("https://api.anthropic.com/api/oauth/usage", {
        "Authorization": f"Bearer {token}",
        "anthropic-beta": "oauth-2025-04-20",
        "User-Agent": "rxwidget-probe/0.1",
    }))


def codex():
    print("\n== Codex (ChatGPT plan) ==")
    path = os.path.expanduser("~/.codex/auth.json")
    d = json.load(open(path))
    t = d.get("tokens") or {}
    print("  auth_mode:", d.get("auth_mode"), "| last_refresh:", d.get("last_refresh"))
    print("  access_token ยาว:", len(t.get("access_token") or ""), "| มี account_id:", bool(t.get("account_id")))
    if t.get("access_token"):
        show(*get("https://chatgpt.com/backend-api/wham/usage", {
            "Authorization": f"Bearer {t['access_token']}",
            "ChatGPT-Account-Id": t.get("account_id", ""),
            "User-Agent": "rxwidget-probe/0.1",
        }))

    print("\n== Codex rollout fallback ==")
    files = sorted(glob.glob(os.path.expanduser("~/.codex/sessions/**/rollout-*.jsonl"), recursive=True),
                   key=os.path.getmtime)
    print("  ไฟล์:", len(files))
    for f in reversed(files):
        last = None
        with open(f, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                if '"token_count"' in line and '"rate_limits"' in line:
                    last = line
        if last:
            ev = json.loads(last)
            payload = ev.get("payload", ev)
            print("  ไฟล์ล่าสุดที่มี:", os.path.basename(f))
            print("  timestamp:", ev.get("timestamp"))
            print("  rate_limits:", json.dumps(payload.get("rate_limits"), ensure_ascii=False, indent=2))
            return
    print("  ไม่พบ event token_count ที่มี rate_limits")


if __name__ == "__main__":
    claude()
    codex()
