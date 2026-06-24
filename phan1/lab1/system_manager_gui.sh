#!/bin/bash

# ============================================================
# system_manager_gui.sh - Giao diện quản lý hệ thống (whiptail)
# Mô tả: Các chức năng quản lý file, lập lịch, thời gian, gói
# Sử dụng: ./system_manager_gui.sh
# ============================================================

LOG_FILE="$HOME/system_manager.log"

# Hàm ghi log
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$1] $2" >> "$LOG_FILE"
}

# Hàm thông báo kết quả
notify() {
    whiptail --msgbox "$1" 10 60
}

# ===================== MENU CHÍNH ============================
main_menu() {
    while true; do
        choice=$(whiptail --title "HỆ THỐNG QUẢN LÝ TỔNG HỢP" \
            --menu "Chọn chức năng:" 18 60 6 \
            "1" "Quản lý file" \
            "2" "Lập lịch tác vụ (cron / at)" \
            "3" "Thiết lập thời gian hệ thống" \
            "4" "Quản lý gói phần mềm (apt)" \
            "5" "Xem log hệ thống" \
            "0" "Thoát" 3>&1 1>&2 2>&3)
        
        case $choice in
            1) file_menu ;;
            2) schedule_menu ;;
            3) time_menu ;;
            4) package_menu ;;
            5) view_log ;;
            0) 
                whiptail --msgbox "Cảm ơn bạn đã sử dụng!" 8 40
                exit 0
                ;;
            *) whiptail --msgbox "Lựa chọn không hợp lệ!" 8 40 ;;
        esac
    done
}

# ===================== QUẢN LÝ FILE ===========================
file_menu() {
    while true; do
        choice=$(whiptail --title "QUẢN LÝ FILE" \
            --menu "Chọn thao tác:" 18 60 10 \
            "1" "Sao lưu thư mục (backup)" \
            "2" "Dọn dẹp file cũ (cleanup)" \
            "3" "Tạo file mới" \
            "4" "Xóa file/thư mục" \
            "5" "Sao chép file" \
            "6" "Di chuyển/đổi tên" \
            "7" "Tìm kiếm file" \
            "8" "Thay đổi quyền (chmod)" \
            "9" "Nén/Giải nén (tar)" \
            "0" "Quay lại" 3>&1 1>&2 2>&3)
        
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
            *) whiptail --msgbox "Lựa chọn không hợp lệ!" 8 40 ;;
        esac
    done
}

backup_files() {
    src=$(whiptail --inputbox "Nhập thư mục nguồn:" 8 60 --title "Sao lưu" 3>&1 1>&2 2>&3)
    [ -z "$src" ] && return
    dest=$(whiptail --inputbox "Nhập thư mục đích (mặc định: $HOME/backups):" 8 60 --title "Sao lưu" 3>&1 1>&2 2>&3)
    [ -z "$dest" ] && dest="$HOME/backups"
    
    if [ ! -d "$src" ]; then
        whiptail --msgbox "Thư mục nguồn không tồn tại!" 8 40
        return
    fi
    
    mkdir -p "$dest"
    local backup_name="backup_$(basename "$src")_$(date +%Y%m%d_%H%M%S).tar.gz"
    local backup_path="$dest/$backup_name"
    
    tar -czf "$backup_path" -C "$(dirname "$src")" "$(basename "$src")" 2>/dev/null
    if [ $? -eq 0 ]; then
        whiptail --msgbox "✅ Sao lưu thành công:\n$backup_path" 10 60
        log "INFO" "Backup: $src -> $backup_path"
    else
        whiptail --msgbox "❌ Sao lưu thất bại!" 8 40
        log "ERROR" "Backup failed"
    fi
}

