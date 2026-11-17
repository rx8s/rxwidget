# Research: แหล่งข้อมูลของแต่ละ provider

อัปเดต 2026-11-17

## 1. Token ของ Claude Code บน macOS

ข้อมูลจากโค้ดของเครื่องมือภายนอกและรายงานบั๊ก ไม่ใช่เอกสารทางการของ Anthropic

- Keychain: generic password, service = `Claude Code-credentials`
- ค่าเป็น JSON ประมาณนี้:
  ```json
  { "claudeAiOauth": { "accessToken": "…", "refreshToken": "…", "expiresAt": 0,
                       "scopes": [], "subscriptionType": "…", "rateLimitTier": "…" } }
  ```
- `expiresAt`: แหล่งส่วนใหญ่บอกเป็น epoch มิลลิวินาที แต่บางแหล่งบอกเป็น string วันที่ → ต้องรองรับทั้งสองแบบ
- บั๊กที่มีรายงาน:
  - token ใน Keychain ถูกล้างเป็นค่าว่าง
  - Keychain กับ `~/.claude/.credentials.json` มีค่าไม่ตรงกัน
  - ถ้าตั้ง `CLAUDE_CODE_OAUTH_TOKEN` ไว้ Claude Code จะข้าม Keychain
  - → ต้องจัดการกรณี token ว่าง/หมดอายุ/ไม่มีรายการ ให้เป็นสถานะ "ข้อมูลเก่า" ไม่ใช่ crash

**ประเด็นออกแบบ:** item นี้สร้างโดย Claude Code ถ้า rxwidget อ่านผ่าน Security framework เอง
macOS จะถามสิทธิ์ ("RxWidget wants to use … Claude Code-credentials")
และอาจถามซ้ำทุกครั้งที่ rebuild แล้ว signature เปลี่ยน
ทางเลือก: เรียก `/usr/bin/security find-generic-password -s … -w` ซึ่งมักอยู่ใน ACL อยู่แล้ว → ต้องทดสอบจริง

ผลบนเครื่องจริง (2026-11-17):
- มี item `Claude Code-credentials` จริง, top-level keys: `mcpOAuth`, `claudeAiOauth`
- fields: `accessToken` str, `refreshToken` str, `expiresAt` int, `refreshTokenExpiresAt` int, `scopes` list, `subscriptionType` str (`team`), `rateLimitTier` str
- ไม่มี `~/.claude/.credentials.json`
- ⚠️ ผล `probe_providers.py`: `accessToken` และ `refreshToken` **ว่าง**, `expiresAt = 0`,
  `refreshTokenExpiresAt` = 2026-09-02 (หมดอายุแล้ว) → ตรงกับบั๊ก token ถูกล้าง
- `subscriptionType = team`, `rateLimitTier = default_raven`, scopes มี `user:profile`, `user:inference`, `user:sessions:claude_code`
- ยังไม่รู้ว่า Claude Code ตอนนี้ login อยู่หรือไม่ และถ้า login อยู่ token อยู่ที่ไหน → ต้องตรวจต่อ
- สิ่งที่แอปต้องรองรับ: item มีอยู่แต่ token ว่าง → สถานะ "ต้อง login Claude Code ใหม่" (แยกจาก "ข้อมูลเก่า")

## 3. Codex (เครื่องจริง)

- `~/.codex/auth.json`: `auth_mode` = `chatgpt`, `OPENAI_API_KEY` null,
  `tokens` {`id_token`, `access_token`, `refresh_token`, `account_id`}, `last_refresh` ISO string
- `wham/usage`: ยังไม่ได้ผล — Python ของ python.org ไม่มี CA cert ของระบบ (`CERTIFICATE_VERIFY_FAILED`)
  ไม่ใช่ปัญหาของ endpoint; สคริปต์เปลี่ยนไปใช้ `/usr/bin/curl` แล้ว
- rollout fallback ใช้ได้: event `token_count` → `payload.rate_limits` ตัวอย่างจริง
  ```json
  { "limit_id": "codex", "limit_name": null,
    "primary":   { "used_percent": 61.0, "window_minutes": 300,   "resets_at": 1794906035 },
    "secondary": { "used_percent": 10.0, "window_minutes": 10080, "resets_at": 1795078743 },
    "credits": { "has_credits": false, "unlimited": false, "balance": "0" },
    "individual_limit": null, "spend_control_reached": null,
    "plan_type": "plus", "rate_limit_reached_type": null }
  ```
  - `window_minutes` 300 = 5 ชั่วโมง, 10080 = 7 วัน → จัดกลุ่มตามค่านี้ (ไม่ยึด primary/secondary)
  - `resets_at` เป็น epoch วินาที, `used_percent` เป็น double, `credits.balance` เป็น string
  - field อื่นอาจเป็น null → decode แบบ optional ทั้งหมด

## 2. ยอดคงเหลือของ OpenAI API

- **ไม่มี endpoint ยอดคงเหลืออย่างเป็นทางการ** OpenAI Support ตอบใน community เมื่อ 2026-09-07 ว่าให้ใช้ Costs API
  และส่งคำขอ endpoint ยอดคงเหลือต่อให้ทีมแล้ว แต่ยังไม่มีกำหนดเวลา
- ที่ใช้ได้: `GET https://api.openai.com/v1/organization/costs` ด้วย Admin key
  (key แบบ project/service account ใช้ไม่ได้)
- `GET /v1/dashboard/billing/credit_grants` เป็น endpoint เก่าที่ไม่อยู่ใน API reference ปัจจุบัน → ไม่ใช้
- → แสดง "ยอดใช้จ่ายเดือนนี้" เหมือน Claude API

## แหล่งอ้างอิง

- https://docs.rs/ai-usagebar/0.7.1/src/ai_usagebar/anthropic/creds.rs.html
- https://docs.rs/scud-cli/1.67.0/src/scud/llm/oauth.rs.html
- https://claudeissues.com/issue/84331-bug-macos-cli-login-loop-keychain-credentials-blob-has-every-accesstoken-refresh
- https://claudeissues.com/issue/91180-bug-keychain-and-claude-credentials-json-diverge-orphaned-plaintext-credential-c
- https://claudeissues.com/issue/37512-claude-code-oauth-token-silently-deletes-macos-keychain-credentials-on-exit
- https://community.openai.com/t/access-billing-balance-costs-via-admin-api/1383654
- https://raw.githubusercontent.com/steipete/CodexBar/main/docs/openai.md
