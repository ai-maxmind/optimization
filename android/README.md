# 🚀 Android Studio Optimization Suite

Bộ công cụ tối ưu hiệu năng Android Studio trên Ubuntu.

---

## ⚡ Cài đặt nhanh (3 bước)

### Bước 1: Tải scripts
```bash
git clone <repo-url> ~/android-optimization
cd ~/android-optimization
```

### Bước 2: Cấp quyền
```bash
chmod +x *.sh
```

### Bước 3: Chạy Master Optimizer
```bash
./master-optimizer.sh
```

**Xong!** Chọn level tối ưu phù hợp và để script làm việc.

## 📋 Yêu cầu hệ thống

- ✅ Ubuntu 20.04 trở lên
- ✅ Android Studio đã cài đặt
- ✅ Tối thiểu 8GB RAM (khuyến nghị 16GB+)
- ✅ Java/JDK đã cài đặt

---

## 🛠️ Các scripts chính

### 1. master-optimizer.sh ⭐ BẮT ĐẦU TỪ ĐÂY
```bash
./master-optimizer.sh
```
**Chức năng:** Menu tương tác, tự động chạy các scripts khác  
**Dùng khi:** Lần đầu sử dụng, muốn đơn giản nhất

---

### 2. auto-profiler.sh 🔬 AI Analysis
```bash
./auto-profiler.sh
```
**Chức năng:**
- Phân tích hiệu năng JVM, build, system
- AI đề xuất optimizations phù hợp với máy bạn
- Monitor real-time

**Dùng khi:** Muốn biết máy mình cần optimize gì

---

### 3. benchmark-suite.sh 🏆 Đo Performance
```bash
export TEST_PROJECT=~/your-android-project
./benchmark-suite.sh
```
**Chức năng:**
- Đo tốc độ build, memory, CPU, disk
- So sánh trước/sau optimization
- Tính performance score

**Dùng khi:** Muốn đo lường cải thiện cụ thể

---

### 4. optimize-android-studio.sh
```bash
./optimize-android-studio.sh
```
**Chức năng:** Tối ưu Android Studio (VM options, G1GC, memory)  
**Dùng khi:** Chỉ muốn optimize Studio, không động vào hệ thống

---

### 5. gradle-daemon-optimizer.sh
```bash
./gradle-daemon-optimizer.sh
```
**Chức năng:** Tối ưu Gradle (parallel build, cache, workers)  
**Dùng khi:** Build chậm, Gradle sync lâu

---

### 6. extreme-jvm-tuner.sh
```bash
./extreme-jvm-tuner.sh
```
**Chức năng:** Cấu hình GC algorithms (ZGC, Shenandoah, Parallel)  
**Dùng khi:** Studio bị lag, muốn giảm GC pause time

---

### 7. cpu-memory-affinity.sh
```bash
./cpu-memory-affinity.sh
```
**Chức năng:** CPU pinning, NUMA, memory optimization  
**Dùng khi:** Máy đa CPU, nhiều RAM (16GB+)

---

### 8. emulator-optimizer.sh
```bash
./emulator-optimizer.sh
```
**Chức năng:** Tối ưu Android Emulator, setup KVM  
**Dùng khi:** Emulator chậm, chạy không mượt

---

### 9. advanced-optimizations.sh ⚠️ CẦN SUDO
```bash
sudo ./advanced-optimizations.sh
```
**Chức năng:** Kernel parameters, I/O scheduler, CPU governor  
**Dùng khi:** Muốn hiệu năng cực đại, có quyền sudo

---

## 📊 Workflow khuyến nghị

### Lần đầu sử dụng:

```bash
# 1. Chạy benchmark baseline (trước optimize)
export TEST_PROJECT=~/your-project
./benchmark-suite.sh

# 2. Chạy auto-profiler để xem khuyến nghị
./auto-profiler.sh
# → Chọn [1] Full Profile

# 3. Apply optimizations
./master-optimizer.sh
# → Chọn Level 2 hoặc 3

# 4. Reboot (nếu chạy Level 4)
sudo reboot

# 5. Chạy lại benchmark (sau optimize)
./benchmark-suite.sh

# 6. So sánh kết quả
cat ~/.android-benchmarks/comparison.csv
```

---

## 🎓 Câu hỏi thường gặp

### ❓ Tôi nên dùng script nào trước?
**Trả lời:** Dùng `./master-optimizer.sh` → Chọn Level 2

### ❓ Có cần chạy tất cả scripts không?
**Trả lời:** Không! Master Optimizer đã chạy các scripts cần thiết

### ❓ Có an toàn không?
**Trả lời:** Có. Tất cả files gốc đều được backup tự động

