# Phase 5 — Protocol Reference

เอกสารนี้กำหนด wire format, กฎ relay, คิวถาวร, ACK, SOS/Rescue และสื่อผ่าน relay
ใช้เป็น contract ร่วมระหว่างส่วนต่าง ๆ ของ Phase 5

สถานะปัจจุบัน: Implement ข้อความ คิวถาวร ACK รายชื่อผ่านเครือข่าย และ SOS/Rescue ผ่าน Relay แล้ว
สื่อผ่าน Relay จำกัด 5 MiB ในรุ่นแรก; การทดสอบบนมือถือจริงยังต้องยืนยัน
รายละเอียดและขั้นตอนทดสอบมือถือดู PHASE_5_DIRECTORY_SOS_VERIFICATION.md
ผล automated tests ไม่ใช่หลักฐานมือถือจริง

---

## 1. ตัวตนและ Endpoint

- **ตัวตนถาวร**: `deviceId` จากตาราง `settings` ใน SQLite — ไม่เปลี่ยนแม้ Nearby endpoint จะหมุนเวียน
- **Nearby endpoint**: ชั่วคราว — ใช้แนะนำตัว (`deviceInfo`) เพื่อ map ไปยัง `deviceId`
- ตัวตนตัวอักษรต้องไม่ว่าง ไม่เกิน 128 ตัว และต้องไม่ซ้ำใน `relayPath`

---

## 2. Packet Types และ Versioning

### 2.1 Packet ที่มีอยู่แล้ว (Phase 1–4)

| type | ใช้ใน relay? | คำอธิบาย |
|------|------------|---------|
| `message` | yes Phase 5 Part 1 | ข้อความแชตปกติ |
| `ack` | yes Phase 5 Part 2 | ยืนยันรับข้อความ |
| `sos` | yes Phase 5 Part 3 | SOS / ยกเลิก SOS |
| `presence` | directory ใน heartbeat | สถานะ online, rescue, SOS ปัจจุบัน |
| `deviceInfo` | no (direct only) | แนะนำตัว — ห้ามผ่าน relay |
| `media` | no (ใช้ mediaInit/FILE) | chat row สำหรับสื่อ |

### 2.2 Packet ใหม่ Phase 5

| packetType | ใน relay? | คำอธิบาย |
|-----------|---------|---------|
| `mediaInit` | yes Phase 5 Part 4 | metadata ของสื่อก่อน FILE payload |
| `mediaAck` | yes Phase 5 Part 4 | ยืนยันสื่อจากผู้รับ |
| directory | อยู่ใน presence.text | ตารางรายชื่อ peer ที่รู้จักผ่าน B; ไม่ใช่ packetType แยก |

---

## 3. RelayPacket (ช่วงที่ 1 — มีอยู่แล้ว)

```json
{
  "id": "<message-uuid>",
  "senderId": "<origin-deviceId>",
  "senderName": "...",
  "receiverId": "<destination-deviceId>",
  "text": "...",
  "timestamp": "2026-...",
  "type": "message",
  "status": "pending",
  "relayVersion": 1,
  "relayPath": ["<origin>", "<hop1>", "..."]
}
```

### กฎ relay_seen (deduplication)
- บันทึก `message.id` ใน SQLite `relay_seen` แบบ atomic ก่อนส่งต่อ
- ใช้ `enqueueRelay()` บันทึก seen และงานคิวใน transaction เดียว ไม่เรียก claimRelay ก่อน enqueue
- ID เดิมไม่สร้างงานเพิ่มและต้องมีเนื้อหาเดิม; ถ้ามี receipt แล้ว ให้ส่ง ACK ที่เก็บไว้ซ้ำเมื่อจำเป็น
- seen จากรุ่นเก่าที่ไม่มีงานคิวสามารถกู้ด้วย packet เดิมที่ส่งมาใหม่ได้
- `relay_seen` ไม่ล้างอัตโนมัติ (ช่วงที่ 2 กำหนด retention ร่วมกับ queue TTL)

### hop limit
- `maxHops = 8` — ถ้า path ยาวถึง 8 แล้วรับได้แต่ส่งต่อไม่ได้
- ปลายทางรับข้อความที่ path ยาวถึง maxHops ได้

---

## 4. Relay Queue — ช่วงที่ 2 (Durable)

ตาราง `relay_queue` ใน SQLite (DB version 8):

