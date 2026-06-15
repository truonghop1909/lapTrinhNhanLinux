#!/bin/bash

# ============================================
# system_manager.sh - Quản lý hệ thống toàn diện
# Tác giả: [Tên bạn]
# Mô tả: Quản lý file, lập lịch, thời gian, gói phần mềm
# Hỗ trợ đường dẫn có dấu ~
# Khi có lỗi, chương trình dừng lại để bạn kiểm tra
# ============================================

# Cấu hình
LOG_FILE="/var/log/system_manager.log"
BACKUP_DEFAULT_DEST="$HOME/backups"
CONFIG_FILE="$HOME/.system_manager.conf"

# Đảm bảo log file tồn tại và có quyền ghi
sudo touch "$LOG_FILE" 2>/dev/null || LOG_FILE="$HOME/system_manager.log"
sudo chmod 666 "$LOG_FILE" 2>/dev/null

# Hàm mở rộng đường dẫn (hỗ trợ ~ và ~user)
expand_path() {
    local path="$1"
    if [[ "$path" =~ ^~(/|$) ]]; then
        path="${path/#\~/$HOME}"
    fi
    echo "$path"
}

# Hàm ghi log
log() {
    local level="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" | tee -a "$LOG_FILE"
}

# Hàm kiểm tra lỗi (nếu lỗi, dừng lại chờ người dùng)
check_error() {
    if [ $? -ne 0 ]; then
        log "ERROR" "$1"
        echo "❌ Lỗi: $1"
        read -p "Nhấn Enter để tiếp tục..."
        return 1
    fi
    return 0
}

# Hàm chờ người dùng nhấn Enter (dùng thay cho sleep)
pause() {
    read -p "Nhấn Enter để tiếp tục..."
}

# Hàm hiển thị menu chính
show_menu() {
    clear
    echo "============================================"
    echo "       HỆ THỐNG QUẢN LÝ TỔNG HỢP"
    echo "============================================"
    echo "1. Quản lý file"
    echo "2. Lập lịch tác vụ (cron / at)"
    echo "3. Thiết lập thời gian hệ thống"
    echo "4. Quản lý gói phần mềm (apt)"
    echo "5. Xem log hệ thống"
    echo "0. Thoát"
    echo "============================================"
    echo -n "Chọn chức năng [0-5]: "
}

# ==================== 1. QUẢN LÝ FILE ====================
file_menu() {
    while true; do
        clear
        echo "--- QUẢN LÝ FILE ---"
        echo "1. Sao lưu thư mục (backup)"
        echo "2. Dọn dẹp file cũ (cleanup)"
        echo "3. Tạo file mới"
        echo "4. Xóa file/thư mục"
        echo "5. Sao chép file"
        echo "6. Di chuyển/đổi tên"
        echo "7. Tìm kiếm file"
        echo "8. Thay đổi quyền (chmod)"
        echo "9. Nén/Giải nén (tar)"
        echo "0. Quay lại"
        echo -n "Chọn: "
        read -r choice
        case $choice in
            1) backup_files ;;
            2) cleanup_files ;;
            3) create_file ;;
            4) delete_file ;;
            5) copy_file ;;
            6) move_file ;;
            7) search_file ;;
            8) change_permission ;;
            9) tar_compress ;;
            0) break ;;
            *) echo "Lựa chọn không hợp lệ!"; pause ;;
        esac
    done
}

backup_files() {
    echo -n "Nhập thư mục nguồn: "
    read -r src
    src=$(expand_path "$src")
    echo -n "Nhập thư mục đích (mặc định: $BACKUP_DEFAULT_DEST): "
    read -r dest
    dest=$(expand_path "$dest")
    [ -z "$dest" ] && dest="$BACKUP_DEFAULT_DEST"
    
    if [ ! -d "$src" ]; then
        log "ERROR" "Thư mục nguồn $src không tồn tại"
        echo "❌ Thư mục nguồn không tồn tại!"
        pause
        return
    fi
    
    mkdir -p "$dest"
    local backup_name="backup_$(basename "$src")_$(date +%Y%m%d_%H%M%S).tar.gz"
    local backup_path="$dest/$backup_name"
    
    log "INFO" "Bắt đầu sao lưu $src vào $backup_path"
    tar -czf "$backup_path" -C "$(dirname "$src")" "$(basename "$src")"
    if check_error "Sao lưu thất bại"; then
        echo "✅ Sao lưu thành công: $backup_path"
        log "INFO" "Sao lưu thành công: $backup_path"
    fi
    pause
}

