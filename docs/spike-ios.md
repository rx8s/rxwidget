# Spike: แอป + widget บน iPhone กับ Personal Team

> **สถานะ: พักไว้ (2026-11-17)** — ลบ target iOS ออกจากโปรเจกต์แล้วเพื่อโฟกัสฝั่ง macOS
> เอกสารนี้เก็บไว้เป็นบันทึกผล ดูโค้ดเดิมได้ที่ commit `43cf98f`

เป้าหมาย: ยืนยันว่า Personal Team ฟรีทำสิ่งเหล่านี้บน iPhone (iOS 27) ได้

1. sign แอป iOS + widget extension ที่มี App Group `group.com.rx8s.rxwidget`
2. แอปเขียน snapshot ลง App Group แล้ว widget อ่านได้

ยังไม่ทดสอบการส่งข้อมูลจริงจาก Mac (เป็น spike ถัดไป)

## Target ที่เพิ่ม

| Target | Bundle ID | App Group |
|---|---|---|
| `RxWidgetiOS` | `com.rx8s.rxwidget.ios` | `group.com.rx8s.rxwidget` |
| `RxWidgetiOSExtension` | `com.rx8s.rxwidget.ios.widget` | `group.com.rx8s.rxwidget` |

target ฝั่ง Mac ไม่เปลี่ยน ยังใช้ `<TEAMID>.rxwidget`
widget iOS ใช้โค้ดเดียวกับ Mac (`Widget/RxWidgetBundle.swift` + `Shared/`)

## ขั้นตอน

1. เตรียม iPhone: ต่อสาย → Trust This Computer → เปิด Developer Mode (Settings → Privacy & Security) → รีสตาร์ต
2. `xcodegen` แล้วเปิด `RxWidget.xcodeproj`
3. เลือก scheme **RxWidgetiOS** และปลายทางเป็น iPhone → ⌘R
   - ถ้า Xcode ไม่สร้าง scheme ให้: Product → Scheme → Manage Schemes… → Autocreate Schemes Now
4. ถ้าขึ้น "Untrusted Developer": Settings → General → VPN & Device Management → Apple Development: … → Trust แล้ว ⌘R อีกครั้ง
5. ในแอป: Group ID ต้องเป็น `group.com.rx8s.rxwidget` และมี path ของ container
6. กด "เขียน snapshot ทดสอบ" → ต้องขึ้น "เขียนและอ่านกลับสำเร็จ"
7. กดค้างหน้า Home → Edit → Add Widget → "RxWidget" → เพิ่ม
8. กด "เขียน snapshot ทดสอบ" อีกครั้ง → % ของ Claude ใน widget ต้องเปลี่ยนตาม

## บันทึกผล (กรอกหลังทดสอบ)

| ข้อ | ผลที่ต้องการ | ผลจริง |
|---|---|---|
| Xcode ลงทะเบียน App Group `group.*` ด้วย Personal Team ได้ | ไม่มี error ใน Signing & Capabilities | ✅ (2026-11-17) |
| sign + ติดตั้งทั้งแอปและ widget | ติดตั้งได้ | ✅ |
| แอปเปิด container ได้ | path ขึ้น | |
| widget อ่าน snapshot ได้ | แสดง Claude/Codex ทดสอบ | |
| `reloadAllTimelines()` ทำให้ widget อัปเดต | % เปลี่ยน | |
| อายุ profile | หมดใน 7 วัน (ต้อง build ใหม่) | |

หมายเหตุ: ตัวเลขในแอป/widget iOS ตอนนี้เป็นข้อมูลทดสอบ จึงไม่ตรงกับ usage จริงบน Mac — ต้องทำการส่งข้อมูลจาก Mac ก่อน

## ถ้าไม่ผ่าน

- จดข้อความ error จาก Signing & Capabilities ทั้งสอง target
- ถ้า Personal Team ใช้ App Group บน iOS ไม่ได้ → ทางเลือก: ให้ widget iOS ดึงข้อมูลจาก relay (เช่น Cloudflare Worker) เองโดยตรง ไม่ต้องใช้ App Group
