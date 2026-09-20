# Hướng dẫn chi tiết Setup Oracle A1 Hunter

> **Dành cho người mới** — từng bước có hình dung, copy-paste chạy được.

---

## 0️⃣ Yêu cầu trước khi bắt đầu

| Yêu cầu | Mô tả |
|---------|-------|
| **Oracle Cloud Account** | Đã đăng ký Always Free (có tenancy) |
| **GitHub Account** | Để host workflow (miễn phí) |
| **Telegram** | Để nhận thông báo (bot + chat_id) |
| **SSH Key** | Để đăng nhập VPS sau khi tạo |

---

## 1️⃣ Fork / Clone Repository

### Cách 1: Fork trên GitHub (khuyên dùng)
1. Vào https://github.com/Thilee97/oracle-a1-hunter
2. Nhấn **Fork** → chọn tài khoản của bạn
3. Clone repo đã fork về máy:
   ```bash
   git clone https://github.com/<TÊN_BẠN>/oracle-a1-hunter.git
   cd oracle-a1-hunter
   ```

### Cách 2: Clone trực tiếp (nếu không fork)
```bash
git clone https://github.com/Thilee97/oracle-a1-hunter.git
cd oracle-a1-hunter
# Sau khi config xong, push lên repo của bạn
```

---

## 2️⃣ Chuẩn bị Oracle Cloud (OCI)

### 2.1 Tạo API Key

