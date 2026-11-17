# Changelog

บันทึกการเปลี่ยนแปลงทั้งหมดของ rxwidget
รูปแบบอิง [Keep a Changelog](https://keepachangelog.com/th/1.1.0/) วันที่เป็น YYYY-MM-DD

## [Unreleased]

### เพิ่ม
- 2026-11-17: Spike ทดสอบ App Group + WidgetKit กับ Apple Personal Team
  - `project.yml` สำหรับ XcodeGen: target `RxWidget` (menu bar, ไม่ sandbox) และ `RxWidgetExtension` (widget, sandbox) รองรับ macOS 26 ขึ้นไป
  - `Config/Signing.xcconfig` ตั้ง `DEVELOPMENT_TEAM` (ยังว่าง) และ App Group `<TEAMID>.rxwidget`
  - `Shared/SpikeSnapshot.swift` อ่าน/เขียน snapshot JSON ใน App Group container
  - host app มีปุ่มเขียน snapshot แล้วสั่ง `WidgetCenter` reload, widget แสดงค่าที่อ่านได้หรือข้อความผิดพลาด
  - `docs/spike-app-group.md` ขั้นตอนทดสอบและจุดที่ต้องบันทึกผล
- `.gitignore` สำหรับ Xcode/macOS (ไม่ commit `.xcodeproj` เพราะสร้างจาก `project.yml`)
- `changelog.md` ไฟล์นี้
