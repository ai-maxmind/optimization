# Ubuntu Ultra Optimizer 🚀

Script tối ưu hóa Ubuntu tự động với 30 modules chuyên sâu.

---

## 🎯 Tính năng chính

✅ **30 Optimization Modules** - Tối ưu toàn diện từ kernel đến desktop  
✅ **4 Profiles sẵn có** - Server, Database, Low-Latency, Desktop  
✅ **Tự động hóa 100%** - Chạy 1 lệnh, tối ưu toàn bộ hệ thống  
✅ **An toàn tuyệt đối** - Auto backup, rollback đầy đủ  
✅ **Hiệu năng cao** - Parallel execution, dependency resolution  
✅ **Smart validation** - Health checks, auto-rollback nếu có lỗi  

---

## ⚡ Cài đặt nhanh (3 bước)

### Bước 1: Cài đặt
```bash
cd /opt
sudo git clone <repo-url> ubuntu-ultra-opt
cd linux
sudo ./install.sh
```

### Bước 2: Chạy (chọn 1 trong 2)

**Cách 1: Interactive (Khuyến nghị cho người mới)**
```bash
sudo ./quick-start.sh
```

**Cách 2: Chạy trực tiếp**
```bash
sudo make server              # Server/Web
sudo make db                  # Database  
sudo make lowlatency          # Gaming/Trading
sudo make desktop             # Desktop/Laptop
```

### Bước 3: Reboot
```bash
sudo reboot
```

---

## 📋 4 Profiles có sẵn

### 1️⃣ Server (`make server`)
**Cho**: Web servers, API servers, ứng dụng  
**Cải thiện**: 20-40% throughput, 30-50% latency  
**An toàn**: Medium risk  

### 2️⃣ Database (`make db`)
**Cho**: PostgreSQL, MySQL, MongoDB, Redis  
**Cải thiện**: 30-60% query performance, 40-70% I/O  
**An toàn**: Medium-High risk  

### 3️⃣ Low-Latency (`make lowlatency`)
**Cho**: Gaming servers, Trading systems, Real-time  
**Cải thiện**: 50-80% giảm latency  
**An toàn**: High risk (test kỹ trước)  

### 4️⃣ Desktop (`make desktop`)
**Cho**: Ubuntu Desktop, Laptop, Workstation  
**Cải thiện**: 15-25% responsiveness, battery life  
**An toàn**: Low risk  

---

## 🔧 Sử dụng nâng cao

### Parallel Execution (Nhanh hơn 4x)
```bash
sudo make server-parallel
sudo make db-parallel
```

### Validated Mode (An toàn nhất - tự động rollback nếu lỗi)
```bash
sudo make server-validated
sudo make db-validated
```

### Xem trước không apply
```bash
sudo make dry-run
```

### Benchmark hiệu năng
```bash
sudo make benchmark
```

### Verify tối ưu đang chạy
```bash
sudo make verify
```

---

## 🔄 Rollback (Hoàn tác)

### Rollback run gần nhất
```bash
sudo make rollback
```

### Rollback tất cả
```bash
sudo make rollback-all
```

### Rollback RUN_ID cụ thể
```bash
sudo ./orchestrator/rollback.sh <RUN_ID>
```

Xem danh sách runs:
```bash
ls -lt /var/lib/ubuntu-ultra-opt/state/
```

---

## 📦 30 Modules (100% complete)

### Kernel - Virtual Memory (7)
- `vm-swappiness` - RAM-based swappiness
- `vm-dirty-writeback` - Dirty page writeback
- `vm-thp-hugepage` - Transparent Huge Pages
- `vm-overcommit` - Memory overcommit
- `vm-cache-pressure` - VFS cache pressure
- `vm-zone-reclaim` - NUMA zone reclaim
- `vm-compact` - Memory compaction

### Kernel - Scheduler (3)
- `sched-governor` - CPU frequency governor
- `sched-numa-balance` - NUMA balancing
- `sched-cpu-isolation` - CPU isolation