cleanup_files() {
    echo -n "Nhập đường dẫn thư mục cần dọn dẹp: "
    read -r path
    path=$(expand_path "$path")
    echo -n "Xóa file cũ hơn bao nhiêu ngày? (vd: 30): "
    read -r days
    
    if [ ! -d "$path" ]; then
        echo "❌ Thư mục không tồn tại!"
        log "ERROR" "Cleanup: $path không tồn tại"
        pause
        return
    fi
    
    echo "⚠️  Các file cũ hơn $days ngày trong $path sẽ bị xóa."
    echo -n "Bạn có chắc chắn? (y/N): "
    read -r confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        find "$path" -type f -mtime +"$days" -exec rm -v {} \; | tee -a "$LOG_FILE"
        if [ $? -eq 0 ]; then
            echo "✅ Đã xóa các file cũ hơn $days ngày."
            log "INFO" "Cleanup $path: xóa file cũ hơn $days ngày"
        else
            echo "❌ Có lỗi khi xóa file."
        fi
    else
        echo "Đã hủy."
    fi
    pause
}

create_file() {
    echo -n "Nhập đường dẫn file cần tạo: "
    read -r filepath
    filepath=$(expand_path "$filepath")
    echo -n "Nhập nội dung (hoặc để trống): "
    read -r content
    if [ -e "$filepath" ]; then
        echo "⚠️  File đã tồn tại. Ghi đè? (y/N): "
        read -r overwrite
        [[ ! "$overwrite" =~ ^[Yy]$ ]] && { pause; return; }
    fi
    echo "$content" > "$filepath"
    if [ $? -eq 0 ]; then
        echo "✅ Đã tạo file $filepath"
        log "INFO" "Tạo file $filepath"
    else
        echo "❌ Không thể tạo file $filepath"
        log "ERROR" "Tạo file $filepath thất bại"
    fi
    pause
}

delete_file() {
    echo -n "Nhập đường dẫn file/thư mục cần xóa: "
    read -r target
    target=$(expand_path "$target")
    if [ ! -e "$target" ]; then
        echo "❌ Không tồn tại!"
        pause
        return
    fi
    echo -n "Xóa vĩnh viễn $target? (y/N): "
    read -r confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        rm -rf "$target"
        if [ $? -eq 0 ]; then
            echo "✅ Đã xóa $target"
            log "INFO" "Xóa $target"
        else
            echo "❌ Xóa thất bại"
            log "ERROR" "Xóa $target thất bại"
        fi
    else
        echo "Đã hủy."
    fi
    pause
}

copy_file() {
    echo -n "Nhập nguồn: "
    read -r src
    src=$(expand_path "$src")
    echo -n "Nhập đích: "
    read -r dest
    dest=$(expand_path "$dest")
    cp -r "$src" "$dest"
    if [ $? -eq 0 ]; then
        echo "✅ Đã sao chép $src -> $dest"
        log "INFO" "Sao chép $src -> $dest"
    else
        echo "❌ Sao chép thất bại"
        log "ERROR" "Sao chép $src -> $dest thất bại"
    fi
    pause
}

move_file() {
    echo -n "Nhập nguồn: "
    read -r src
    src=$(expand_path "$src")
    echo -n "Nhập đích: "
    read -r dest
    dest=$(expand_path "$dest")
    mv "$src" "$dest"
    if [ $? -eq 0 ]; then
        echo "✅ Đã di chuyển/đổi tên thành công"
        log "INFO" "Di chuyển $src -> $dest"
    else
        echo "❌ Di chuyển thất bại"
        log "ERROR" "Di chuyển $src -> $dest thất bại"
    fi
    pause
}

