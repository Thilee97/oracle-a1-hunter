# Oracle A1 Hunter — Free Tier VM.Standard.A1.Flex Hunter

> **Mục tiêu:** Tự động săn slot Oracle Cloud Always Free **VM.Standard.A1.Flex (2 OCPU / 12 GB RAM)** tại **Singapore (ap-singapore-1)**. Chạy trên GitHub Actions miễn phí, báo cáo qua Telegram heartbeat, tự tắt khi đã có VPS.

---

## 🎯 Tính năng

- ✅ Chạy **mỗi 5 phút** (`*/5 * * * *`) trên GitHub Actions (miễn phí)
- ✅ Tự detect capacity **Out of capacity** → retry lịch sau
- ✅ **Telegram heartbeat** sau mỗi lần check thất bại (biết workflow vẫn sống)
- ✅ **Thông báo chi tiết** khi tạo VPS thành công (IP, SSH, spec, JSON)
- ✅ **Tự disable workflow** sau khi đã có VPS (không lãng phí Actions minutes)
- ✅ **Không secret trong code** — tất cả credentials qua GitHub Secrets
- ✅ **Zero dependency** ngoài OCI CLI + curl + python3 (có sẵn Ubuntu runner)

---

## 🏗️ Kiến trúc

```
┌─────────────────────────────────────────────────────────────────┐
│ GitHub Actions (ubuntu-latest, 5 min timeout)                  │
│  ├─ Checkout repo                                              │
│  ├─ Install OCI CLI (pip)                                      │
│  ├─ Configure OCI CLI từ Secrets                               │
│  ├─ Hunt A1 (scripts/hunt.sh)                                  │
│  │    ├─ Check instance đã tồn tại? → exists=true, stop        │
│  │    ├─ Try launch A1.Flex 2C/12G                             │
│  │    │    ├─ Success → created=true, collect info, notify    │
│  │    │    ├─ Out of capacity → created=false, heartbeat      │
│  │    │    └─ Other error → fail, notify                       │
│  ├─ Collect VPS info (scripts/collect_instance_info.sh)        │
│  ├─ Telegram notifications (heartbeat / success / error)       │
│  └─ Disable workflow nếu success/exists                        │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📁 Cấu trúc repo

```
oracle-a1-hunter/
├── .github/workflows/oracle-a1.yml   # GitHub Actions workflow
├── scripts/
│   ├── hunt.sh                       # Core hunting logic
│   └── collect_instance_info.sh      # Collect VPS details → JSON + summary
├── SETUP.md                          # Hướng dẫn chi tiết (file này)
└── README.md                         # File này
```

---

## 🚀 Quick Start (Tóm tắt)

> **Xem chi tiết tại [SETUP.md](SETUP.md)**

```bash
# 1. Fork repo này
# 2. Tạo OCI API Key + lấy 9 OCID (xem SETUP.md)
# 3. Tạo Telegram Bot + lấy Token + Chat ID
# 4. Vào GitHub repo → Settings → Secrets → Actions → New repository secret
#    Thêm 14 secrets (xem bảng dưới)
# 5. Enable workflow: Actions → Oracle A1 Hunter → Enable workflow
# 6. Chạy test: Actions → Oracle A1 Hunter → Run workflow
# 7. Check Telegram: nhận heartbeat mỗi 5p cho đến khi có VPS
```

---

## 🔐 14 GitHub Secrets bắt buộc

| Secret | Mô tả | Ví dụ / Cách lấy |
|--------|-------|------------------|
| `OCI_PRIVATE_KEY` | Nội dung file `.pem` private key OCI API | `cat ~/.oci/oci_api_key.pem` (copy toàn bộ bao gồm header/footer) |
| `OCI_TENANCY_OCID` | OCID Tenancy | OCI Console → Profile → Tenancy OCID |
| `OCI_USER_OCID` | OCID User | OCI Console → Profile → User OCID |
| `OCI_FINGERPRINT` | Fingerprint API Key | OCI Console → Profile → API Keys → Fingerprint |
| `OCI_REGION` | Region Oracle | `ap-singapore-1` |
| `OCI_COMPARTMENT_OCID` | OCID Compartment | OCI Console → Identity → Compartments → Copy OCID |
| `OCI_SUBNET_OCID` | OCID Subnet (public) | OCI Console → Networking → Subnets → Copy OCID |
| `OCI_IMAGE_OCID` | OCID Image (Ubuntu) | OCI Console → Compute → Images → Canonical Ubuntu → Copy OCID |
| `OCI_SSH_PUBLIC_KEY` | Public key SSH | `cat ~/.ssh/id_rsa.pub` |
| `TELEGRAM_BOT_TOKEN` | Token Bot Telegram | Tạo bot qua @BotFather → copy token |
| `TELEGRAM_CHAT_ID` | Chat ID nhận tin | Gửi tin cho @userinfobot → lấy chat_id |
| `OCI_OCPUS` | Số OCPU | `2` |
| `OCI_MEMORY_GB` | RAM (GB) | `12` |
| `INSTANCE_NAME` | Tên instance | `oracle-a1-2c12g` |

> ⚠️ **Lưu ý:** `OCI_PRIVATE_KEY` phải copy **toàn bộ file .pem** bao gồm `-----BEGIN PRIVATE KEY-----` và `-----END PRIVATE KEY-----`.

---

## ⚙️ Cấu hình có thể tùy chỉnh

Trong file `.github/workflows/oracle-a1.yml`, có thể chỉnh các biến `env`:

```yaml
env:
  INSTANCE_NAME: oracle-a1-2c12g      # Tên VPS
  OCI_SHAPE: VM.Standard.A1.Flex      # Shape (Always Free)
  OCI_OCPUS: "2"                      # OCPU (Always Free max 4)
  OCI_MEMORY_GB: "12"                 # RAM GB (Always Free max 24)
  OCI_REGION: ap-singapore-1          # Region (Singapore)