cleanup_files() {
    path=$(whiptail --inputbox "Nhập đường dẫn thư mục cần dọn dẹp:" 8 60 --title "Dọn dẹp" 3>&1 1>&2 2>&3)
    [ -z "$path" ] && return
    days=$(whiptail --inputbox "Xóa file cũ hơn bao nhiêu ngày?" 8 60 --title "Dọn dẹp" 3>&1 1>&2 2>&3)
    [ -z "$days" ] && return
    
    if [ ! -d "$path" ]; then
        whiptail --msgbox "Thư mục không tồn tại!" 8 40
        return
    fi
    
    if whiptail --yesno "Bạn có chắc muốn xóa các file cũ hơn $days ngày trong $path?" 10 60; then
        find "$path" -type f -mtime +"$days" -exec rm -v {} \; > /tmp/cleanup.log 2>&1
        whiptail --msgbox "✅ Đã xóa các file cũ hơn $days ngày.\nChi tiết xem /tmp/cleanup.log" 12 60
        log "INFO" "Cleanup: $path, days=$days"
    else
        whiptail --msgbox "Đã hủy." 8 40
    fi
}

create_file() {
    filepath=$(whiptail --inputbox "Nhập đường dẫn file cần tạo:" 8 60 --title "Tạo file" 3>&1 1>&2 2>&3)
    [ -z "$filepath" ] && return
    content=$(whiptail --inputbox "Nhập nội dung (để trống nếu không muốn):" 10 60 --title "Nội dung" 3>&1 1>&2 2>&3)
    
    if [ -e "$filepath" ] && ! whiptail --yesno "File đã tồn tại. Ghi đè?" 8 40; then
        return
    fi
    
    echo "$content" > "$filepath"
    whiptail --msgbox "✅ Đã tạo file $filepath" 8 60
    log "INFO" "Create file: $filepath"
}

delete_file() {
    target=$(whiptail --inputbox "Nhập đường dẫn file/thư mục cần xóa:" 8 60 --title "Xóa" 3>&1 1>&2 2>&3)
    [ -z "$target" ] && return
    if [ ! -e "$target" ]; then
        whiptail --msgbox "Không tồn tại!" 8 40
        return
    fi
    if whiptail --yesno "Bạn có chắc muốn xóa vĩnh viễn $target?" 10 60; then
        rm -rf "$target"
        whiptail --msgbox "✅ Đã xóa $target" 8 60
        log "INFO" "Delete: $target"
    else
        whiptail --msgbox "Đã hủy." 8 40
    fi
}

copy_file() {
    src=$(whiptail --inputbox "Nhập nguồn:" 8 60 --title "Sao chép" 3>&1 1>&2 2>&3)
    [ -z "$src" ] && return
    dest=$(whiptail --inputbox "Nhập đích:" 8 60 --title "Sao chép" 3>&1 1>&2 2>&3)
    [ -z "$dest" ] && return
    cp -r "$src" "$dest" 2>/dev/null
    if [ $? -eq 0 ]; then
        whiptail --msgbox "✅ Sao chép thành công: $src -> $dest" 10 60
        log "INFO" "Copy: $src -> $dest"
    else
        whiptail --msgbox "❌ Sao chép thất bại!" 8 40
    fi
}

move_file() {
    src=$(whiptail --inputbox "Nhập nguồn:" 8 60 --title "Di chuyển/Đổi tên" 3>&1 1>&2 2>&3)
    [ -z "$src" ] && return
    dest=$(whiptail --inputbox "Nhập đích:" 8 60 --title "Di chuyển/Đổi tên" 3>&1 1>&2 2>&3)
    [ -z "$dest" ] && return
    mv "$src" "$dest" 2>/dev/null
    if [ $? -eq 0 ]; then
        whiptail --msgbox "✅ Di chuyển/đổi tên thành công!" 8 60
        log "INFO" "Move: $src -> $dest"
    else
        whiptail --msgbox "❌ Di chuyển thất bại!" 8 40
    fi
}

