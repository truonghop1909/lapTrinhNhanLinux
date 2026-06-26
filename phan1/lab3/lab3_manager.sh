#!/bin/bash

# ============================================================
# lab3_manager.sh - Giao diện quản lý Lab3 Kernel Module
# Thư mục: ~/lapTrinhNhanLinux/project/phan1/lab3
#
# Hỗ trợ:
#   - hello_module
#   - proc_module
#   - crypto_module XOR
#   - Mã hóa và giải mã file bằng OpenSSL
# ============================================================

# Đường dẫn thư mục chứa script
LAB3_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

HELLO_DIR="$LAB3_DIR/hello_module"
PROC_DIR="$LAB3_DIR/proc_module"
CRYPTO_DIR="$LAB3_DIR/crypto_module"

# Tên file /proc của crypto_module
XOR_PROC="/proc/xor3"
XOR_RAW_PROC="/proc/xor3_raw"

# ============================================================
# KIỂM TRA CHƯƠNG TRÌNH CẦN THIẾT
# ============================================================

check_whiptail() {
    if ! command -v whiptail >/dev/null 2>&1; then
        echo "whiptail chưa được cài đặt."
        echo "Hãy chạy: sudo apt install whiptail"
        exit 1
    fi
}

check_openssl() {
    if ! command -v openssl >/dev/null 2>&1; then
        whiptail --msgbox \
            "OpenSSL chưa được cài đặt.\n\nHãy chạy:\nsudo apt install openssl" \
            10 60
        return 1
    fi

    return 0
}

check_directories() {
    if [ ! -d "$HELLO_DIR" ]; then
        whiptail --msgbox \
            "Thư mục hello_module không tồn tại:\n$HELLO_DIR" \
            10 70
        exit 1
    fi

    if [ ! -d "$PROC_DIR" ]; then
        whiptail --msgbox \
            "Thư mục proc_module không tồn tại:\n$PROC_DIR" \
            10 70
        exit 1
    fi

    if [ ! -d "$CRYPTO_DIR" ]; then
        whiptail --msgbox \
            "Thư mục crypto_module không tồn tại:\n$CRYPTO_DIR" \
            10 70
        exit 1
    fi
}

# ============================================================
# CÁC HÀM QUẢN LÝ MODULE
# ============================================================

is_loaded() {
    local modname="$1"

    lsmod | grep -q "^${modname}[[:space:]]"
}

build_module() {
    local dir="$1"
    local name="$2"
    local status

    if [ ! -d "$dir" ]; then
        whiptail --msgbox \
            "Thư mục không tồn tại:\n$dir" \
            10 70
        return 1
    fi

    cd "$dir" || {
        whiptail --msgbox \
            "Không thể truy cập thư mục:\n$dir" \
            10 70
        return 1
    }

    {
        echo "Đang làm sạch file build cũ..."
        make clean

        echo
        echo "Đang biên dịch module $name..."
        make
    } > /tmp/module_build.log 2>&1

    status=$?

    if [ "$status" -eq 0 ]; then
        whiptail --msgbox \
            "✅ Biên dịch $name thành công.\n\nFile log:\n/tmp/module_build.log" \
            11 60
        return 0
    fi

    whiptail --textbox /tmp/module_build.log 22 90 \
        --title "❌ Biên dịch $name thất bại"

    return 1
}

load_module() {
    local dir="$1"
    local modname="$2"
    local ko_file="$dir/$modname.ko"
    local status

    if [ ! -f "$ko_file" ]; then
        whiptail --msgbox \
            "Không tìm thấy file module:\n$ko_file\n\nHãy biên dịch module trước." \
            12 70
        return 1
    fi

    if is_loaded "$modname"; then
        whiptail --msgbox \
            "Module $modname đã được load." \
            8 50
        return 0
    fi

    sudo insmod "$ko_file" > /tmp/insmod.log 2>&1
    status=$?

    if [ "$status" -eq 0 ]; then
        whiptail --msgbox \
            "✅ Load module $modname thành công." \
            8 55
        return 0
    fi

    {
        echo "Không thể load module $modname."
        echo
        cat /tmp/insmod.log
        echo
        echo "=== Kernel log gần nhất ==="
        sudo dmesg | tail -30
    } > /tmp/insmod_full.log

    whiptail --textbox /tmp/insmod_full.log 22 90 \
        --title "❌ Load module thất bại"

    return 1
}