```sql
CREATE TABLE relay_queue (
  seq          INTEGER PRIMARY KEY AUTOINCREMENT,
  packet_id    TEXT NOT NULL,
  payload      TEXT NOT NULL,
  dest_peer    TEXT NOT NULL,
  attempts     INTEGER NOT NULL DEFAULT 0,
  next_attempt TEXT,
  created_at   TEXT NOT NULL,
  ack_payload  TEXT
);
CREATE UNIQUE INDEX relay_queue_packet ON relay_queue(packet_id, dest_peer);
```

### กฎคิว
- B บันทึกลง `relay_queue` ก่อนส่งต่อ (ภายใน transaction เดียวกับ `relay_seen`)
- `dest_peer` ของงานใหม่เป็นปลายทางสุดท้าย เก็บงานได้แม้ไม่รู้ next hop; งานรุ่น 7 คง key เดิมและอ่านปลายทางจาก payload
- หลัง native send สำเร็จยังเก็บคิว จนได้รับ ACK จากปลายทางที่ตรงกับงาน
- เมื่อ ACK ถึง B เก็บ receipt ใน `ack_payload` และคิว ACK ใน transaction เดียว หยุดส่งข้อความนั้นต่อ แต่เก็บ receipt ไว้ส่งซ้ำหาก ACK หาย
- หลัง restart retry งานค้างทันทีที่เชื่อมต่อ peer ได้
- Backoff: `2^attempts * 5s` จำกัดช่วงรอสูงสุด 300 วินาที ไม่หยุดงานเงียบ ๆ หลังห้าครั้ง
- retry ตามรอบ 5 วินาทีเมื่อถึงกำหนด; reconnect/reset service ทำให้งานพร้อมลองใหม่ทันที
- ต้นทางส่งข้อความ ID เดิมซ้ำจนรับ ACK เพื่อกู้กรณี native send สำเร็จแต่ packet/ACK หาย
- TTL: 48 ชั่วโมง นับจาก `created_at` — cleanup รันตอนเปิดแอปและทุก 6 ชั่วโมง

### ความสัมพันธ์ relay_seen กับ relay_queue
- `relay_seen` บันทึก `packet_id` เพื่อกัน flood ซ้ำ
- `relay_queue` บันทึกงานที่รอส่งต่อ
- ทั้งสองบันทึกใน transaction เดียว ป้องกัน race condition
- การที่ relay_seen มีแล้วไม่หมายความว่า relay_queue ว่าง

---

## 5. End-to-End ACK

### 5.1 Direct link (เดิม)
- ปลายทางส่ง `type: ack, ackFor: <messageId>` กลับโดยตรง
- ต้นทางเปลี่ยนสถานะเป็น `delivered`

### 5.2 Relay ACK — ช่วงที่ 2 (ใหม่)
ห่อ `type: ack` โดยแยกเส้นทางย้อนกลับทั้งหมดออกจาก hop ที่ผ่านแล้ว:

```json
{
  "id": "<new-uuid>",
  "senderId": "<destination-deviceId>",
  "receiverId": "<origin-deviceId>",
  "type": "ack",
  "ackFor": "<original-message-id>",
  "relayVersion": 1,
  "relayPath": ["<destination>"],
  "relayAckRoute": ["<destination>", "<hop-n>", "...", "<origin>"]
}
```

- ใช้เส้นทางที่รับข้อความจริงในรอบนั้นย้อนลำดับ; `relayPath` เป็น prefix ของ `relayAckRoute`
- เครื่องรับต้องเป็น hop ถัดไปและรู้จัก endpoint ของ hop ก่อนหน้า; B ตรวจว่าเส้นทางกลับตรงกับงานที่เคยเก็บ
- ACK route มีได้สูงสุด 9 ผู้ใช้ เพื่อรองรับข้อความที่ส่งครบ 8 ลิงก์
- ถ้าเส้นทางยังไม่ขาด ส่ง ACK ผ่าน relay ทันที
- บันทึก ACK ลง `relay_ack_queue` ก่อนลองส่งเสมอ ลบเมื่อ native send สำเร็จ; ถ้า ACK หายให้กู้จาก receipt หรือข้อมูลเดิมที่ส่งซ้ำ

