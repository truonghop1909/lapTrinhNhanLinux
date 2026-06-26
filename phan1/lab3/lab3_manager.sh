#!/bin/bash

# ============================================================
# lab3_manager.sh - Giao diện quản lý Lab3 (kernel module)
# Thư mục: ~/lapTrinhNhanLinux/project/phan1/lab3
# Hỗ trợ: hello_module, proc_module, crypto_module (XOR)
# ============================================================

# Đường dẫn tuyệt đối
LAB3_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELLO_DIR="$LAB3_DIR/hello_module"
PROC_DIR="$LAB3_DIR/proc_module"
CRYPTO_DIR="$LAB3_DIR/crypto_module"

# Kiểm tra thư mục
if [ ! -d "$HELLO_DIR" ]; then
    whiptail --msgbox "Thư mục hello_module không tồn tại!" 8 60
    exit 1
fi
if [ ! -d "$PROC_DIR" ]; then
    whiptail --msgbox "Thư mục proc_module không tồn tại!" 8 60
    exit 1
fi
if [ ! -d "$CRYPTO_DIR" ]; then
    whiptail --msgbox "Thư mục crypto_module không tồn tại!" 8 60
    exit 1
fi

# Hàm kiểm tra openssl (cho mã hóa/giải mã file)
check_openssl() {
    if ! command -v openssl &> /dev/null; then
        whiptail --msgbox "openssl chưa được cài đặt. Vui lòng cài: sudo apt install openssl" 8 60
        return 1
    fi
    return 0
}

# Hàm kiểm tra module đã load chưa
is_loaded() {
    local modname="$1"
    lsmod | grep -q "^$modname"
}

# Hàm biên dịch module host
build_module() {
    local dir="$1"
    local name="$2"
    if [ ! -d "$dir" ]; then
        whiptail --msgbox "Thư mục $dir không tồn tại!" 8 60
        return 1
    fi
    cd "$dir" || return 1
    make clean 2>/dev/null
    if make; then
        whiptail --msgbox "✅ Biên dịch $name thành công!" 8 60
        return 0
    else
        whiptail --msgbox "❌ Biên dịch $name thất bại." 8 60
        return 1
    fi
}

# Hàm load module
load_module() {
    local dir="$1"
    local modname="$2"
    local ko_file="$dir/$modname.ko"
    if [ ! -f "$ko_file" ]; then
        whiptail --msgbox "File $ko_file không tồn tại. Hãy biên dịch trước." 8 60
        return 1
    fi
    if is_loaded "$modname"; then
        whiptail --msgbox "Module $modname đã được load." 8 40
        return 0
    fi
    sudo insmod "$ko_file" 2>&1 | tee /tmp/insmod.log
    if [ $? -eq 0 ]; then
        whiptail --msgbox "✅ Load module $modname thành công." 8 40
        return 0
    else
        whiptail --msgbox "❌ Load module thất bại.\nXem log: /tmp/insmod.log" 10 60
        return 1
    fi
}

# Hàm unload module
unload_module() {
    local modname="$1"
    if ! is_loaded "$modname"; then
        whiptail --msgbox "Module $modname chưa được load." 8 40
        return 0
    fi
    sudo rmmod "$modname" 2>&1 | tee /tmp/rmmod.log
    if [ $? -eq 0 ]; then
        whiptail --msgbox "✅ Unload module $modname thành công." 8 40
        return 0
    else
        whiptail --msgbox "❌ Unload thất bại.\nXem log: /tmp/rmmod.log" 10 60
        return 1
    fi
}

# Hàm xem dmesg
view_dmesg() {
    dmesg | tail -30 > /tmp/dmesg.log
    whiptail --textbox /tmp/dmesg.log 20 80 --title "Kernel log (30 dòng gần nhất)"
}

# Hàm xóa dmesg (clear log)
clear_dmesg() {
    if whiptail --yesno "Bạn có chắc muốn xóa toàn bộ kernel log?" 8 60; then
        sudo dmesg -c > /dev/null 2>&1
        whiptail --msgbox "✅ Kernel log đã được xóa." 8 40
    else
        whiptail --msgbox "Hủy bỏ." 8 40
    fi
}

