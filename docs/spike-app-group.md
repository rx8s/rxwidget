# Spike: App Group + Widget กับ Personal Team

เป้าหมาย: ยืนยันว่า host app (ไม่ sandbox) เขียนไฟล์ลง App Group `<TEAMID>.rxwidget`
แล้ว widget extension (sandbox) อ่านได้ โดย sign ด้วย Apple Personal Team ฟรี

## เตรียม

1. ใส่ Team ID ใน `Config/Signing.xcconfig` → `DEVELOPMENT_TEAM = XXXXXXXXXX`
2. `brew install xcodegen` (ครั้งเดียว)
3. ที่ root โปรเจกต์: `xcodegen` แล้วเปิด `RxWidget.xcodeproj`

## ทดสอบ

1. เลือก scheme `RxWidget` → Run (⌘R)
2. คลิกไอคอนเกจบน menu bar → ดูว่า `Container` แสดง path (ไม่ใช่ error)
3. กด "เขียน snapshot" → ต้องขึ้น "เขียนและอ่านกลับสำเร็จ"
4. คลิกขวาที่ desktop → Edit Widgets → ค้นหา "RxWidget Spike" → เพิ่มลง desktop
5. widget ต้องแสดง `#<counter>` ตรงกับใน menu bar
6. กด "เขียน snapshot" อีกครั้ง → widget ต้องอัปเดตภายในไม่กี่วินาที

## บันทึกผล (กรอกหลังทดสอบ)

| ข้อ | ผลที่ต้องการ | ผลจริง |
|---|---|---|
| Xcode sign ทั้ง 2 target ผ่านด้วย Personal Team | ไม่มี error เรื่อง provisioning / App Groups | |
| host เปิด container ได้ | path ขึ้นใน menu | |
| ไม่มี prompt "would like to access data from other apps" | ไม่มี | |
| widget โผล่ในแกลเลอรี | มี | |
| widget อ่าน snapshot ได้ | แสดง `#n` | |
| `reloadAllTimelines()` ทำให้ widget อัปเดต | อัปเดตเร็ว | |
| ปิด/เปิดเครื่องหรือ 7 วันผ่านไป widget ยังทำงาน | ทำงาน (Personal Team profile หมดอายุ 7 วัน?) | |

## ถ้าไม่ผ่าน ให้จดไว้

- ข้อความ error จาก Xcode (Signing & Capabilities)
- ข้อความใน widget (เช่น "เปิด App Group container ไม่ได้")
- log: `log stream --predicate 'subsystem == "com.apple.chrono"' --level debug`