search_file() {
    echo -n "Nhập thư mục gốc tìm kiếm: "
    read -r path
    path=$(expand_path "$path")
    echo -n "Nhập tên file (có thể dùng * ?): "
    read -r pattern
    echo "Kết quả tìm kiếm:"
    find "$path" -type f -name "$pattern" 2>/dev/null | tee -a "$LOG_FILE"
    echo "=== Kết thúc tìm kiếm ==="
    pause
}

change_permission() {
    echo -n "Nhập file/thư mục: "
    read -r target
    target=$(expand_path "$target")
    echo -n "Nhập quyền (vd: 755, 644): "
    read -r perm
    chmod "$perm" "$target"
    if [ $? -eq 0 ]; then
        echo "✅ Đã thay đổi quyền của $target thành $perm"
        log "INFO" "chmod $perm $target"
    else
        echo "❌ Thay đổi quyền thất bại"
        log "ERROR" "chmod $perm $target thất bại"
    fi
    pause
}

tar_compress() {
    echo "1. Nén (tar.gz)"
    echo "2. Giải nén"
    echo -n "Chọn: "
    read -r opt
    if [ "$opt" -eq 1 ]; then
        echo -n "Nhập thư mục/file cần nén: "
        read -r src
        src=$(expand_path "$src")
        echo -n "Nhập tên file đầu ra (không có .tar.gz): "
        read -r outname
        outname=$(expand_path "$outname")
        tar -czf "${outname}.tar.gz" "$src"
        if [ $? -eq 0 ]; then
            echo "✅ Đã nén thành ${outname}.tar.gz"
            log "INFO" "Nén $src thành ${outname}.tar.gz"
        else
            echo "❌ Nén thất bại"
            log "ERROR" "Nén $src thất bại"
        fi
    elif [ "$opt" -eq 2 ]; then
        echo -n "Nhập file .tar.gz cần giải nén: "
        read -r file
        file=$(expand_path "$file")
        echo -n "Nhập thư mục đích (mặc định: .): "
        read -r dest
        dest=$(expand_path "$dest")
        [ -z "$dest" ] && dest="."
        tar -xzf "$file" -C "$dest"
        if [ $? -eq 0 ]; then
            echo "✅ Đã giải nén vào $dest"
            log "INFO" "Giải nén $file vào $dest"
        else
            echo "❌ Giải nén thất bại"
            log "ERROR" "Giải nén $file thất bại"
        fi
    else
        echo "Lựa chọn sai!"
    fi
    pause
}

# ==================== 2. LẬP LỊCH TÁC VỤ ====================
schedule_menu() {
    while true; do
        clear
        echo "--- LẬP LỊCH TÁC VỤ ---"
        echo "1. Thêm tác vụ cron (chạy backup mỗi ngày 2h sáng)"
        echo "2. Xem crontab hiện tại"
        echo "3. Xóa một dòng trong crontab"
        echo "4. Lập lịch với at (chạy một lần)"
        echo "5. Xem danh sách at jobs"
        echo "0. Quay lại"
        echo -n "Chọn: "
        read -r choice
        case $choice in
            1) add_cron_backup ;;
            2) view_crontab ;;
            3) remove_cron_line ;;
            4) schedule_at ;;
            5) view_at_jobs ;;
            0) break ;;
            *) echo "Lựa chọn không hợp lệ!"; pause ;;
        esac
    done
}