ตาราง `relay_ack_queue`:
```sql
CREATE TABLE relay_ack_queue (
  seq         INTEGER PRIMARY KEY AUTOINCREMENT,
  ack_for     TEXT NOT NULL,
  payload     TEXT NOT NULL,
  dest_peer   TEXT NOT NULL,
  attempts    INTEGER NOT NULL DEFAULT 0,
  next_attempt TEXT,
  created_at  TEXT NOT NULL
);
CREATE UNIQUE INDEX relay_ack_packet ON relay_ack_queue(ack_for);
```

### กฎ ACK
- ต้นทาง (A) ขึ้น `delivered` เมื่อ ACK มาจาก `receiverId` ที่ตรงกับข้อความเดิมเท่านั้น
- เครื่องกลาง (B) ส่ง ACK ตามเส้นทางกลับเท่านั้น ไม่ flood และไม่บันทึกเป็นแชต
- A รับ ACK ซ้ำได้โดยไม่สร้างแชต/แจ้งเตือนเพิ่ม และไม่ส่ง ACK ตอบ ACK
- ปลายทาง (C) ส่ง ACK ซ้ำได้เมื่อรับข้อความเดิม (idempotent)
- B ไม่ขึ้น delivered แม้ส่ง packet ให้ C สำเร็จแล้ว

---

## 6. Remote Peer Directory — ช่วงที่ 3

### Directory ใน presence heartbeat

JSON ใน presence.text ใช้ PeerPresence เดิม พร้อม directoryVersion: 1 และ directory
แต่ละ entry คือ {peerId, name, sequence, rescue, sos, ageMs, path}
sos เป็น JSON string หรือ null; path เริ่มจากเจ้าของข้อมูลและจบที่ผู้ส่ง heartbeat

### กฎ
- B ส่ง directory ให้ A ทุก presence interval แบ่งไม่เกิน 32 entries และ 24 KiB ต่อ heartbeat
- sequence เพิ่มและบันทึกที่เจ้าของข้อมูลก่อนส่งเท่านั้น
- ageMs สะสมอายุข้อมูลตามนาฬิกาเครื่องที่ถือข้อมูล ไม่รีเซ็ตเมื่อส่งต่อ
- path ต้องไม่ซ้ำ ไม่ผ่านผู้รับ และสมาชิกสุดท้ายต้องตรงกับ peer ผู้ส่งจริง
- sequence เก่าหรือเท่าเดิมไม่ต่ออายุ presence และไม่ย้อนสถานะ Rescue
- directory และ presence บันทึกใน settings จึงกู้ได้หลัง restart

### stale/freshness
- ทั้ง direct และ remote presence ใช้ freshness 30 วินาที; ข้อมูลอายุ 48 ชั่วโมงหยุดประกาศต่อ
- reachable ต้องมีข้อมูลสดและลิงก์ถึง hop ถัดไป; รายชื่อและประวัติยังอยู่เมื่อหลุด
- ผู้หายจากเครือข่าย ไม่ใช่ยกเลิก SOS แต่ presence กลายเป็น stale

---

## 7. SOS ผ่าน Relay — ช่วงที่ 3

### Wire format
- ใช้ `type: sos` บรรจุใน `RelayPacket` เหมือน `type: message`
- เพิ่ม field `relayVersion: 1` และ `relayPath`

### revision และ incident lifecycle
- `incidentId` คงเดิมตลอดอายุเหตุ
- `revision` ต้องเพิ่มขึ้นเสมอ; revision เก่าหรือเท่าเดิมไม่แทนสถานะล่าสุดหรือยืดอายุ SOS แต่ปลายทางตอบ ACK ซ้ำได้
- การยกเลิก (`active: false`) ต้องมี revision สูงกว่า active packet ล่าสุด
- เครื่องกลางใช้ message ID ใน relay_seen/relay_queue เดิม; เก็บ revision ล่าสุดแยกตาม owner และ incident ใน settings (remoteSos) รวมสถานะยกเลิก

### expiration
- active SOS หมดอายุเมื่อครบ 24 ชั่วโมงจาก updatedAt; การส่งต่อไม่เปลี่ยนเวลา และสถานะยกเลิกเก็บไว้กันข้อมูลเก่า
- เครื่องกลาง: ลบงาน SOS ที่หมดอายุหรือมี revision ใหม่กว่าใน ledger ก่อนส่งต่อ
- ปลายทาง: ตรวจอายุเมื่อแสดง UI ไม่ใช่เมื่อรับ
- ผู้ส่งหายจากเครือข่าย ≠ ยกเลิก SOS (ต้องได้รับ packet `active: false` จริง)

