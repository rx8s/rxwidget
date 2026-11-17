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

สถานะ: **รอยืนยันบนเครื่องจริง**

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