search_file() {
    path=$(whiptail --inputbox "Nhập thư mục gốc tìm kiếm:" 8 60 --title "Tìm kiếm" 3>&1 1>&2 2>&3)
    [ -z "$path" ] && return
    pattern=$(whiptail --inputbox "Nhập tên file (có thể dùng * ?):" 8 60 --title "Tìm kiếm" 3>&1 1>&2 2>&3)
    [ -z "$pattern" ] && return
    result=$(find "$path" -type f -name "$pattern" 2>/dev/null)
    if [ -n "$result" ]; then
        echo "$result" > /tmp/search_result.txt
        whiptail --textbox /tmp/search_result.txt 20 80 --title "Kết quả tìm kiếm"
    else
        whiptail --msgbox "Không tìm thấy file nào." 8 40
    fi
}

change_permission() {
    target=$(whiptail --inputbox "Nhập file/thư mục:" 8 60 --title "Đổi quyền" 3>&1 1>&2 2>&3)
    [ -z "$target" ] && return
    perm=$(whiptail --inputbox "Nhập quyền (vd: 755, 644):" 8 60 --title "Đổi quyền" 3>&1 1>&2 2>&3)
    [ -z "$perm" ] && return
    chmod "$perm" "$target" 2>/dev/null
    if [ $? -eq 0 ]; then
        whiptail --msgbox "✅ Đã đổi quyền của $target thành $perm" 8 60
        log "INFO" "chmod $perm $target"
    else
        whiptail --msgbox "❌ Đổi quyền thất bại!" 8 40
    fi
}

tar_compress() {
    opt=$(whiptail --menu "Chọn chức năng:" 12 50 2 \
        "1" "Nén (tar.gz)" \
        "2" "Giải nén" 3>&1 1>&2 2>&3)
    case $opt in
        1)
            src=$(whiptail --inputbox "Nhập thư mục/file cần nén:" 8 60 --title "Nén" 3>&1 1>&2 2>&3)
            [ -z "$src" ] && return
            out=$(whiptail --inputbox "Nhập tên file đầu ra (không có .tar.gz):" 8 60 --title "Nén" 3>&1 1>&2 2>&3)
            [ -z "$out" ] && return
            tar -czf "${out}.tar.gz" "$src" 2>/dev/null
            if [ $? -eq 0 ]; then
                whiptail --msgbox "✅ Đã nén thành ${out}.tar.gz" 8 60
                log "INFO" "Compress: $src -> ${out}.tar.gz"
            else
                whiptail --msgbox "❌ Nén thất bại!" 8 40
            fi
            ;;
        2)
            file=$(whiptail --inputbox "Nhập file .tar.gz cần giải nén:" 8 60 --title "Giải nén" 3>&1 1>&2 2>&3)
            [ -z "$file" ] && return
            dest=$(whiptail --inputbox "Nhập thư mục đích (mặc định: .):" 8 60 --title "Giải nén" 3>&1 1>&2 2>&3)
            [ -z "$dest" ] && dest="."
            tar -xzf "$file" -C "$dest" 2>/dev/null
            if [ $? -eq 0 ]; then
                whiptail --msgbox "✅ Đã giải nén vào $dest" 8 60
                log "INFO" "Extract: $file -> $dest"
            else
                whiptail --msgbox "❌ Giải nén thất bại!" 8 40
            fi
            ;;
    esac
}

# ===================== LẬP LỊCH ===============================
schedule_menu() {
    while true; do
        choice=$(whiptail --title "LẬP LỊCH TÁC VỤ" \
            --menu "Chọn thao tác:" 18 60 6 \
            "1" "Thêm cron backup hàng ngày (2h sáng)" \
            "2" "Xem crontab hiện tại" \
            "3" "Xóa một dòng trong crontab" \
            "4" "Lập lịch với at" \
            "5" "Xem at jobs" \
            "0" "Quay lại" 3>&1 1>&2 2>&3)
        
        case $choice in
            1) add_cron_backup ;;
            2) view_crontab ;;
            3) remove_cron_line ;;
            4) schedule_at ;;
            5) view_at_jobs ;;
            0) break ;;
            *) whiptail --msgbox "Lựa chọn không hợp lệ!" 8 40 ;;
        esac
    done
}