add_cron_backup() {
    local backup_script="$HOME/backup.sh"
    if [ ! -f "$backup_script" ]; then
        cat > "$backup_script" << 'EOF'
#!/bin/bash
# backup.sh script tự động được tạo bởi system_manager
src="$1"
dest="$2"
[ -z "$src" ] && src="$HOME/Documents"
[ -z "$dest" ] && dest="$HOME/backups/auto"
mkdir -p "$dest"
backup_name="backup_$(basename "$src")_$(date +%Y%m%d_%H%M%S).tar.gz"
tar -czf "$dest/$backup_name" -C "$(dirname "$src")" "$(basename "$src")"
echo "$(date): Backup $src -> $dest/$backup_name" >> "$HOME/backup.log"
EOF
        chmod +x "$backup_script"
        log "INFO" "Đã tạo script $backup_script mẫu"
        echo "✅ Đã tạo file backup.sh mẫu tại $backup_script"
    fi
    
    echo "Bạn muốn lên lịch backup thư mục nào?"
    read -p "Thư mục nguồn [mặc định: $HOME/Documents]: " src
    src=$(expand_path "${src:-$HOME/Documents}")
    read -p "Thư mục đích [mặc định: $HOME/backups/auto]: " dest
    dest=$(expand_path "${dest:-$HOME/backups/auto}")
    
    cron_line="0 2 * * * $backup_script \"$src\" \"$dest\""
    (crontab -l 2>/dev/null; echo "$cron_line") | crontab -
    if [ $? -eq 0 ]; then
        echo "✅ Đã thêm lịch chạy backup mỗi ngày lúc 2h sáng (cron job)."
        log "INFO" "Thêm cron job: $cron_line"
    else
        echo "❌ Không thể thêm crontab"
        log "ERROR" "Thêm cron job thất bại"
    fi
    pause
}

view_crontab() {
    echo "=== Crontab hiện tại của user $USER ==="
    crontab -l 2>/dev/null || echo "Không có cron job nào."
    pause
}

remove_cron_line() {
    crontab -l 2>/dev/null > /tmp/crontab.tmp
    if [ ! -s /tmp/crontab.tmp ]; then
        echo "Không có cron job nào."
        pause
        return
    fi
    echo "Danh sách cron jobs:"
    nl /tmp/crontab.tmp
    echo -n "Nhập số dòng muốn xóa: "
    read -r line_num
    sed -i "${line_num}d" /tmp/crontab.tmp
    crontab /tmp/crontab.tmp
    if [ $? -eq 0 ]; then
        echo "✅ Đã xóa dòng $line_num"
        log "INFO" "Xóa dòng $line_num trong crontab"
    else
        echo "❌ Xóa thất bại"
        log "ERROR" "Xóa dòng $line_num thất bại"
    fi
    pause
}

schedule_at() {
    if ! command -v at &>/dev/null; then
        echo "⚠️  Lệnh 'at' chưa được cài đặt."
        read -p "Bạn có muốn cài đặt ngay không? (y/N): " ans
        if [[ "$ans" =~ ^[Yy]$ ]]; then
            sudo apt update && sudo apt install -y at
            if [ $? -eq 0 ]; then
                sudo systemctl enable --now atd
                echo "✅ Đã cài đặt at."
            else
                echo "❌ Cài đặt at thất bại."
                pause
                return
            fi
        else
            return
        fi
    fi
    
    echo "Nhập lệnh cần chạy (vd: /home/$USER/backup.sh): "
    read -r command
    echo "Nhập thời điểm chạy (định dạng at, vd: now + 5 minutes, 14:30, 2026-06-16 10:00): "
    read -r time_spec
    echo "$command" | at $time_spec 2>&1 | tee -a "$LOG_FILE"
    if [ $? -eq 0 ]; then
        echo "✅ Đã lên lịch chạy lệnh tại $time_spec"
        log "INFO" "at: $command vào lúc $time_spec"
    else
        echo "❌ Lập lịch at thất bại"
        log "ERROR" "at: $command thất bại"
    fi
    pause
}

view_at_jobs() {
    echo "=== Danh sách at jobs ==="
    atq 2>/dev/null || echo "Không có job nào."
    pause
}