unload_module() {
    local modname="$1"
    local status

    if ! is_loaded "$modname"; then
        whiptail --msgbox \
            "Module $modname chưa được load." \
            8 50
        return 0
    fi

    sudo rmmod "$modname" > /tmp/rmmod.log 2>&1
    status=$?

    if [ "$status" -eq 0 ]; then
        whiptail --msgbox \
            "✅ Unload module $modname thành công." \
            8 55
        return 0
    fi

    {
        echo "Không thể unload module $modname."
        echo
        cat /tmp/rmmod.log
        echo
        echo "=== Kernel log gần nhất ==="
        sudo dmesg | tail -30
    } > /tmp/rmmod_full.log

    whiptail --textbox /tmp/rmmod_full.log 22 90 \
        --title "❌ Unload module thất bại"

    return 1
}

view_modinfo() {
    local dir="$1"
    local modname="$2"
    local ko_file="$dir/$modname.ko"

    if [ ! -f "$ko_file" ]; then
        whiptail --msgbox \
            "Không tìm thấy file:\n$ko_file\n\nHãy biên dịch trước." \
            10 70
        return 1
    fi

    modinfo "$ko_file" > /tmp/modinfo.log 2>&1

    whiptail --textbox /tmp/modinfo.log 22 90 \
        --title "Thông tin module $modname"
}

# ============================================================
# XEM VÀ XÓA KERNEL LOG
# ============================================================

view_dmesg() {
    sudo dmesg | tail -50 > /tmp/dmesg.log

    whiptail --textbox /tmp/dmesg.log 24 90 \
        --title "Kernel log - 50 dòng gần nhất"
}

clear_dmesg() {
    if whiptail --yesno \
        "Bạn có chắc muốn xóa toàn bộ kernel log hiện tại không?" \
        9 65
    then
        sudo dmesg -c >/dev/null 2>&1

        if [ $? -eq 0 ]; then
            whiptail --msgbox \
                "✅ Kernel log đã được xóa." \
                8 50
        else
            whiptail --msgbox \
                "❌ Không thể xóa kernel log." \
                8 50
        fi
    fi
}

view_loaded_modules() {
    {
        echo "=== Các module của Lab 3 ==="
        echo

        lsmod | grep -E "^(hello|proc_module|crypto_module)[[:space:]]" ||
            echo "Chưa có module Lab 3 nào được load."

        echo
        echo "=== Toàn bộ module đang được load ==="
        echo

        lsmod
    } > /tmp/lsmod.log

    whiptail --textbox /tmp/lsmod.log 24 90 \
        --title "Danh sách module đang được load"
}

# ============================================================
# KIỂM TRA PROC_MODULE
# ============================================================