# Hàm kiểm tra /proc/mymodule
test_proc_module() {
    if ! is_loaded "proc_module"; then
        whiptail --msgbox "Module proc_module chưa được load. Hãy load trước." 8 40
        return 1
    fi
    if [ ! -f /proc/mymodule ]; then
        whiptail --msgbox "File /proc/mymodule không tồn tại. Module có thể chưa tạo đúng." 8 50
        return 1
    fi
    # Đọc nội dung hiện tại
    current=$(cat /proc/mymodule 2>/dev/null)
    whiptail --msgbox "Nội dung hiện tại của /proc/mymodule:\n$current" 12 60
    
    # Hỏi ghi nội dung mới?
    if whiptail --yesno "Bạn có muốn ghi nội dung mới vào /proc/mymodule không?" 10 60; then
        new_msg=$(whiptail --inputbox "Nhập tin nhắn mới:" 8 60 "Hello from userspace" --title "Ghi vào /proc/mymodule" 3>&1 1>&2 2>&3)
        if [ -n "$new_msg" ]; then
            echo "$new_msg" | sudo tee /proc/mymodule > /dev/null
            if [ $? -eq 0 ]; then
                updated=$(cat /proc/mymodule 2>/dev/null)
                whiptail --msgbox "✅ Ghi thành công.\nNội dung mới:\n$updated" 12 60
            else
                whiptail --msgbox "❌ Ghi thất bại." 8 40
            fi
        fi
    fi
}

# Hàm kiểm tra /proc/xor (crypto_module)
test_xor_module() {
    if ! is_loaded "crypto_module"; then
        whiptail --msgbox "Module crypto_module chưa được load. Hãy load trước." 8 40
        return 1
    fi
    if [ ! -f /proc/xor ]; then
        whiptail --msgbox "File /proc/xor không tồn tại. Module có thể chưa tạo đúng." 8 50
        return 1
    fi
    
    # Đọc nội dung hiện tại
    current=$(cat /proc/xor 2>/dev/null)
    whiptail --msgbox "Nội dung hiện tại của /proc/xor:\n$current" 12 60
    
    # Hỏi ghi nội dung mới?
    if whiptail --yesno "Bạn có muốn ghi nội dung mới vào /proc/xor (mã hóa tự động)?" 10 60; then
        new_msg=$(whiptail --inputbox "Nhập tin nhắn mới:" 8 60 "Hello XOR" --title "Ghi vào /proc/xor" 3>&1 1>&2 2>&3)
        if [ -n "$new_msg" ]; then
            echo "$new_msg" > /proc/xor
            if [ $? -eq 0 ]; then
                updated=$(cat /proc/xor 2>/dev/null)
                whiptail --msgbox "✅ Ghi thành công (đã mã hóa).\nNội dung giải mã khi đọc:\n$updated" 12 60
            else
                whiptail --msgbox "❌ Ghi thất bại." 8 40
            fi
        fi
    fi
}

# Hàm xem thông tin module (modinfo)
view_modinfo() {
    local dir="$1"
    local modname="$2"
    local ko_file="$dir/$modname.ko"
    if [ ! -f "$ko_file" ]; then
        whiptail --msgbox "File $ko_file không tồn tại. Hãy biên dịch trước." 8 60
        return 1
    fi
    modinfo "$ko_file" > /tmp/modinfo.log 2>&1
    whiptail --textbox /tmp/modinfo.log 20 80 --title "Thông tin module $modname"
}

# ==================== CHỨC NĂNG MÃ HÓA/GIẢI MÃ FILE (OPENSSL) ====================

encrypt_file() {
    check_openssl || return 1
    
    local input_file=$(whiptail --inputbox "Nhập đường dẫn file cần mã hóa:" 8 60 --title "Mã hóa file" 3>&1 1>&2 2>&3)
    [ -z "$input_file" ] && return
    if [ ! -f "$input_file" ]; then
        whiptail --msgbox "File không tồn tại!" 8 40
        return 1
    fi
    
    local output_file=$(whiptail --inputbox "Nhập tên file đầu ra (mặc định: input_file.enc):" 8 60 "${input_file}.enc" --title "Mã hóa file" 3>&1 1>&2 2>&3)
    [ -z "$output_file" ] && output_file="${input_file}.enc"
    
    local password=$(whiptail --passwordbox "Nhập mật khẩu mã hóa:" 8 60 --title "Mật khẩu" 3>&1 1>&2 2>&3)
    [ -z "$password" ] && return
    
    openssl enc -aes-256-cbc -salt -pbkdf2 -in "$input_file" -out "$output_file" -pass pass:"$password" 2>/tmp/encrypt_error.log
    if [ $? -eq 0 ]; then
        whiptail --msgbox "✅ Mã hóa thành công!\nFile đầu ra: $output_file" 10 60
    else
        whiptail --msgbox "❌ Mã hóa thất bại.\nXem log: /tmp/encrypt_error.log" 10 60
    fi
}

