# Redis Scripts for Ubuntu

Bộ scripts siêu tối ưu để cài đặt, gỡ cài đặt và tối ưu hóa Redis trên Ubuntu.

## 📋 Mục lục

- [Yêu cầu hệ thống](#yêu-cầu-hệ-thống)
- [Cài đặt](#cài-đặt)
- [Gỡ cài đặt](#gỡ-cài-đặt)
- [Tối ưu hóa](#tối-ưu-hóa)
- [Các scripts hỗ trợ](#các-scripts-hỗ-trợ)
- [Tính năng](#tính-năng)
- [FAQ](#faq)

## 🖥️ Yêu cầu hệ thống

- **OS**: Ubuntu 20.04, 22.04, hoặc 24.04
- **RAM**: Tối thiểu 1GB, khuyến nghị 4GB+
- **Disk**: Tối thiểu 1GB trống, khuyến nghị SSD
- **CPU**: 1 core+, khuyến nghị 2+ cores
- **Quyền**: Root hoặc sudo

## 📦 Cài đặt

### Cài đặt Redis từ mã nguồn với siêu tối ưu

```bash
# Download script
wget https://raw.githubusercontent.com/yourusername/optimization/main/redis/install_redis.sh

# Hoặc nếu đã clone repo:
cd redis

# Cấp quyền thực thi
chmod +x install_redis.sh

# Chạy script với quyền root
sudo ./install_redis.sh
```


### Sau khi cài đặt:

```bash
# Kiểm tra trạng thái
sudo systemctl status redis

# Kết nối Redis CLI
redis-cli

# Test ping
redis-cli ping
# Kết quả: PONG

# Kiểm tra version
redis-cli --version

# Chạy benchmark nhanh
redis-benchmark -q -n 100000
```

## 🗑️ Gỡ cài đặt

### Gỡ cài đặt hoàn toàn Redis

```bash
# Cấp quyền thực thi
chmod +x uninstall_redis.sh

# Chạy script
sudo ./uninstall_redis.sh
```

## ⚡ Tối ưu hóa

### Siêu tối ưu hóa Redis đã cài đặt

```bash
# Cấp quyền thực thi
chmod +x optimize_redis.sh

# Chạy script
sudo ./optimize_redis.sh
```

### Các tối ưu hóa được áp dụng:

#### 1. **Auto-detection tài nguyên**
- Tự động phát hiện CPU cores, RAM, loại disk
- Điều chỉnh cấu hình phù hợp với phần cứng

#### 2. **Redis Configuration**
- `maxmemory`: 60-70% RAM tổng
- `io-threads`: Tối ưu theo CPU cores
- Active defragmentation
- Lazy freeing
- AOF persistence với everysec fsync
- Memory policies tối ưu

#### 3. **Kernel Optimization**
- Network tuning (somaxconn, tcp_max_syn_backlog)
- Memory management (vm.overcommit_memory, vm.swappiness)
- File system limits
- TCP keepalive và timeout

#### 4. **Systemd Service**
- LimitNOFILE: 1048576
- Nice priority: -5
- OOM protection
- Security hardening

#### 5. **Monitoring & Maintenance**
- Script giám sát hiệu suất
- Script benchmark
- Script backup tự động
- Script cleanup

## 🛠️ Các scripts hỗ trợ

Sau khi tối ưu hóa, bạn sẽ có các scripts sau:

### 1. **redis-monitor.sh** - Giám sát hiệu suất

```bash
redis-monitor.sh
```

Hiển thị:
- Memory usage
- Operations per second
- Connected clients
- Cache hit rate
- Slow queries
- System resources

### 2. **redis-benchmark-test.sh** - Kiểm tra hiệu suất

```bash
redis-benchmark-test.sh
```

Chạy:
- Benchmark với 100,000 requests
- Latency test
- Throughput test

### 3. **redis-backup.sh** - Backup dữ liệu

```bash
redis-backup.sh
```

Tính năng:
- BGSAVE để không block operations
- Backup dump.rdb và AOF
- Tự động xóa backup cũ hơn 7 ngày
- Lưu tại `/var/backups/redis`

### 4. **redis-clean.sh** - Dọn dẹp database

```bash
redis-clean.sh
```

Cho phép:
- Xem memory usage
- Flush all databases (với xác nhận)

## 🎯 Tính năng nổi bật

### 1. **Hiệu suất cao**
- Biên dịch với jemalloc (allocator tối ưu)
- IO threads cho multi-threading
- Pipeline và connection pooling ready
- Lazy freeing giảm blocking

### 2. **Persistence linh hoạt**
- RDB snapshots tối ưu
- AOF với fsync everysec
- RDB + AOF hybrid mode

### 3. **Memory management thông minh**
- Auto eviction với LRU
- Active defragmentation
- Maxmemory protection

### 4. **Security**
- Protected mode mặc định
- Systemd security hardening
- OOM protection
- Proper file permissions

### 5. **Production-ready**
- Systemd integration
- Auto-restart on failure
- Proper logging
- Monitoring tools

## 📊 Benchmark mẫu

Trên VPS 2 CPU, 4GB RAM, SSD:

```
PING_INLINE: 94786.73 requests per second
PING_BULK: 95693.78 requests per second
SET: 92592.59 requests per second
GET: 95693.78 requests per second
INCR: 93632.96 requests per second
LPUSH: 91743.12 requests per second
RPUSH: 92592.59 requests per second
LPOP: 93457.94 requests per second
RPOP: 92592.59 requests per second
SADD: 94339.62 requests per second
HSET: 91743.12 requests per second
SPOP: 95238.10 requests per second
ZADD: 90909.09 requests per second
ZPOPMIN: 93457.94 requests per second
LPUSH (needed to benchmark LRANGE): 91743.12 requests per second
LRANGE_100 (first 100 elements): 39062.50 requests per second
LRANGE_300 (first 300 elements): 15625.00 requests per second
LRANGE_500 (first 450 elements): 11111.11 requests per second
LRANGE_600 (first 600 elements): 8333.33 requests per second
MSET (10 keys): 71428.57 requests per second
```

## 🔧 Cấu hình nâng cao

### Đặt password

```bash
# Edit config
sudo nano /etc/redis/redis.conf

# Tìm và bỏ comment dòng:
requirepass your_strong_password_here

# Restart
sudo systemctl restart redis

# Test
redis-cli -a your_strong_password_here ping
```

### Cho phép remote access

```bash
# Edit config
sudo nano /etc/redis/redis.conf

# Thay đổi:
bind 127.0.0.1
# Thành:
bind 0.0.0.0

# Đặt password (BẮT BUỘC cho remote access!)
requirepass your_strong_password

# Restart
sudo systemctl restart redis

# Mở firewall (nếu cần)
sudo ufw allow 6379/tcp
```

**⚠️ Cảnh báo**: Không expose Redis ra internet không có password!

### Tuning theo use case

#### Cache Server
```conf
maxmemory-policy allkeys-lru
appendonly no
save ""
```

#### Session Store
```conf
maxmemory-policy volatile-lru
appendonly yes
appendfsync everysec
```

#### Message Queue
```conf
appendonly yes
appendfsync always
maxmemory-policy noeviction
```

## 📝 FAQ

### Redis không khởi động được?

```bash
# Kiểm tra logs
sudo journalctl -u redis -n 50

# Kiểm tra cấu hình
redis-server /etc/redis/redis.conf --test-memory 1024

# Kiểm tra THP
cat /sys/kernel/mm/transparent_hugepage/enabled
# Nên thấy: [never]
```

### Memory usage cao?

```bash
# Kiểm tra memory
redis-cli INFO memory

# Xem keys lớn nhất
redis-cli --bigkeys

# Giảm maxmemory trong config
sudo nano /etc/redis/redis.conf
# Tìm: maxmemory 2gb
# Sửa thành giá trị thấp hơn
```

### Hiệu suất thấp?

```bash
# Kiểm tra slow queries
redis-cli SLOWLOG GET 10

# Chạy latency test
redis-cli --latency

# Kiểm tra system resources
redis-monitor.sh

# Re-optimize
sudo ./optimize_redis.sh
```

### Cần cluster/replication?

Scripts này cài đặt Redis standalone. Để setup:

**Replication (Master-Slave)**:
```bash
# Trên slave server
redis-cli REPLICAOF master-ip 6379
```

**Cluster**:
```bash
# Cần cài đặt nhiều instance và config cluster
redis-cli --cluster create [nodes]
```