test_proc_module() {
    local current
    local new_msg
    local updated

    if ! is_loaded "proc_module"; then
        whiptail --msgbox \
            "Module proc_module chưa được load.\nHãy load module trước." \
            9 55
        return 1
    fi

    if [ ! -e /proc/mymodule ]; then
        whiptail --msgbox \
            "File /proc/mymodule không tồn tại.\nModule có thể chưa tạo proc entry đúng." \
            10 65
        return 1
    fi

    while true; do
        proc_choice=$(whiptail \
            --title "KIỂM TRA PROC_MODULE" \
            --menu "Chọn thao tác:" \
            17 70 7 \
            "1" "Đọc nội dung /proc/mymodule" \
            "2" "Ghi nội dung mới vào /proc/mymodule" \
            "3" "Xem quyền và trạng thái file" \
            "0" "Quay lại menu chính" \
            3>&1 1>&2 2>&3)

        case "$proc_choice" in
            1)
                current=$(cat /proc/mymodule 2>/tmp/proc_read_error.log)

                if [ $? -eq 0 ]; then
                    if [ -z "$current" ]; then
                        current="(Chưa có dữ liệu)"
                    fi

                    whiptail --msgbox \
                        "Nội dung /proc/mymodule:\n\n$current" \
                        14 65
                else
                    whiptail --msgbox \
                        "❌ Không thể đọc /proc/mymodule.\n\nXem log:\n/tmp/proc_read_error.log" \
                        11 65
                fi
                ;;

            2)
                new_msg=$(whiptail \
                    --inputbox "Nhập nội dung mới:" \
                    10 65 "Hello from userspace" \
                    --title "Ghi vào /proc/mymodule" \
                    3>&1 1>&2 2>&3)

                if [ $? -ne 0 ]; then
                    continue
                fi

                if [ -z "$new_msg" ]; then
                    whiptail --msgbox \
                        "Nội dung không được để trống." \
                        8 50
                    continue
                fi

                if printf "%s" "$new_msg" |
                    sudo tee /proc/mymodule >/dev/null
                then
                    updated=$(cat /proc/mymodule 2>/dev/null)

                    whiptail --msgbox \
                        "✅ Ghi thành công.\n\nNội dung mới:\n$updated" \
                        14 65
                else
                    whiptail --msgbox \
                        "❌ Ghi vào /proc/mymodule thất bại." \
                        8 55
                fi
                ;;

            3)
                {
                    echo "=== Trạng thái proc_module ==="
                    lsmod | grep "^proc_module" ||
                        echo "proc_module chưa được load"

                    echo
                    echo "=== File /proc/mymodule ==="
                    ls -l /proc/mymodule 2>&1
                } > /tmp/proc_status.log

                whiptail --textbox /tmp/proc_status.log 15 80 \
                    --title "Trạng thái proc_module"
                ;;

            0|"")
                break
                ;;

            *)
                whiptail --msgbox \
                    "Lựa chọn không hợp lệ." \
                    8 45
                ;;
        esac
    done
}

# ============================================================
# KIỂM TRA CRYPTO_MODULE XOR
# ============================================================