add_cron_backup() {
    src=$(whiptail --inputbox "Thư mục nguồn (mặc định: $HOME/Documents):" 8 60 --title "Cron backup" 3>&1 1>&2 2>&3)
    [ -z "$src" ] && src="$HOME/Documents"
    dest=$(whiptail --inputbox "Thư mục đích (mặc định: $HOME/backups/auto):" 8 60 --title "Cron backup" 3>&1 1>&2 2>&3)
    [ -z "$dest" ] && dest="$HOME/backups/auto"
    
    backup_script="$HOME/backup.sh"
    if [ ! -f "$backup_script" ]; then
        cat > "$backup_script" << 'EOF'
#!/bin/bash
src="$1"; dest="$2"
[ -z "$src" ] && src="$HOME/Documents"
[ -z "$dest" ] && dest="$HOME/backups/auto"
mkdir -p "$dest"
backup_name="backup_$(basename "$src")_$(date +%Y%m%d_%H%M%S).tar.gz"
tar -czf "$dest/$backup_name" -C "$(dirname "$src")" "$(basename "$src")"
echo "$(date): Backup $src -> $dest/$backup_name" >> "$HOME/backup.log"
EOF
        chmod +x "$backup_script"
    fi
    
    cron_line="0 2 * * * $backup_script \"$src\" \"$dest\""
    (crontab -l 2>/dev/null; echo "$cron_line") | crontab -
    whiptail --msgbox "✅ Đã thêm cron job chạy mỗi ngày lúc 2h sáng." 10 60
    log "INFO" "Cron added: $cron_line"
}

view_crontab() {
    crontab -l 2>/dev/null > /tmp/crontab.txt
    if [ -s /tmp/crontab.txt ]; then
        whiptail --textbox /tmp/crontab.txt 20 80 --title "Crontab hiện tại"
    else
        whiptail --msgbox "Không có cron job nào." 8 40
    fi
}

remove_cron_line() {
    crontab -l 2>/dev/null > /tmp/crontab.txt
    if [ ! -s /tmp/crontab.txt ]; then
        whiptail --msgbox "Không có cron job nào." 8 40
        return
    fi
    # Hiển thị và chọn dòng để xóa (đơn giản hóa: xóa toàn bộ)
    if whiptail --yesno "Bạn có muốn xóa TOÀN BỘ crontab không?" 8 60; then
        crontab -r
        whiptail --msgbox "✅ Đã xóa toàn bộ crontab." 8 40
        log "INFO" "Crontab cleared"
    else
        whiptail --msgbox "Hủy bỏ." 8 40
    fi
}

schedule_at() {
    if ! command -v at &>/dev/null; then
        if whiptail --yesno "'at' chưa cài. Bạn có muốn cài không?" 8 50; then
            sudo apt update && sudo apt install -y at
            sudo systemctl enable --now atd
        else
            return
        fi
    fi
    cmd=$(whiptail --inputbox "Nhập lệnh cần chạy:" 8 60 --title "Lập lịch at" 3>&1 1>&2 2>&3)
    [ -z "$cmd" ] && return
    time=$(whiptail --inputbox "Thời điểm (vd: now + 5 minutes, 14:30, ...):" 8 60 --title "Lập lịch at" 3>&1 1>&2 2>&3)
    [ -z "$time" ] && return
    echo "$cmd" | at $time 2>&1 | tee -a "$LOG_FILE"
    whiptail --msgbox "✅ Đã lên lịch lệnh tại $time" 10 60
    log "INFO" "at: $cmd at $time"
}

view_at_jobs() {
    atq > /tmp/at_jobs.txt 2>&1
    if [ -s /tmp/at_jobs.txt ]; then
        whiptail --textbox /tmp/at_jobs.txt 15 70 --title "At jobs"
    else
        whiptail --msgbox "Không có at job nào." 8 40
    fi
}