# ==================== 3. THIẾT LẬP THỜI GIAN ====================
time_menu() {
    while true; do
        clear
        echo "--- THIẾT LẬP THỜI GIAN HỆ THỐNG ---"
        echo "1. Hiển thị thời gian hiện tại"
        echo "2. Cài đặt thời gian thủ công (ngày giờ)"
        echo "3. Bật/Tắt đồng bộ NTP"
        echo "4. Đồng bộ ngay với NTP server"
        echo "5. Thay đổi múi giờ"
        echo "0. Quay lại"
        echo -n "Chọn: "
        read -r choice
        case $choice in
            1) show_time ;;
            2) set_time_manual ;;
            3) toggle_ntp ;;
            4) sync_ntp ;;
            5) set_timezone ;;
            0) break ;;
            *) echo "Lựa chọn không hợp lệ!"; pause ;;
        esac
    done
}

show_time() {
    echo "=== Thời gian hệ thống ==="
    date
    echo "=== Thông tin chi tiết ==="
    timedatectl 2>/dev/null || echo "timedatectl không khả dụng (cần systemd)"
    pause
}

set_time_manual() {
    echo -n "Nhập ngày tháng (định dạng YYYY-MM-DD): "
    read -r new_date
    echo -n "Nhập giờ phút giây (HH:MM:SS): "
    read -r new_time
    sudo date -s "$new_date $new_time"
    if [ $? -eq 0 ]; then
        echo "✅ Đã cài đặt thời gian mới."
        log "INFO" "Cài đặt thời gian thủ công: $new_date $new_time"
        sudo hwclock --systohc 2>/dev/null
    else
        echo "❌ Cài đặt thời gian thất bại"
        log "ERROR" "set_time_manual thất bại"
    fi
    pause
}

toggle_ntp() {
    if command -v timedatectl &>/dev/null; then
        current=$(timedatectl show -p NTP --value)
        if [ "$current" = "yes" ]; then
            sudo timedatectl set-ntp false
            echo "✅ Đã TẮT đồng bộ NTP."
            log "INFO" "Tắt NTP"
        else
            sudo timedatectl set-ntp true
            echo "✅ Đã BẬT đồng bộ NTP."
            log "INFO" "Bật NTP"
        fi
    else
        echo "timedatectl không có sẵn. Cài đặt ntp?"
        read -p "Cài đặt ntp? (y/N): " ans
        if [[ "$ans" =~ ^[Yy]$ ]]; then
            sudo apt update && sudo apt install -y ntp
            if [ $? -eq 0 ]; then
                sudo systemctl enable --now ntp
                echo "Đã cài đặt và khởi động ntp."
            else
                echo "Cài đặt thất bại."
            fi
        fi
    fi
    pause
}

sync_ntp() {
    if command -v timedatectl &>/dev/null; then
        sudo timedatectl set-ntp true
        sudo timedatectl set-ntp false   # reset
        sudo timedatectl set-ntp true
        echo "Đã yêu cầu đồng bộ qua NTP."
    else
        sudo ntpdate -u pool.ntp.org 2>/dev/null || sudo ntpd -q
    fi
    if [ $? -eq 0 ]; then
        echo "✅ Đã đồng bộ thời gian."
        log "INFO" "Đồng bộ NTP"
    else
        echo "❌ Đồng bộ NTP thất bại"
        log "ERROR" "sync_ntp thất bại"
    fi
    pause
}

set_timezone() {
    echo "Danh sách múi giờ (có thể nhập tìm kiếm)"
    read -p "Nhập múi giờ (vd: Asia/Ho_Chi_Minh): " tz
    sudo timedatectl set-timezone "$tz" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "✅ Đã đổi múi giờ thành $tz"
        log "INFO" "Đổi múi giờ thành $tz"
    else
        echo "❌ Múi giờ không hợp lệ"
        log "ERROR" "set_timezone $tz thất bại"
    fi
    pause
}