test_xor_module() {
    local decoded
    local new_msg
    local xor_choice
    local status

    if ! is_loaded "crypto_module"; then
        whiptail --msgbox \
            "Module crypto_module chưa được load.\nHãy load module trước." \
            9 60
        return 1
    fi

    if [ ! -e "$XOR_PROC" ]; then
        whiptail --msgbox \
            "File $XOR_PROC không tồn tại.\nModule có thể chưa tạo proc entry đúng." \
            10 65
        return 1
    fi

    if [ ! -e "$XOR_RAW_PROC" ]; then
        whiptail --msgbox \
            "File $XOR_RAW_PROC không tồn tại.\nModule có thể chưa tạo proc entry đúng." \
            10 65
        return 1
    fi

    while true; do
        xor_choice=$(whiptail \
            --title "KIỂM TRA CRYPTO MODULE XOR" \
            --menu "Chọn thao tác:" \
            19 75 9 \
            "1" "Ghi dữ liệu vào /proc/xor3" \
            "2" "Đọc dữ liệu đã giải mã từ /proc/xor3" \
            "3" "Xem dữ liệu mã hóa thô từ /proc/xor3_raw" \
            "4" "Kiểm tra thao tác lseek bằng dd" \
            "5" "Xem trạng thái module và các file /proc" \
            "0" "Quay lại menu chính" \
            3>&1 1>&2 2>&3)

        case "$xor_choice" in
            1)
                new_msg=$(whiptail \
                    --inputbox "Nhập nội dung cần mã hóa bằng XOR:" \
                    10 70 "Hello XOR" \
                    --title "Ghi vào /proc/xor3" \
                    3>&1 1>&2 2>&3)

                if [ $? -ne 0 ]; then
                    continue
                fi

                if [ -z "$new_msg" ]; then
                    whiptail --msgbox \
                        "Nội dung không được để trống." \
                        8 50
                    continue
                fi

                printf "%s" "$new_msg" |
                    sudo tee "$XOR_PROC" >/tmp/xor3_write.log 2>&1

                status=${PIPESTATUS[1]}

                if [ "$status" -eq 0 ]; then
                    decoded=$(cat "$XOR_PROC" 2>/dev/null)

                    whiptail --msgbox \
                        "✅ Ghi và mã hóa thành công.\n\nDữ liệu giải mã khi đọc:\n$decoded" \
                        15 70
                else
                    whiptail --msgbox \
                        "❌ Ghi vào $XOR_PROC thất bại.\n\nXem log:\n/tmp/xor3_write.log" \
                        11 65
                fi
                ;;

            2)
                decoded=$(cat "$XOR_PROC" 2>/tmp/xor3_read_error.log)
                status=$?

                if [ "$status" -eq 0 ]; then
                    if [ -z "$decoded" ]; then
                        decoded="(Chưa có dữ liệu)"
                    fi

                    whiptail --msgbox \
                        "Dữ liệu đã giải mã từ $XOR_PROC:\n\n$decoded" \
                        15 70
                else
                    whiptail --msgbox \
                        "❌ Không thể đọc $XOR_PROC.\n\nXem log:\n/tmp/xor3_read_error.log" \
                        11 65
                fi
                ;;

            3)
                if command -v xxd >/dev/null 2>&1; then
                    sudo xxd "$XOR_RAW_PROC" \
                        > /tmp/xor3_raw.log \
                        2> /tmp/xor3_raw_error.log
                else
                    sudo od -An -tx1c "$XOR_RAW_PROC" \
                        > /tmp/xor3_raw.log \
                        2> /tmp/xor3_raw_error.log
                fi

                status=$?

                if [ "$status" -eq 0 ]; then
                    if [ ! -s /tmp/xor3_raw.log ]; then
                        echo "(Chưa có dữ liệu mã hóa)" \
                            > /tmp/xor3_raw.log
                    fi

                    whiptail --textbox /tmp/xor3_raw.log 22 85 \
                        --title "Dữ liệu mã hóa thô - $XOR_RAW_PROC"
                else
                    whiptail --msgbox \
                        "❌ Không thể đọc $XOR_RAW_PROC.\n\nXem log:\n/tmp/xor3_raw_error.log" \
                        11 65
                fi
                ;;

            4)
                skip_value=$(whiptail \
                    --inputbox "Nhập số byte muốn bỏ qua:" \
                    9 60 "1" \
                    --title "Kiểm tra lseek" \
                    3>&1 1>&2 2>&3)

                if [ $? -ne 0 ]; then
                    continue
                fi

                count_value=$(whiptail \
                    --inputbox "Nhập số byte muốn đọc:" \
                    9 60 "3" \
                    --title "Kiểm tra lseek" \
                    3>&1 1>&2 2>&3)

                if [ $? -ne 0 ]; then
                    continue
                fi

                if ! [[ "$skip_value" =~ ^[0-9]+$ ]] ||
                    ! [[ "$count_value" =~ ^[0-9]+$ ]]
                then
                    whiptail --msgbox \
                        "Giá trị skip và count phải là số nguyên không âm." \
                        9 60
                    continue
                fi

                dd if="$XOR_PROC" \
                    bs=1 \
                    skip="$skip_value" \
                    count="$count_value" \
                    status=none \
                    > /tmp/xor3_lseek_result.log \
                    2> /tmp/xor3_lseek_error.log

                status=$?

                if [ "$status" -eq 0 ]; then
                    if [ ! -s /tmp/xor3_lseek_result.log ]; then
                        echo "(Không có dữ liệu trong vùng đã chọn)" \
                            > /tmp/xor3_lseek_result.log
                    fi

                    whiptail --textbox \
                        /tmp/xor3_lseek_result.log \
                        14 70 \
                        --title "Kết quả kiểm tra lseek"
                else
                    whiptail --msgbox \
                        "❌ Kiểm tra lseek thất bại.\n\nXem log:\n/tmp/xor3_lseek_error.log" \
                        11 65
                fi
                ;;

            5)
                {
                    echo "=== Trạng thái crypto_module ==="
                    lsmod | grep "^crypto_module" ||
                        echo "crypto_module chưa được load"

                    echo
                    echo "=== Các file proc ==="
                    ls -l "$XOR_PROC" "$XOR_RAW_PROC" 2>&1

                    echo
                    echo "=== Dữ liệu giải mã hiện tại ==="
                    cat "$XOR_PROC" 2>/dev/null ||
                        echo "Không thể đọc $XOR_PROC"
                } > /tmp/xor3_status.log

                whiptail --textbox /tmp/xor3_status.log 20 85 \
                    --title "Trạng thái crypto_module"
                ;;

            0|"")
                break
                ;;

            *)
                whiptail --msgbox \
                    "Lựa chọn không hợp lệ." \
                    8 45
                ;;
        esac
    done
}