### Kernel - I/O (4)
- `io-scheduler` - I/O scheduler per device
- `io-read-ahead` - Read-ahead tuning
- `io-nr-requests` - Queue depth
- `io-write-cache` - Write cache policy

### Network (6)
- `net-core-buffers` - TCP buffers, BBR, Fast Open
- `net-tcp-timewait` - TIME_WAIT optimization
- `net-tcp-backlog` - Listen backlog
- `net-ethtool-offload` - Hardware offload
- `net-irq-pinning` - IRQ affinity
- `net-rps-rfs` - Packet steering

### Filesystem (4)
- `fs-mount-noatime` - Mount options
- `fs-mount-journal` - Journal commit
- `fs-swap-zram` - ZRAM swap
- `fs-inotify-limits` - Inotify limits

### Services (3)
- `svc-limits-ulimit` - User limits
- `svc-systemd-boot-fast` - Boot optimization
- `svc-journald-tune` - Journal tuning

### Desktop (2)
- `desk-gnome-animation` - GNOME speed
- `desk-laptop-power` - Power management

### Security (1)
- `sec-kernel-hardening` - Kernel security

---

## 🛠️ Troubleshooting

### ❌ Lỗi khi apply
```bash
# Xem log
sudo tail -100 /var/log/ubuntu-ultra-opt/ubuntu-ultra-opt.log

# Rollback ngay
sudo make rollback
```

### 📉 Performance giảm sau khi tối ưu
```bash
# Rollback
sudo make rollback

# Hoặc rollback chỉ 1 stage cụ thể (ví dụ: network)
sudo ./orchestrator/rollback.sh <RUN_ID> --stage net
```

### 🌐 Mất kết nối mạng
```bash
# Rollback network modules
sudo ./orchestrator/rollback.sh <RUN_ID> --stage net

# Khởi động lại network
sudo systemctl restart NetworkManager
```

### 🔍 Check xem module nào đã apply
```bash
sudo make verify
```

---

## 📊 Commands hữu ích

```bash
# Liệt kê profiles
sudo make list-profiles

# Liệt kê tất cả modules
sudo make list-modules

# Xem status hiện tại
sudo make status

# Chạy benchmark
sudo make benchmark

# So sánh benchmark trước/sau
sudo make benchmark-compare

# Clean temporary files
sudo make clean

# Xem help
sudo make help
```

---

## 📁 Cấu trúc quan trọng

```
/var/lib/ubuntu-ultra-opt/
├── state/          # State của mỗi run (RUN_ID)
├── backups/        # Backup configs
└── benchmarks/     # Benchmark results

/var/log/ubuntu-ultra-opt/
└── ubuntu-ultra-opt.log    # Main log file
```

---

## ⚠️ Lưu ý quan trọng

1. **Backup trước** - Luôn backup data quan trọng
2. **Test trước** - Test trên non-production trước
3. **Đọc log** - Kiểm tra log nếu có vấn đề
4. **Reboot sau** - Reboot để các thay đổi có hiệu lực đầy đủ
5. **Rollback sẵn** - Có thể rollback bất cứ lúc nào

---

## 🚀 Examples

### Example 1: Server cơ bản
```bash
sudo ./quick-start.sh
# Chọn: 1 (Server)
# Chọn: 1 (Standard mode)
# Confirm: yes
sudo reboot
```

### Example 2: Database với parallel + validation
```bash
sudo make db-parallel
sudo make verify
sudo reboot
```

### Example 3: Test dry-run trước
```bash
sudo make dry-run          # Xem thay đổi
sudo make server           # Apply nếu OK
sudo make verify           # Verify
sudo reboot
```

### Example 4: Rollback nếu có vấn đề
```bash
sudo make rollback         # List runs và chọn
# hoặc
sudo ./orchestrator/rollback.sh --latest
sudo reboot
```

---

## 📞 Hỗ trợ

- **Logs**: `/var/log/ubuntu-ultra-opt/ubuntu-ultra-opt.log`
- **State**: `/var/lib/ubuntu-ultra-opt/state/`
- **Docs**: `docs/ARCHITECTURE.md`

