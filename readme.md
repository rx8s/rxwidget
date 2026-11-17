# RxWidget

แอป menu bar และ widget บน desktop ของ macOS สำหรับดูโควตาการใช้งาน Claude และ Codex ในที่เดียว

> สถานะ: **กำลังพัฒนา** — ยังไม่มี release

## Provider ที่รองรับ

| Provider | แหล่งข้อมูล | สิ่งที่แสดง | สถานะ |
|---|---|---|---|
| Claude (subscription) | `GET api.anthropic.com/api/oauth/usage` ด้วย token ของ Claude Code | % ช่วง 5 ชั่วโมง, 7 วัน, 7 วันรายรุ่น | ✅ data layer |
| Codex (ChatGPT plan) | `GET chatgpt.com/backend-api/wham/usage` → fallback log `~/.codex/sessions` | % ช่วง 5 ชั่วโมง, 7 วัน | ✅ data layer |
| Claude API | Admin API `/v1/organizations/cost_report` | ยอดใช้จ่ายเดือนนี้ | ⏳ ยังไม่เริ่ม |
| OpenAI API | Costs API `/v1/organization/costs` | ยอดใช้จ่ายเดือนนี้ (ไม่มี API ยอดคงเหลือ) | ⏳ ยังไม่เริ่ม |

endpoint ของ Claude subscription และ Codex **ไม่ได้ประกาศเป็นทางการ** อาจเปลี่ยนหรือใช้ไม่ได้เมื่อไรก็ได้
แอปจึงแปลงทุกความผิดพลาดเป็นสถานะบนหน้าจอ และคงค่าล่าสุดไว้พร้อมป้าย "ข้อมูลเก่า"

## สถาปัตยกรรม

```
┌──────────────────────────────┐        App Group container         ┌────────────────────────┐
│ RxWidget (menu bar, ไม่ sandbox) │  ──►  <TEAMID>.rxwidget/            ──►  │ RxWidgetExtension      │
│ • อ่าน Keychain / ~/.codex      │       usage-snapshot.json               │ (widget, sandbox)      │
│ • เรียก API ทุก 5 นาที           │                                         │ • อ่านอย่างเดียว          │
│ • เขียน snapshot + reload widget│                                         └────────────────────────┘
└──────────────────────────────┘
```

- **host app** ดึงข้อมูลทั้งหมด แล้วเขียน `UsageSnapshot` เป็น JSON ลง App Group
- **widget** อ่าน snapshot ไปแสดงอย่างเดียว ไม่เรียกเครือข่ายและไม่แตะ credential
- ช่วงเวลาของโควตาแยกตาม**ความยาว window** (5 ชั่วโมง / 7 วัน) ไม่ยึดชื่อ slot ของ provider

## ความปลอดภัยของ credential

- **อ่านอย่างเดียว** ไม่ refresh token ของ Claude Code หรือ Codex เอง
  ถ้า token หมดอายุ แอปจะแสดง "ข้อมูลเก่า" จนกว่าจะเปิด Claude Code / Codex ให้ต่ออายุเอง
- token ของ Claude Code อ่านจาก Keychain item `Claude Code-credentials` ผ่าน `/usr/bin/security`
- token ของ Codex อ่านจาก `~/.codex/auth.json`
- Admin key ของ Claude API / OpenAI API (เมื่อทำเสร็จ) จะเก็บใน Keychain ของ RxWidget เอง
- token ไม่ถูกเขียนลง App Group หรือ log

## ความต้องการของระบบ

- macOS 26 Tahoe ขึ้นไป
- Xcode 26 ขึ้นไป
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- Apple ID ที่ login ใน Xcode (Personal Team ฟรีก็พอ)
- ใช้กับ Claude: login Claude Code ด้วยบัญชี claude.ai (`claude auth login`)
- ใช้กับ Codex: login Codex CLI ด้วยบัญชี ChatGPT

## Build และรัน