# ===================== THỜI GIAN ==============================
time_menu() {
    while true; do
        choice=$(whiptail --title "THIẾT LẬP THỜI GIAN" \
            --menu "Chọn thao tác:" 18 60 6 \
            "1" "Hiển thị thời gian hiện tại" \
            "2" "Cài đặt thời gian thủ công" \
            "3" "Bật/Tắt NTP" \
            "4" "Đồng bộ NTP" \
            "5" "Thay đổi múi giờ" \
            "0" "Quay lại" 3>&1 1>&2 2>&3)
        
        case $choice in
            1) show_time ;;
            2) set_time_manual ;;
            3) toggle_ntp ;;
            4) sync_ntp ;;
            5) set_timezone ;;
            0) break ;;
            *) whiptail --msgbox "Lựa chọn không hợp lệ!" 8 40 ;;
        esac
    done
}

show_time() {
    date > /tmp/time_info.txt
    timedatectl >> /tmp/time_info.txt 2>/dev/null
    whiptail --textbox /tmp/time_info.txt 15 70 --title "Thời gian hệ thống"
}

set_time_manual() {
    date_str=$(whiptail --inputbox "Nhập ngày (YYYY-MM-DD):" 8 60 --title "Set time" 3>&1 1>&2 2>&3)
    [ -z "$date_str" ] && return
    time_str=$(whiptail --inputbox "Nhập giờ (HH:MM:SS):" 8 60 --title "Set time" 3>&1 1>&2 2>&3)
    [ -z "$time_str" ] && return
    sudo date -s "$date_str $time_str"
    sudo hwclock --systohc 2>/dev/null
    whiptail --msgbox "✅ Đã cài thời gian mới." 8 40
    log "INFO" "Manual set time: $date_str $time_str"
}

toggle_ntp() {
    if command -v timedatectl &>/dev/null; then
        current=$(timedatectl show -p NTP --value)
        if [ "$current" = "yes" ]; then
            sudo timedatectl set-ntp false
            whiptail --msgbox "✅ Đã TẮT NTP." 8 40
        else
            sudo timedatectl set-ntp true
            whiptail --msgbox "✅ Đã BẬT NTP." 8 40
        fi
        log "INFO" "NTP toggled"
    else
        whiptail --msgbox "timedatectl không khả dụng." 8 40
    fi
}

sync_ntp() {
    sudo timedatectl set-ntp true
    sudo timedatectl set-ntp false
    sudo timedatectl set-ntp true
    whiptail --msgbox "✅ Đã yêu cầu đồng bộ NTP." 8 40
    log "INFO" "NTP sync requested"
}

set_timezone() {
    tz=$(whiptail --inputbox "Nhập múi giờ (vd: Asia/Ho_Chi_Minh):" 8 60 --title "Múi giờ" 3>&1 1>&2 2>&3)
    [ -z "$tz" ] && return
    sudo timedatectl set-timezone "$tz" 2>/dev/null
    if [ $? -eq 0 ]; then
        whiptail --msgbox "✅ Đã đổi múi giờ thành $tz" 8 40
        log "INFO" "Timezone changed to $tz"
    else
        whiptail --msgbox "❌ Múi giờ không hợp lệ!" 8 40
    fi
}

# ===================== QUẢN LÝ GÓI ============================
package_menu() {
    while true; do
        choice=$(whiptail --title "QUẢN LÝ GÓI (APT)" \
            --menu "Chọn thao tác:" 18 60 8 \
            "1" "Cài đặt gói" \
            "2" "Gỡ bỏ gói" \
            "3" "Cập nhật danh sách gói" \
            "4" "Nâng cấp tất cả gói" \
            "5" "Kiểm tra và cài nếu chưa có" \
            "6" "Tìm kiếm gói" \
            "7" "Xem thông tin gói" \
            "0" "Quay lại" 3>&1 1>&2 2>&3)
        
        case $choice in
            1) install_package ;;
            2) remove_package ;;
            3) update_packages ;;
            4) upgrade_packages ;;
            5) check_install_package ;;
            6) search_package ;;
            7) show_package_info ;;
            0) break ;;
            *) whiptail --msgbox "Lựa chọn không hợp lệ!" 8 40 ;;
        esac
    done
}