decrypt_file() {
    check_openssl || return 1
    
    local input_file=$(whiptail --inputbox "Nhập đường dẫn file cần giải mã:" 8 60 --title "Giải mã file" 3>&1 1>&2 2>&3)
    [ -z "$input_file" ] && return
    if [ ! -f "$input_file" ]; then
        whiptail --msgbox "File không tồn tại!" 8 40
        return 1
    fi
    
    local output_file=$(whiptail --inputbox "Nhập tên file đầu ra (mặc định: input_file.dec):" 8 60 "${input_file%.enc}.dec" --title "Giải mã file" 3>&1 1>&2 2>&3)
    [ -z "$output_file" ] && output_file="${input_file%.enc}.dec"
    
    local password=$(whiptail --passwordbox "Nhập mật khẩu giải mã:" 8 60 --title "Mật khẩu" 3>&1 1>&2 2>&3)
    [ -z "$password" ] && return
    
    openssl enc -d -aes-256-cbc -salt -pbkdf2 -in "$input_file" -out "$output_file" -pass pass:"$password" 2>/tmp/decrypt_error.log
    if [ $? -eq 0 ]; then
        whiptail --msgbox "✅ Giải mã thành công!\nFile đầu ra: $output_file" 10 60
    else
        whiptail --msgbox "❌ Giải mã thất bại. Sai mật khẩu hoặc file không đúng định dạng.\nXem log: /tmp/decrypt_error.log" 12 60
    fi
}

# ==================== MENU CHÍNH ====================
main_menu() {
    while true; do
        choice=$(whiptail --title "QUẢN LÝ LAB 3 - KERNEL MODULE (HOST)" \
            --menu "Chọn thao tác:" 24 80 18 \
            "1" "Biên dịch hello_module" \
            "2" "Biên dịch proc_module" \
            "3" "Load hello_module" \
            "4" "Unload hello_module" \
            "5" "Load proc_module" \
            "6" "Unload proc_module" \
            "7" "Xem kernel log (dmesg)" \
            "8" "Xóa kernel log (clear dmesg)" \
            "9" "Kiểm tra /proc/mymodule" \
            "10" "Xem trạng thái module (lsmod)" \
            "11" "Xem thông tin hello_module" \
            "12" "Xem thông tin proc_module" \
            "13" "Mã hóa file (openssl)" \
            "14" "Giải mã file (openssl)" \
            "15" "Biên dịch crypto_module (XOR)" \
            "16" "Load crypto_module (XOR)" \
            "17" "Unload crypto_module (XOR)" \
            "18" "Kiểm tra /proc/xor (XOR)" \
            "0" "Thoát" 3>&1 1>&2 2>&3)
        
        case $choice in
            1) build_module "$HELLO_DIR" "hello" ;;
            2) build_module "$PROC_DIR" "proc_module" ;;
            3) load_module "$HELLO_DIR" "hello" ;;
            4) unload_module "hello" ;;
            5) load_module "$PROC_DIR" "proc_module" ;;
            6) unload_module "proc_module" ;;
            7) view_dmesg ;;
            8) clear_dmesg ;;
            9) test_proc_module ;;
            10) 
                lsmod > /tmp/lsmod.log
                whiptail --textbox /tmp/lsmod.log 20 80 --title "Danh sách module đã load"
                ;;
            11) view_modinfo "$HELLO_DIR" "hello" ;;
            12) view_modinfo "$PROC_DIR" "proc_module" ;;
            13) encrypt_file ;;
            14) decrypt_file ;;
            15) build_module "$CRYPTO_DIR" "crypto_module" ;;
            16) load_module "$CRYPTO_DIR" "crypto_module" ;;
            17) unload_module "crypto_module" ;;
            18) test_xor_module ;;
            0) 
                whiptail --msgbox "Cảm ơn bạn đã sử dụng!" 8 40
                exit 0
                ;;
            *) whiptail --msgbox "Lựa chọn không hợp lệ!" 8 40 ;;
        esac
    done
}

# ==================== BẮT ĐẦU ====================
main_menu