1. Đăng nhập [OCI Console](https://cloud.oracle.com)
2. Góc trên phải → **Profile** (biểu tượng người) → **My profile**
3. Tab **API Keys** → **Add API Key**
4. Chọn **Generate API Key Pair** → **Download Private Key** (file `.pem`)
   - **Lưu file `.pem` an toàn** — đây là `OCI_PRIVATE_KEY`
   - File `.pub` không cần (OCI tự lưu public key)
5. Copy **Fingerprint** hiển thị → đây là `OCI_FINGERPRINT`

### 2.2 Lấy các OCID

| OCID | Nơi lấy |
|------|---------|
| `OCI_TENANCY_OCID` | Profile → Tenancy OCID |
| `OCI_USER_OCID` | Profile → User OCID |
| `OCI_COMPARTMENT_OCID` | Menu ☰ → Identity → Compartments → chọn compartment → Copy OCID |
| `OCI_SUBNET_OCID` | Menu ☰ → Networking → Subnets → chọn **public subnet** → Copy OCID |
| `OCI_IMAGE_OCID` | Compute → Images → **Canonical Ubuntu** (xem phiên bản mới nhất) → Copy OCID |

> 💡 **Mẹo:** Dùng search bar OCI Console gõ tên resource để tìm nhanh.

### 2.3 Kiểm tra Public Subnet

Subnet dùng cho VPS **PHẢI** là public subnet:
- Có **Internet Gateway** gắn
- Route Table có rule `0.0.0.0/0 → Internet Gateway`
- Security List / NSG allow **Ingress port 22 (SSH)** từ `0.0.0.0/0`

Nếu chưa có → tạo mới hoặc sửa Security List.

### 2.5 Policy (Quyền user)

User API key cần policy trong compartment:
```
Allow group <your-group> to manage instance-family in compartment <compartment-name>
Allow group <your-group> to manage virtual-network-family in compartment <compartment-name>
Allow group <your-group> to read instance-images in compartment <compartment-name>
```
Hoặc gán user vào group có sẵn `Administrators`.

---

## 3️⃣ Chuẩn bị SSH Key

### Tạo mới (nếu chưa có)
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/oracle_a1 -C "oracle-a1-hunter"
# Nhấn Enter 3 lần (không passphrase để automation dễ hơn)
```

### Lấy public key
```bash
cat ~/.ssh/oracle_a1.pub
# Copy toàn bộ dòng bắt đầu bằng ssh-rsa AAAA... → đây là OCI_SSH_PUBLIC_KEY
```

> ⚠️ **Private key** (`~/.ssh/oracle_a1`) giữ bí mật — **KHÔNG** để vào GitHub Secrets.

---

## 4️⃣ Chuẩn bị Telegram Bot

### 4.1 Tạo Bot
1. Mở Telegram → search `@BotFather`
2. Gửi `/newbot` → đặt tên (ví dụ: `My Oracle Hunter`) → username kết thúc bằng `bot` (ví dụ: `my_oracle_hunter_bot`)
3. BotFather trả về **Token** → copy → đây là `TELEGRAM_BOT_TOKEN`

### 4.2 Lấy Chat ID
1. Mở Telegram → search `@userinfobot`
2. Gửi `/start` → bot trả về `Id: 123456789` → đây là `TELEGRAM_CHAT_ID`
3. **Quan trọng:** Gửi `/start` cho **bot của bạn** (tên bạn đặt ở 4.1) để bot có quyền gửi tin.

---

## 5️⃣ Thêm GitHub Secrets (14 cái)

### 5.1 Vào Settings
Repo trên GitHub → **Settings** (tab trên cùng) → **Secrets and variables** → **Actions** → **New repository secret**

### 5.2 Danh sách 14 secrets (copy-paste tên chính xác)

| Secret Name | Value | Ghi chú |
|-------------|-------|---------|
| `OCI_PRIVATE_KEY` | **Toàn bộ nội dung file `.pem`** | Copy từ `-----BEGIN PRIVATE KEY-----` đến `-----END PRIVATE KEY-----` |
| `OCI_TENANCY_OCID` | `ocid1.tenancy.oc1..xxxx` | Tenancy OCID |
| `OCI_USER_OCID` | `ocid1.user.oc1..xxxx` | User OCID |
| `OCI_FINGERPRINT` | `aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99` | Fingerprint từ API Key |
| `OCI_REGION` | `ap-singapore-1` | Cứng trong workflow |
| `OCI_COMPARTMENT_OCID` | `ocid1.compartment.oc1..xxxx` | Compartment OCID |
| `OCI_SUBNET_OCID` | `ocid1.subnet.oc1.ap-singapore-1.xxxx` | **Public subnet** OCID |
| `OCI_IMAGE_OCID` | `ocid1.image.oc1.ap-singapore-1.xxxx` | Canonical Ubuntu image OCID |
| `OCI_SSH_PUBLIC_KEY` | `ssh-rsa AAAAB3NzaC1yc2E... user@host` | Từ `cat ~/.ssh/oracle_a1.pub` |
| `TELEGRAM_BOT_TOKEN` | `123456789:ABC-DEF...` | Từ @BotFather |
| `TELEGRAM_CHAT_ID` | `123456789` | Từ @userinfobot |
| `OCI_OCPUS` | `2` | Số OCPU |
| `OCI_MEMORY_GB` | `12` | RAM GB |
| `INSTANCE_NAME` | `oracle-a1-2c12g` | Tên VPS |

> ⚠️ **Cẩn trọng:** Tên secret **PHÂN BIỆT CHỮ HOA/THƯỞNG** — copy chính xác bảng trên.

---

## 6️⃣ Enable & Test Workflow

### 6.1 Enable
1. Vào repo → tab **Actions**
2. Tìm **Oracle A1 Hunter** → nhấn **Enable workflow**

### 6.2 Chạy test (manual)
1. Tab **Actions** → **Oracle A1 Hunter** → **Run workflow** → **Run workflow**
2. Theo dõi run: click vào run đang chạy → xem log step **Hunt A1**

### 6.3 Kiểm tra Telegram
- Nếu secrets đúng → bot sẽ gửi tin nhắn **Heartbeat** sau ~1-2 phút
- Nội dung: `🔄 Oracle A1 Hunter #1 ✅ Workflow vẫn hoạt động. ❌ Chưa có slot...`

---

## 7️⃣ Khi đã có VPS (Success)

Khi workflow tạo thành công VPS:

1. **Telegram nhận 2 tin:**
   - **vps_summary.txt** — tóm tắt đẹp (IP, SSH command, spec)
   - **vps_details.json** — file JSON chi tiết (attach document)

2. **Workflow tự disable** — không chạy nữa (tiết kiệm Actions minutes)

3. **Đăng nhập VPS:**
   ```bash
   # Private key đã tạo ở bước 3: ~/.ssh/oracle_a1
   ssh -i ~/.ssh/oracle_a1 ubuntu@<PUBLIC_IP>
   ```
   (User mặc định Ubuntu = `ubuntu`, Oracle Linux = `opc`)

---

## 8️⃣ Tùy chỉnh (Optional)

### Đổi spec VPS
Sửa file `.github/workflows/oracle-a1.yml` phần `env`:
```yaml
env:
  OCI_OCPUS: "4"          # Max 4 OCPU free tier
  OCI_MEMORY_GB: "24"     # Max 24 GB free tier
  INSTANCE_NAME: my-a1-vps
```
> ⚠️ Free tier total: **4 OCPU + 24 GB RAM**. Nếu đã có VPS khác, trừ đi.

### Đổi Region
Phải đổi **cùng lúc 3 giá trị** (region, image, subnet):
```yaml
OCI_REGION: ap-tokyo-1
OCI_IMAGE_OCID: <image OCID tại Tokyo>
OCI_SUBNET_OCID: <subnet OCID tại Tokyo>
```

### Tắt heartbeat (giảm tin nhắn)
Sửa workflow: xóa step **Send Telegram run status** (lines 80-132) hoặc thêm condition.

---

## 9️⃣ FAQ / Troubleshooting

| Vấn đề | Nguyên nhân | Giải pháp |
|--------|-------------|-----------|
| Workflow fail ngay | Secrets thiếu/sai | Check 14 secrets, tên chính xác, `OCI_PRIVATE_KEY` format `.pem` |
| `Out of capacity` liên tục | Bình thường — A1 free hiếm | Chờ, workflow retry 5p/lần |
| `Invalid compartment` | Compartment OCID sai hoặc thiếu policy | Kiểm tra OCID + policy `manage instance-family` |
| `Subnet not found` / No public IP | Subnet không public / thiếu IGW | Tạo public subnet + IGW + Route Table + Security List port 22 |
| Telegram không nhận tin | Bot token/chat_id sai / chưa `/start` bot | Check token + chat_id, `/start` bot |
| Workflow không disable sau success | Thiếu `actions: write` permission | Workflow đã config `permissions: actions: write` |

---

## 🔄 Chạy lại sau khi đã disable (muốn săn thêm VPS)

Workflow đã disable sau success. Để chạy lại:
1. Actions → Oracle A1 Hunter → **Enable workflow**
2. Run workflow manual hoặc chờ schedule

---

## 📞 Hỗ trợ

- **Issues:** https://github.com/Thilee97/oracle-a1-hunter/issues
- **Discussions:** https://github.com/Thilee97/oracle-a1-hunter/discussions

---

## ✅ Checklist nhanh trước khi chạy

- [ ] Fork/clone repo
- [ ] Tạo OCI API Key → lấy `.pem` + Fingerprint
- [ ] Lấy 5 OCID: Tenancy, User, Compartment, Subnet, Image
- [ ] Tạo SSH key → lấy public key
- [ ] Tạo Telegram Bot → lấy Token + Chat ID
- [ ] Thêm 14 GitHub Secrets (check tên chính xác)
- [ ] Enable workflow
- [ ] Run workflow test
- [ ] Check Telegram heartbeat
- [ ] Chờ VPS → nhận summary + SSH

---

**Chúc bạn săn được A1 nhanh chóng!** 🎯

*Cập nhật: 2026-09-20*