# ==================== 4. QUẢN LÝ GÓI PHẦN MỀM ====================
package_menu() {
    while true; do
        clear
        echo "--- QUẢN LÝ GÓI (APT) ---"
        echo "1. Cài đặt gói (tự động yes)"
        echo "2. Gỡ bỏ gói (tự động yes)"
        echo "3. Cập nhật danh sách gói (apt update)"
        echo "4. Nâng cấp tất cả gói (apt upgrade -y)"
        echo "5. Kiểm tra và cài đặt nếu chưa có"
        echo "6. Tìm kiếm gói"
        echo "7. Xem thông tin gói"
        echo "0. Quay lại"
        echo -n "Chọn: "
        read -r choice
        case $choice in
            1) install_package ;;
            2) remove_package ;;
            3) update_packages ;;
            4) upgrade_packages ;;
            5) check_install_package ;;
            6) search_package ;;
            7) show_package_info ;;
            0) break ;;
            *) echo "Lựa chọn không hợp lệ!"; pause ;;
        esac
    done
}

install_package() {
    echo -n "Nhập tên gói cần cài đặt: "
    read -r pkg
    echo "🔧 Đang cài đặt $pkg ..."
    sudo apt update
    sudo apt install -y "$pkg"
    if [ $? -eq 0 ]; then
        echo "✅ Đã cài đặt $pkg thành công."
        log "INFO" "Cài đặt gói $pkg"
    else
        echo "❌ Cài đặt $pkg thất bại"
        log "ERROR" "Cài đặt $pkg thất bại"
    fi
    pause
}

remove_package() {
    echo -n "Nhập tên gói cần gỡ bỏ: "
    read -r pkg
    sudo apt remove -y "$pkg"
    if [ $? -eq 0 ]; then
        echo "✅ Đã gỡ bỏ $pkg."
        log "INFO" "Gỡ bỏ gói $pkg"
    else
        echo "❌ Gỡ bỏ $pkg thất bại"
        log "ERROR" "Gỡ bỏ $pkg thất bại"
    fi
    pause
}

update_packages() {
    echo "Đang cập nhật danh sách gói..."
    sudo apt update
    if [ $? -eq 0 ]; then
        echo "✅ Hoàn tất update."
        log "INFO" "apt update"
    else
        echo "❌ apt update thất bại"
        log "ERROR" "apt update thất bại"
    fi
    pause
}

upgrade_packages() {
    echo "Đang nâng cấp các gói (có thể mất thời gian)..."
    sudo apt upgrade -y
    if [ $? -eq 0 ]; then
        echo "✅ Nâng cấp hoàn tất."
        log "INFO" "apt upgrade -y"
    else
        echo "❌ Nâng cấp thất bại"
        log "ERROR" "apt upgrade -y thất bại"
    fi
    pause
}

check_install_package() {
    echo -n "Nhập tên gói: "
    read -r pkg
    if dpkg -l | grep -qw "$pkg"; then
        echo "✅ Gói $pkg đã được cài đặt."
        log "INFO" "Kiểm tra gói $pkg: đã cài"
    else
        echo "❌ Gói $pkg chưa được cài đặt. Bạn có muốn cài không? (y/N): "
        read -r ans
        if [[ "$ans" =~ ^[Yy]$ ]]; then
            sudo apt install -y "$pkg"
            if [ $? -eq 0 ]; then
                echo "✅ Đã cài đặt $pkg."
                log "INFO" "Kiểm tra và cài đặt gói $pkg"
            else
                echo "❌ Cài đặt $pkg thất bại"
                log "ERROR" "Cài đặt $pkg thất bại"
            fi
        fi
    fi
    pause
}

search_package() {
    echo -n "Nhập từ khóa tìm kiếm: "
    read -r keyword
    apt-cache search "$keyword" | head -20
    pause
}

show_package_info() {
    echo -n "Nhập tên gói: "
    read -r pkg
    apt-cache show "$pkg" 2>/dev/null || echo "Không tìm thấy thông tin gói $pkg"
    pause
}

# ==================== 5. XEM LOG ====================
view_log() {
    clear
    echo "=== LOG HỆ THỐNG (20 dòng gần nhất) ==="
    tail -20 "$LOG_FILE" 2>/dev/null || echo "Chưa có log nào."
    echo "=========================================="
    pause
}

