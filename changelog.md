# Changelog

บันทึกการเปลี่ยนแปลงทั้งหมดของ rxwidget
รูปแบบอิง [Keep a Changelog](https://keepachangelog.com/th/1.1.0/) วันที่เป็น YYYY-MM-DD

## [Unreleased]

### เพิ่ม
- 2026-11-17: บันทึกผล spike iOS: Personal Team ลงทะเบียน App Group `group.*` และติดตั้งแอป + widget บน iPhone ได้ (ข้อมูลยังเป็นข้อมูลทดสอบ)
- 2026-11-17: Spike iOS ทดสอบแอป + widget บน iPhone กับ Personal Team
  - target `RxWidgetiOS` / `RxWidgetiOSExtension` (iOS 26.0 ขึ้นไป, iPhone อย่างเดียว) ใน `project.yml`
  - App Group ฝั่ง iOS `group.com.rx8s.rxwidget` (`APP_GROUP_ID_IOS` ใน `Config/Signing.xcconfig`) เพราะ iOS บังคับให้ขึ้นต้นด้วย `group.`
  - `iOS/App/RxWidgetiOSApp.swift` แอปทดสอบเขียน snapshot ลง App Group แล้ว reload widget
  - widget iOS ใช้โค้ดร่วมกับ Mac (`Widget/RxWidgetBundle.swift`, `Shared/`)
  - `docs/spike-ios.md` ขั้นตอนทดสอบและตารางบันทึกผล
- 2026-11-17: `readme.md` ภาพรวม, provider, สถาปัตยกรรม, ความปลอดภัยของ credential, วิธี build, โครงสร้างโปรเจกต์, แก้ปัญหา
- 2026-11-17: Data layer รอบแรก (Claude subscription + Codex)
  - `Shared/UsageModels.swift` model กลาง: `UsageSnapshot` → `ProviderSnapshot` → `UsageWindow` แยกช่วงเวลาตามความยาว window, สถานะ `ok / stale / needsLogin / error / notConfigured`
  - `App/Providers/ClaudeSubscriptionProvider.swift` อ่าน token จาก Keychain `Claude Code-credentials` ผ่าน `/usr/bin/security` (ไม่ refresh เอง), เรียก `/api/oauth/usage` ใช้ `limits[]` เป็นหลัก fallback `five_hour`/`seven_day`, token ว่าง → `needsLogin`, หมดอายุ/401/403 → `stale`
  - `App/Providers/CodexProvider.swift` เรียก `wham/usage` ถ้าไม่ได้ → อ่าน event `token_count` ล่าสุดจาก rollout (20 ไฟล์ใหม่สุด) พร้อมหมายเหตุสาเหตุ
  - `App/Providers/Support.swift` ตัวรัน process, HTTP (timeout 20 วิ, ephemeral), parser วันที่ ISO 8601 (เศษวินาทีกี่หลักก็ได้) และ epoch วินาที/มิลลิวินาที
  - `App/UsageCoordinator.swift` ดึงข้อมูลทุก 5 นาที (กด refresh เองได้), ถ้ารอบนี้ไม่ได้ข้อมูลให้คงค่าเดิมพร้อมสถานะข้อมูลเก่า, เขียน `usage-snapshot.json` ลง App Group แล้ว reload widget
  - `Shared/UsageViews.swift` view ชั่วคราวใช้ร่วมกันระหว่าง menu และ widget (ออกแบบจริงภายหลัง)

### เปลี่ยนแปลง
- 2026-11-17: `SnapshotStore` เก็บ `UsageSnapshot` ในไฟล์ `usage-snapshot.json` แทนข้อมูล spike
- 2026-11-17: menu bar แสดงโควตาจริงแทนหน้าทดสอบ spike, widget เปลี่ยน kind เป็น `UsageWidget` (ต้องลบ widget spike เดิมแล้วเพิ่มใหม่)

### ลบออก
- 2026-11-17: `Shared/SpikeSnapshot.swift` (แทนด้วย model จริง)

### แก้ไข
- 2026-11-17: `probe_providers.py` เปลี่ยนจาก urllib เป็น `/usr/bin/curl` แก้ `CERTIFICATE_VERIFY_FAILED` บน Python ของ python.org

### เพิ่ม
- 2026-11-17: Spike ทดสอบ App Group + WidgetKit กับ Apple Personal Team
  - `project.yml` สำหรับ XcodeGen: target `RxWidget` (menu bar, ไม่ sandbox) และ `RxWidgetExtension` (widget, sandbox) รองรับ macOS 26 ขึ้นไป
  - `Config/Signing.xcconfig` ตั้ง `DEVELOPMENT_TEAM` (ยังว่าง) และ App Group `<TEAMID>.rxwidget`
  - `Shared/SpikeSnapshot.swift` อ่าน/เขียน snapshot JSON ใน App Group container
  - host app มีปุ่มเขียน snapshot แล้วสั่ง `WidgetCenter` reload, widget แสดงค่าที่อ่านได้หรือข้อความผิดพลาด
  - `docs/spike-app-group.md` ขั้นตอนทดสอบและจุดที่ต้องบันทึกผล
- `.gitignore` สำหรับ Xcode/macOS (ไม่ commit `.xcodeproj` เพราะสร้างจาก `project.yml`)
- `changelog.md` ไฟล์นี้
- 2026-11-17: `docs/research-providers.md` ผล research ตำแหน่ง token ของ Claude Code (Keychain `Claude Code-credentials`) และยืนยันว่า OpenAI ไม่มี endpoint ยอดคงเหลือ → ใช้ Costs API
- 2026-11-17: บันทึกโครงสร้าง credential จริงของ Claude Code และ Codex ใน `docs/research-providers.md`
- 2026-11-17: บันทึกผล probe หลัง login Claude Code: token อยู่ใน `Claude Code-credentials`, `/api/oauth/usage` ใช้ได้ พร้อมตัวอย่าง response และข้อสังเกตการ decode
- 2026-11-17: บันทึกผล `claude doctor`/`/status`: CLI ยังไม่ได้ login (Expired) จึงยังสรุปไม่ได้ว่าเป็นบั๊ก Keychain
- 2026-11-17: บันทึกผล probe รอบสาม: login Claude Code ใหม่แล้วแต่ Keychain ไม่ถูกเขียน พร้อมอ้างอิงบั๊กที่เกี่ยวข้อง
- 2026-11-17: บันทึกผล probe รอบสอง: `wham/usage` ใช้ได้ (ตัวอย่าง response ตัด id/email), token Claude Code ว่างทั้ง 28 Keychain item
- 2026-11-17: บันทึกผล probe รอบแรก: token Claude Code ใน Keychain ว่าง, ตัวอย่าง `rate_limits` จริงจาก Codex rollout
- 2026-11-17: `probe_providers.py` ไล่ตรวจทุก Keychain item `Claude Code-credentials*` และทดสอบ usage ด้วย token ที่ยังใช้ได้
- 2026-11-17: `scripts/probe_providers.py` สคริปต์ตรวจ token/endpoint/rollout แบบอ่านอย่างเดียว ไม่พิมพ์ secret

### เปลี่ยนแปลง
- 2026-11-17: ตั้ง `DEVELOPMENT_TEAM = <TEAMID>` (Personal Team) ใน `Config/Signing.xcconfig` → App Group เป็น `<TEAMID>.rxwidget`
- 2026-11-17: บันทึกผล spike ใน `docs/spike-app-group.md` — sign ผ่าน, host เขียนและ widget อ่าน App Group ได้, reload ทำงาน (เหลือเช็ก prompt สิทธิ์และอายุ profile 7 วัน)