install_package() {
    pkg=$(whiptail --inputbox "Nhập tên gói cần cài:" 8 60 --title "Cài gói" 3>&1 1>&2 2>&3)
    [ -z "$pkg" ] && return
    sudo apt update && sudo apt install -y "$pkg" 2>&1 | tee /tmp/apt.log
    if [ $? -eq 0 ]; then
        whiptail --msgbox "✅ Cài đặt $pkg thành công." 8 40
        log "INFO" "Installed $pkg"
    else
        whiptail --msgbox "❌ Cài đặt $pkg thất bại. Xem /tmp/apt.log" 8 60
    fi
}

remove_package() {
    pkg=$(whiptail --inputbox "Nhập tên gói cần gỡ:" 8 60 --title "Gỡ gói" 3>&1 1>&2 2>&3)
    [ -z "$pkg" ] && return
    sudo apt remove -y "$pkg" 2>&1 | tee /tmp/apt.log
    if [ $? -eq 0 ]; then
        whiptail --msgbox "✅ Gỡ bỏ $pkg thành công." 8 40
        log "INFO" "Removed $pkg"
    else
        whiptail --msgbox "❌ Gỡ bỏ $pkg thất bại. Xem /tmp/apt.log" 8 60
    fi
}

update_packages() {
    sudo apt update 2>&1 | tee /tmp/apt.log
    whiptail --msgbox "✅ Cập nhật danh sách gói hoàn tất." 8 40
    log "INFO" "apt update"
}

upgrade_packages() {
    if whiptail --yesno "Nâng cấp tất cả gói? (có thể mất nhiều thời gian)" 10 60; then
        sudo apt upgrade -y 2>&1 | tee /tmp/apt.log
        whiptail --msgbox "✅ Nâng cấp hoàn tất." 8 40
        log "INFO" "apt upgrade"
    fi
}

check_install_package() {
    pkg=$(whiptail --inputbox "Nhập tên gói:" 8 60 --title "Kiểm tra gói" 3>&1 1>&2 2>&3)
    [ -z "$pkg" ] && return
    if dpkg -l | grep -qw "$pkg"; then
        whiptail --msgbox "✅ Gói $pkg đã được cài đặt." 8 40
    else
        if whiptail --yesno "❌ Gói $pkg chưa cài. Bạn có muốn cài không?" 10 60; then
            sudo apt install -y "$pkg"
            whiptail --msgbox "✅ Đã cài $pkg." 8 40
            log "INFO" "Installed $pkg via check"
        fi
    fi
}

search_package() {
    keyword=$(whiptail --inputbox "Nhập từ khóa tìm kiếm:" 8 60 --title "Tìm kiếm gói" 3>&1 1>&2 2>&3)
    [ -z "$keyword" ] && return
    apt-cache search "$keyword" | head -20 > /tmp/search.txt
    whiptail --textbox /tmp/search.txt 20 80 --title "Kết quả tìm kiếm"
}

show_package_info() {
    pkg=$(whiptail --inputbox "Nhập tên gói:" 8 60 --title "Thông tin gói" 3>&1 1>&2 2>&3)
    [ -z "$pkg" ] && return
    apt-cache show "$pkg" 2>/dev/null > /tmp/info.txt
    if [ -s /tmp/info.txt ]; then
        whiptail --textbox /tmp/info.txt 20 80 --title "Thông tin gói $pkg"
    else
        whiptail --msgbox "Không tìm thấy thông tin gói $pkg" 8 40
    fi
}

# ===================== XEM LOG ================================
view_log() {
    if [ -f "$LOG_FILE" ]; then
        tail -30 "$LOG_FILE" > /tmp/log.txt
        whiptail --textbox /tmp/log.txt 20 80 --title "Log hệ thống (30 dòng gần nhất)"
    else
        whiptail --msgbox "Chưa có log." 8 40
    fi
}

# ===================== MAIN ===================================
main_menu