# ============================================================
# MÃ HÓA VÀ GIẢI MÃ FILE BẰNG OPENSSL
# ============================================================

encrypt_file() {
    local input_file
    local output_file
    local password
    local status

    check_openssl || return 1

    input_file=$(whiptail \
        --inputbox "Nhập đường dẫn file cần mã hóa:" \
        10 70 \
        --title "Mã hóa file bằng AES-256-CBC" \
        3>&1 1>&2 2>&3)

    if [ $? -ne 0 ] || [ -z "$input_file" ]; then
        return
    fi

    if [ ! -f "$input_file" ]; then
        whiptail --msgbox \
            "File không tồn tại:\n$input_file" \
            9 65
        return 1
    fi

    output_file=$(whiptail \
        --inputbox "Nhập đường dẫn file đầu ra:" \
        10 70 "${input_file}.enc" \
        --title "File mã hóa đầu ra" \
        3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then
        return
    fi

    if [ -z "$output_file" ]; then
        output_file="${input_file}.enc"
    fi

    password=$(whiptail \
        --passwordbox "Nhập mật khẩu mã hóa:" \
        10 65 \
        --title "Mật khẩu mã hóa" \
        3>&1 1>&2 2>&3)

    if [ $? -ne 0 ] || [ -z "$password" ]; then
        return
    fi

    openssl enc \
        -aes-256-cbc \
        -salt \
        -pbkdf2 \
        -in "$input_file" \
        -out "$output_file" \
        -pass pass:"$password" \
        2> /tmp/encrypt_error.log

    status=$?

    password=""

    if [ "$status" -eq 0 ]; then
        whiptail --msgbox \
            "✅ Mã hóa thành công.\n\nFile đầu ra:\n$output_file" \
            11 70
    else
        whiptail --msgbox \
            "❌ Mã hóa thất bại.\n\nXem log:\n/tmp/encrypt_error.log" \
            11 65
    fi
}

decrypt_file() {
    local input_file
    local output_file
    local password
    local status

    check_openssl || return 1

    input_file=$(whiptail \
        --inputbox "Nhập đường dẫn file cần giải mã:" \
        10 70 \
        --title "Giải mã file AES-256-CBC" \
        3>&1 1>&2 2>&3)

    if [ $? -ne 0 ] || [ -z "$input_file" ]; then
        return
    fi

    if [ ! -f "$input_file" ]; then
        whiptail --msgbox \
            "File không tồn tại:\n$input_file" \
            9 65
        return 1
    fi

    output_file=$(whiptail \
        --inputbox "Nhập đường dẫn file đầu ra:" \
        10 70 "${input_file%.enc}.dec" \
        --title "File giải mã đầu ra" \
        3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then
        return
    fi

    if [ -z "$output_file" ]; then
        output_file="${input_file%.enc}.dec"
    fi

    password=$(whiptail \
        --passwordbox "Nhập mật khẩu giải mã:" \
        10 65 \
        --title "Mật khẩu giải mã" \
        3>&1 1>&2 2>&3)

    if [ $? -ne 0 ] || [ -z "$password" ]; then
        return
    fi

    openssl enc \
        -d \
        -aes-256-cbc \
        -pbkdf2 \
        -in "$input_file" \
        -out "$output_file" \
        -pass pass:"$password" \
        2> /tmp/decrypt_error.log

    status=$?

    password=""

    if [ "$status" -eq 0 ]; then
        whiptail --msgbox \
            "✅ Giải mã thành công.\n\nFile đầu ra:\n$output_file" \
            11 70
    else
        rm -f "$output_file"

        whiptail --msgbox \
            "❌ Giải mã thất bại.\nMật khẩu có thể sai hoặc file không đúng định dạng.\n\nXem log:\n/tmp/decrypt_error.log" \
            13 70
    fi
}

# ============================================================
# MENU CHÍNH
# ============================================================

main_menu() {
    local choice

    while true; do
        choice=$(whiptail \
            --title "QUẢN LÝ LAB 3 - KERNEL MODULE" \
            --menu "Chọn chức năng:" \
            28 88 20 \
            "1"  "Biên dịch hello_module" \
            "2"  "Biên dịch proc_module" \
            "3"  "Load hello_module" \
            "4"  "Unload hello_module" \
            "5"  "Load proc_module" \
            "6"  "Unload proc_module" \
            "7"  "Xem kernel log dmesg" \
            "8"  "Xóa kernel log" \
            "9"  "Kiểm tra /proc/mymodule" \
            "10" "Xem trạng thái các module" \
            "11" "Xem thông tin hello_module" \
            "12" "Xem thông tin proc_module" \
            "13" "Mã hóa file bằng OpenSSL" \
            "14" "Giải mã file bằng OpenSSL" \
            "15" "Biên dịch crypto_module XOR" \
            "16" "Load crypto_module XOR" \
            "17" "Unload crypto_module XOR" \
            "18" "Kiểm tra /proc/xor3 và xor3_raw" \
            "19" "Xem thông tin crypto_module" \
            "0"  "Thoát chương trình" \
            3>&1 1>&2 2>&3)

        case "$choice" in
            1)
                build_module "$HELLO_DIR" "hello"
                ;;

            2)
                build_module "$PROC_DIR" "proc_module"
                ;;

            3)
                load_module "$HELLO_DIR" "hello"
                ;;

            4)
                unload_module "hello"
                ;;

            5)
                load_module "$PROC_DIR" "proc_module"
                ;;

            6)
                unload_module "proc_module"
                ;;

            7)
                view_dmesg
                ;;

            8)
                clear_dmesg
                ;;

            9)
                test_proc_module
                ;;

            10)
                view_loaded_modules
                ;;

            11)
                view_modinfo "$HELLO_DIR" "hello"
                ;;

            12)
                view_modinfo "$PROC_DIR" "proc_module"
                ;;

            13)
                encrypt_file
                ;;

            14)
                decrypt_file
                ;;

            15)
                build_module "$CRYPTO_DIR" "crypto_module"
                ;;

            16)
                load_module "$CRYPTO_DIR" "crypto_module"
                ;;

            17)
                unload_module "crypto_module"
                ;;

            18)
                test_xor_module
                ;;

            19)
                view_modinfo "$CRYPTO_DIR" "crypto_module"
                ;;

            0|"")
                whiptail --msgbox \
                    "Đã thoát chương trình quản lý Lab 3." \
                    8 55
                exit 0
                ;;

            *)
                whiptail --msgbox \
                    "Lựa chọn không hợp lệ." \
                    8 45
                ;;
        esac
    done
}

# ============================================================
# BẮT ĐẦU CHƯƠNG TRÌNH
# ============================================================

check_whiptail
check_directories
main_menu