# ==================== XỬ LÝ THAM SỐ DÒNG LỆNH ====================
process_args() {
    case "$1" in
        backup)
            shift
            backup_files_auto "$1" "$2"
            exit $?
            ;;
        cleanup)
            shift
            cleanup_files_auto "$1" "$2"
            exit $?
            ;;
        install)
            shift
            sudo apt install -y "$@"
            ;;
        remove)
            shift
            sudo apt remove -y "$@"
            ;;
        cron-backup)
            add_cron_backup
            ;;
        at)
            schedule_at
            ;;
        settime)
            sudo date -s "$2"
            ;;
        ntp-on)
            sudo timedatectl set-ntp true
            ;;
        ntp-off)
            sudo timedatectl set-ntp false
            ;;
        help)
            echo "Sử dụng: $0 [command] [options]"
            echo "Các lệnh: backup, cleanup, install, remove, cron-backup, at, settime, ntp-on, ntp-off"
            echo "Ví dụ: $0 backup /home/user/docs /backup"
            echo "       $0 install htop"
            exit 0
            ;;
        *)
            return 0
            ;;
    esac
    exit 0
}

backup_files_auto() {
    src="$1"
    dest="$2"
    src=$(expand_path "$src")
    dest=$(expand_path "$dest")
    
    if [ -z "$src" ]; then
        echo "❌ Lỗi: Thiếu thư mục nguồn. Cú pháp: $0 backup <nguồn> [đích]"
        return 1
    fi
    if [ ! -d "$src" ]; then
        echo "❌ Lỗi: Thư mục nguồn '$src' không tồn tại."
        return 1
    fi
    
    if [ -z "$dest" ]; then
        dest="$HOME/backups"
    fi
    
    mkdir -p "$dest" 2>/dev/null
    if [ ! -w "$dest" ]; then
        echo "❌ Lỗi: Không thể ghi vào '$dest'. Hãy dùng thư mục có quyền viết (ví dụ: $HOME/backups)."
        return 1
    fi
    
    local backup_name="backup_$(basename "$src")_$(date +%Y%m%d_%H%M%S).tar.gz"
    local backup_path="$dest/$backup_name"
    
    echo "Đang sao lưu $src -> $backup_path ..."
    tar -czf "$backup_path" -C "$(dirname "$src")" "$(basename "$src")" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "✅ Backup thành công: $backup_path"
        log "INFO" "CLI backup: $src -> $backup_path"
    else
        echo "❌ Backup thất bại. Kiểm tra lại quyền hoặc đường dẫn."
        return 1
    fi
}

cleanup_files_auto() {
    path="$1"
    days="$2"
    path=$(expand_path "$path")
    
    if [ -z "$path" ] || [ -z "$days" ]; then
        echo "❌ Lỗi: Cú pháp $0 cleanup <đường_dẫn> <số_ngày>"
        return 1
    fi
    
    if [ ! -d "$path" ]; then
        echo "❌ Lỗi: Thư mục '$path' không tồn tại."
        return 1
    fi
    
    if ! [[ "$days" =~ ^[0-9]+$ ]]; then
        echo "❌ Lỗi: Số ngày phải là số nguyên dương."
        return 1
    fi
    
    echo "Đang tìm file cũ hơn $days ngày trong $path ..."
    find "$path" -type f -mtime +"$days" -exec rm -v {} \;
    echo "✅ Đã xóa các file cũ hơn $days ngày."
    log "INFO" "CLI cleanup: $path, days=$days"
}

# ==================== MAIN ====================
main() {
    if [ $# -gt 0 ]; then
        process_args "$@"
    fi
    
    while true; do
        show_menu
        read -r option
        case $option in
            1) file_menu ;;
            2) schedule_menu ;;
            3) time_menu ;;
            4) package_menu ;;
            5) view_log ;;
            0) 
                echo "Cảm ơn bạn đã sử dụng. Tạm biệt!"
                log "INFO" "Thoát chương trình"
                exit 0
                ;;
            *) echo "Lựa chọn không hợp lệ!"; pause ;;
        esac
    done
}

main "$@"