### ❓ Làm sao rollback nếu có vấn đề?
```bash
# Tìm backup files
find ~ -name "*.backup.*"

# Khôi phục (ví dụ)
cp ~/.gradle/gradle.properties.backup.20250118_120000 ~/.gradle/gradle.properties
```

### ❓ Tôi chỉ có 8GB RAM, có dùng được không?
**Trả lời:** Được! Script tự động điều chỉnh theo RAM 

### ❓ Cần cài gì thêm không?
```bash
# Nếu thiếu dependencies
sudo apt-get install openjdk-17-jdk bc
```

### ❓ Làm sao biết đã optimize thành công?
```bash
# Kiểm tra reports
ls -lh ~/*.txt

# Monitor real-time
~/monitor-android-studio.sh
~/gradle-monitor.sh
```


## 🔧 Monitoring & Debugging

### Scripts giám sát (tự động tạo trong ~/)
```bash
~/monitor-android-studio.sh      # Monitor Studio
~/gradle-monitor.sh              # Monitor Gradle
~/monitor-memory-pressure.sh     # Monitor RAM/Swap
~/profile-android-studio-jvm.sh  # JVM profiling
```

### Check optimization status
```bash
# Studio VM options
cat ~/.local/share/Google/AndroidStudio*/studio.vmoptions

# Gradle config
cat ~/.gradle/gradle.properties

# System optimization (nếu chạy Level 4)
sudo systemctl status android-studio-optimize.service
```

---

## ⚠️ Lưu ý quan trọng

### Trước khi chạy:
- ✅ Đóng Android Studio
- ✅ Stop Gradle: `./gradlew --stop` (trong project)
- ✅ Backup quan trọng (script tự backup nhưng nên kiểm tra)

### Level 4 (ULTRA Deep):
- ⚠️ Thay đổi kernel parameters
- ⚠️ Cần reboot sau khi chạy
- ⚠️ Chỉ nên dùng trên máy development chuyên dụng

### Rollback (nếu có vấn đề):
```bash
# User files
cp ~/.gradle/gradle.properties.backup.* ~/.gradle/gradle.properties
cp ~/.local/share/Google/AndroidStudio*/studio.vmoptions.backup.* studio.vmoptions

# System files (nếu chạy Level 4)
sudo cp /etc/sysctl.conf.backup.* /etc/sysctl.conf
sudo sysctl -p

# Restart Gradle
./gradlew --stop
```

---

## 📞 Cần trợ giúp?

### Xem logs & reports:
```bash
# Tất cả reports
ls -lh ~/*report*.txt

# Auto-profiler data
ls -lh ~/.android-studio-profiles/

# Benchmark data
ls -lh ~/.android-benchmarks/
```

### Check errors:
```bash
# Journal logs (nếu Level 4)
sudo journalctl -u android-studio-optimize.service

# Gradle logs
ls ~/.gradle/*.log
```

---

## 🎯 Quick Commands Cheat Sheet

```bash
# Optimization
./master-optimizer.sh              # Menu chính (khuyến nghị)
./auto-profiler.sh                 # AI analysis
./benchmark-suite.sh               # Performance test

# Monitoring
~/monitor-android-studio.sh        # Studio monitor
~/gradle-monitor.sh                # Gradle monitor

# Utilities
~/optimize-android-project.sh      # Optimize project hiện tại
~/gradle-profile.sh                # Profile build với --scan
~/clean-gradle-caches.sh           # Clean Gradle cache
~/warm-gradle-cache.sh             # Pre-download dependencies

# Advanced
~/set-cpu-affinity.sh              # CPU pinning
~/enable-performance-mode.sh       # Max performance (sudo)
~/compact-memory.sh                # Memory defrag (sudo)
```

---

## 🏆 Tips Pro

### Cấu hình cao (32GB+ RAM):
```bash
# Chỉnh trong ~/.gradle/gradle.properties
org.gradle.jvmargs=-Xmx16g -XX:MaxMetaspaceSize=4g

# Chỉnh trong studio.vmoptions
-Xmx12g
```

### RAM Disk (ultimate speed):
```bash
sudo mkdir /mnt/ramdisk
sudo mount -t tmpfs -o size=8G tmpfs /mnt/ramdisk

# Trong build.gradle
android {
    buildDir = "/mnt/ramdisk/${project.name}/build"
}
```

### Switch GC algorithm:
```bash
# ZGC (lowest latency - Java 15+)
cp ~/.local/share/Google/AndroidStudio*/studio-zgc.vmoptions studio.vmoptions

# Shenandoah (balanced - Java 12+)
cp ~/.local/share/Google/AndroidStudio*/studio-shenandoah.vmoptions studio.vmoptions
```