```

> 💡 Always Free limits: **4 OCPU + 24 GB RAM** tổng cộng. Mặc định 2C/12G để vừa free tier.

---

## 📱 Telegram Notifications

Workflow gửi 3 loại tin nhắn:

| Loại | Khi nào | Nội dung |
|------|---------|----------|
| **Heartbeat** | Mỗi 5p khi chưa có slot | "Workflow vẫn hoạt động. Chưa có slot A1..." |
| **Exists** | VPS đã tồn tại | "VPS oracle-a1-2c12g đã tồn tại. Không tạo thêm. Workflow sẽ tự dừng." |
| **Success** | Tạo VPS thành công | Chi tiết: IP, SSH command, spec, JSON attachment |

---

## 🔍 Troubleshooting

### 1. Workflow fail ngay lập tức
- Check **Secrets** có đủ 14 cái không, tên chính xác (case-sensitive)
- `OCI_PRIVATE_KEY` có copy đúng format `.pem` không?

### 2. "Out of capacity" liên tục
- Bình thường — Oracle A1 free tier rất ít slot. Workflow sẽ retry mỗi 5p.
- Có thể đổi region (cần đổi `OCI_REGION` + `OCI_IMAGE_OCID` + `OCI_SUBNET_OCID` tương ứng).

### 3. "Invalid compartment" / "Not authorized"
- `OCI_COMPARTMENT_OCID` sai hoặc user không có policy `manage instance-family` trong compartment đó.

### 4. "Subnet not found" / "No public IP"
- `OCI_SUBNET_OCID` phải là **public subnet** (có Internet Gateway + Route Table → 0.0.0.0/0 → IGW).
- Security List / NSG phải allow ingress SSH (port 22).

### 5. Telegram không nhận tin
- Check `TELEGRAM_BOT_TOKEN` + `TELEGRAM_CHAT_ID` đúng.
- Bot phải được `/start` trong chat đó trước.

### 5. Workflow không tự disable sau success
- Cần `GH_TOKEN` (có sẵn `github.token`) + quyền `actions: write` (đã config trong workflow).

---

## 🔄 Chạy thủ công (test)

```bash
# Trên GitHub UI:
Actions → Oracle A1 Hunter → Run workflow → Run workflow

# Hoặc trigger qua API:
gh workflow run oracle-a1.yml
```

---

## 📚 Tham khảo

- [Oracle Cloud Always Free](https://www.oracle.com/cloud/free/)
- [OCI CLI Documentation](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm)
- [VM.Standard.A1.Flex Specs](https://docs.oracle.com/en-us/iaas/Content/Compute/References/computeshapes.htm#arm)
- [GitHub Actions Docs](https://docs.github.com/en/actions)

---

## 📜 License

MIT — Tự do sử dụng, chỉnh sửa, chia sẻ.

---

**Chúc anh săn được slot A1 nhanh!** 🎯

*Nếu hữu ích, hãy ⭐ repo để ủng hộ.*