### แยก presence stale ออกจาก SOS expired/cancelled

| สถานการณ์ | UI ที่แสดง |
|---------|---------|
| presence stale (>30s ไม่เห็น) | "สถานะล่าสุด" |
| SOS active, presence stale | SOS ยังแสดง active |
| SOS cancelled (active:false) | "ยกเลิก SOS" |
| SOS expired (>24h) | "หมดอายุ" |

---

## 8. สื่อผ่าน Relay — ช่วงที่ 4

### ขีดจำกัดไฟล์ (ปรับได้ผ่าน config)
- รูปภาพ: สูงสุด 2 MiB (`relayImageLimit = 2 * 1024 * 1024`)
- วิดีโอ: สูงสุด 10 MiB (`relayVideoLimit = 10 * 1024 * 1024`)
- แสดงขีดจำกัดก่อน picker เปิด (ถ้าปลายทางต้องส่งผ่าน relay)

### Flow สำหรับ relay (A to B to C)
1. A ส่ง FILE payload และ RelayPacket ชนิด `media` ที่มี metadata ไปยัง B
2. B ตรวจ checksum/ขนาด คัดลอกลง `rescuelink_media/<B>/relay_media` และเก็บ MediaFile สถานะ `relayQueued`
3. B เก็บ RelayPacket ไว้ใน `relay_queue` เดิม คิวจึงอยู่หลัง restart และรอ C เชื่อมต่อ
4. B ส่ง FILE กับ RelayPacket ชุดเดิมไปยัง C โดยสร้าง payload ID ของลิงก์ B–C ใหม่
5. C รับครบ ตรวจ checksum บันทึกสื่อในแชต แล้วส่ง ACK กลับ A ตามเส้นทาง A–B–C
6. A รับ ACK จาก C แล้วเปลี่ยนสถานะสื่อและข้อความเป็น `delivered`

### B ไม่แสดงสื่อ relay เป็นแชตส่วนตัว
- B บันทึกไฟล์ใน `rescuelink_media/<myId>/relay_media` แยกจากสื่อในแชต
- B ไม่บันทึก row ใน `messages` table
- ไฟล์ relay รุ่นแรกจำกัดไม่เกิน 5 MiB; สื่อส่งตรงยังจำกัด 50 MiB

### Queue storage
- ใช้ `relay_queue` และ `relay_seen` เดิม โดย message ID เป็น packet ID
- ไฟล์ที่ตรวจแล้วอ้างจาก `media_files.localPath` และสถานะ `relayQueued`
- ACK ผ่าน `relay_ack_queue` เดิม; คิวต้นทางยังอยู่จน ACK ยืนยันปลายทาง

### TTL และ cleanup
- สื่อ relay: metadata queue หมดอายุ 48 ชั่วโมงตาม cleanup ของ relay queue
- ห้ามลบไฟล์ของงานที่ยังค้างอยู่ในคิว

### retry
- ใช้ `media_id` เดิม ป้องกัน duplicate ที่ปลายทาง
- ปลายทาง (C) รับ `mediaInit` ซ้ำ: ถ้า received/delivered แล้ว ส่ง ACK ซ้ำ ไม่สร้างแชตใหม่

---

## 9. Database Migration

### Version 7 และ 8 (ข้อความและ ACK)
- Version 6 → 7: เพิ่ม `relay_queue` และ `relay_ack_queue`
- Version 7 → 8: เพิ่ม `relay_queue.ack_payload` และ `relay_ack_queue.next_attempt`
- แปลง ACK รุ่น 7 ที่มี path เต็มให้แยก `relayAckRoute` กับ `relayPath`
- คงงานค้าง payload ตัวตน และประวัติเดิม ไม่ล้างหรือสร้างคิวใหม่ทับของเดิม
- Relay media ใช้ schema เดิม ไม่มี migration เพิ่ม

---

## 10. ขอบเขตที่ตั้งใจไม่ทำ ใน Phase 5

- Best-path routing (ใช้ flooding เป็น default)
- Partial file resume ระดับ byte (ส่งใหม่ทั้งก้อน)
- Digital signature ของ relay path
- Multi-hop ของ `deviceInfo` (ห้าม relay)
- Auto-cleanup `relay_seen` ในช่วงนี้

---

*อัปเดตล่าสุด: 2026-10-04*