1. ใส่ Team ID ใน `Config/Signing.xcconfig`

   ```
   DEVELOPMENT_TEAM = XXXXXXXXXX
   ```

   หา Team ID ได้จากใบรับรอง Apple Development (ดูค่า `OU=`):

   ```bash
   security find-certificate -c "Apple Development" -p | openssl x509 -noout -subject
   ```

2. สร้าง Xcode project แล้วเปิด

   ```bash
   xcodegen
   open RxWidget.xcodeproj
   ```

   ไม่ต้อง commit `RxWidget.xcodeproj` — สร้างใหม่จาก `project.yml` ได้ทุกเมื่อ
   แก้ setting ใน `project.yml` / `Config/*.xcconfig` แทนการแก้ใน Xcode (ค่าที่แก้ใน Xcode จะหายเมื่อรัน `xcodegen`)

3. เลือก scheme `RxWidget` แล้ว Run (⌘R) — ไอคอนเกจจะขึ้นบน menu bar
4. เพิ่ม widget: คลิกขวาที่ desktop → Edit Widgets → ค้นหา "RxWidget"

## โครงสร้างโปรเจกต์

```
project.yml                 XcodeGen spec (2 target)
Config/Signing.xcconfig     Team ID, bundle prefix, App Group
App/                        host app (menu bar)
  RxWidgetApp.swift         MenuBarExtra + หน้า panel
  UsageCoordinator.swift    รอบดึงข้อมูล, merge ข้อมูลเก่า, เขียน snapshot
  Providers/                provider แต่ละเจ้า + HTTP/process/date helpers
Widget/                     widget extension
Shared/                     ใช้ร่วมกันทั้ง 2 target
  UsageModels.swift         UsageSnapshot / ProviderSnapshot / UsageWindow
  SnapshotStore.swift       อ่าน/เขียน JSON ใน App Group
  UsageViews.swift          view ที่ใช้ร่วมกัน
scripts/probe_providers.py  ตรวจ credential และ endpoint บนเครื่องจริง (ไม่พิมพ์ secret)
docs/                       ผล spike และ research
```

## แก้ปัญหา

| อาการ | สาเหตุที่เป็นไปได้ / วิธีแก้ |
|---|---|
| Claude: "ยังไม่ได้ login (token ว่าง)" | Claude Code ไม่ได้ login — รัน `claude auth login` แล้วเช็ก `/status` ใน `claude` |
| Claude: "ข้อมูลเก่า · token หมดอายุ" | token ของ Claude Code อายุ ~8 ชั่วโมง เปิด `claude` สักครั้งเพื่อให้ต่ออายุ |
| Codex: หมายเหตุ "ใช้ข้อมูลจาก log" | `wham/usage` ใช้ไม่ได้ ตัวเลขมาจาก session ล่าสุดของ Codex อาจไม่เป็นปัจจุบัน |
| widget: "เปิด App Group container ไม่ได้" | `DEVELOPMENT_TEAM` ไม่ตรงกับใบรับรอง หรือยังไม่ได้รัน `xcodegen` ใหม่หลังแก้ |
| widget: "ยังไม่มีข้อมูล" | เปิดแอป RxWidget บน menu bar อย่างน้อยหนึ่งครั้ง |

ตรวจ credential และ endpoint จาก Terminal ได้ด้วย:

```bash
python3 scripts/probe_providers.py
```

## เอกสารเพิ่มเติม

- [`docs/spike-app-group.md`](docs/spike-app-group.md) — ผลทดสอบ App Group + widget กับ Personal Team
- [`docs/research-providers.md`](docs/research-providers.md) — รูปแบบ credential และ response จริงของแต่ละ provider
- [`changelog.md`](changelog.md) — บันทึกการเปลี่ยนแปลง

## แนวทางพัฒนา

- บันทึกทุกการเปลี่ยนแปลงใน `changelog.md` (Keep a Changelog ภาษาไทย, วันที่ YYYY-MM-DD)
- ทำงานบน branch `master`
