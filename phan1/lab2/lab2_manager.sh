#!/bin/bash

# ============================================================
# lab2_manager.sh - Giao diện quản lý Lab2 (whiptail)
# Thư mục: ~/lapTrinhNhanLinux/project/phan1/lab2
# ============================================================

# Hàm kiểm tra và biên dịch nếu cần
check_and_build() {
    if [ ! -f process_demo ] || [ ! -f file_io ] || [ ! -f file_mmap ] || \
       [ ! -f tcp_server ] || [ ! -f tcp_client ] || [ ! -f udp_server ] || \
       [ ! -f udp_client ] || [ ! -f network_info ]; then
        whiptail --title "Biên dịch" --yesno "Chưa có file thực thi. Bạn có muốn chạy 'make' để biên dịch không?" 10 60
        if [ $? -eq 0 ]; then
            make clean && make
            if [ $? -ne 0 ]; then
                whiptail --msgbox "❌ Biên dịch thất bại. Kiểm tra lỗi." 10 60
                exit 1
            else
                whiptail --msgbox "✅ Biên dịch thành công!" 10 60
            fi
        else
            whiptail --msgbox "Không thể tiếp tục nếu chưa biên dịch." 10 60
            exit 1
        fi
    fi
}

# Hàm mở terminal mới
open_new_terminal() {
    local cmd="$1"
    if command -v gnome-terminal &> /dev/null; then
        gnome-terminal -- bash -c "$cmd; exec bash"
    elif command -v xterm &> /dev/null; then
        xterm -e bash -c "$cmd; exec bash" &
    else
        whiptail --msgbox "Không tìm thấy gnome-terminal hoặc xterm.\nVui lòng mở terminal thủ công và chạy lệnh:\n$cmd" 12 60
    fi
}

# Menu chính
main_menu() {
    while true; do
        choice=$(whiptail --title "QUẢN LÝ LAB 2" \
            --menu "Chọn chương trình cần chạy:" 20 70 10 \
            "1" "process_demo - Tiến trình (fork, exec, wait)" \
            "2" "file_io - Copy file dùng read/write" \
            "3" "file_mmap - Copy file dùng mmap" \
            "4" "network_info - Thông tin mạng" \
            "5" "TCP Server" \
            "6" "TCP Client" \
            "7" "UDP Server" \
            "8" "UDP Client" \
            "9" "Biên dịch lại (make clean && make)" \
            "0" "Thoát" 3>&1 1>&2 2>&3)
        
        case $choice in
            1) run_process_demo ;;
            2) run_file_io ;;
            3) run_file_mmap ;;
            4) run_network_info ;;
            5) run_tcp_server ;;
            6) run_tcp_client ;;
            7) run_udp_server ;;
            8) run_udp_client ;;
            9) rebuild ;;
            0) whiptail --msgbox "Cảm ơn bạn đã sử dụng!" 8 40; exit 0 ;;
            *) whiptail --msgbox "Lựa chọn không hợp lệ!" 8 40 ;;
        esac
    done
}

# ==================== Các hàm chạy chương trình ==================

run_process_demo() {
    ./process_demo 2>&1 | tee /tmp/process_demo.log
    whiptail --textbox /tmp/process_demo.log 20 80 --title "Kết quả process_demo"
}

run_file_io() {
    src=$(whiptail --inputbox "Nhập file nguồn:" 8 60 "source.txt" --title "file_io" 3>&1 1>&2 2>&3)
    [ -z "$src" ] && return
    dest=$(whiptail --inputbox "Nhập file đích:" 8 60 "dest_io.txt" --title "file_io" 3>&1 1>&2 2>&3)
    [ -z "$dest" ] && return
    if [ ! -f "$src" ]; then
        whiptail --msgbox "File nguồn không tồn tại. Tạo file mẫu..." 8 40
        echo "Test content for file_io" > "$src"
    fi
    ./file_io "$src" "$dest" 2>&1 | tee /tmp/file_io.log
    whiptail --textbox /tmp/file_io.log 20 80 --title "Kết quả file_io"
}

run_file_mmap() {
    src=$(whiptail --inputbox "Nhập file nguồn:" 8 60 "source.txt" --title "file_mmap" 3>&1 1>&2 2>&3)
    [ -z "$src" ] && return
    dest=$(whiptail --inputbox "Nhập file đích:" 8 60 "dest_mmap.txt" --title "file_mmap" 3>&1 1>&2 2>&3)
    [ -z "$dest" ] && return
    if [ ! -f "$src" ]; then
        whiptail --msgbox "File nguồn không tồn tại. Tạo file mẫu..." 8 40
        echo "Test content for file_mmap" > "$src"
    fi
    ./file_mmap "$src" "$dest" 2>&1 | tee /tmp/file_mmap.log
    whiptail --textbox /tmp/file_mmap.log 20 80 --title "Kết quả file_mmap"
}

run_network_info() {
    ./network_info 2>&1 | tee /tmp/network_info.log
    whiptail --textbox /tmp/network_info.log 20 80 --title "Thông tin mạng"
}

run_tcp_server() {
    whiptail --msgbox "Mở terminal mới để chạy TCP Server..." 8 40
    open_new_terminal "./tcp_server"
    whiptail --msgbox "TCP Server đã được khởi chạy trong terminal mới.\nHãy mở terminal khác để chạy TCP Client." 10 60
}

run_tcp_client() {
    ip=$(whiptail --inputbox "Nhập địa chỉ IP server (mặc định 127.0.0.1):" 8 60 "127.0.0.1" --title "TCP Client" 3>&1 1>&2 2>&3)
    [ -z "$ip" ] && ip="127.0.0.1"
    ./tcp_client "$ip" 2>&1 | tee /tmp/tcp_client.log
    whiptail --textbox /tmp/tcp_client.log 20 80 --title "Kết quả TCP Client"
}

run_udp_server() {
    whiptail --msgbox "Mở terminal mới để chạy UDP Server..." 8 40
    open_new_terminal "./udp_server"
    whiptail --msgbox "UDP Server đã được khởi chạy trong terminal mới.\nHãy mở terminal khác để chạy UDP Client." 10 60
}

run_udp_client() {
    ip=$(whiptail --inputbox "Nhập địa chỉ IP server (mặc định 127.0.0.1):" 8 60 "127.0.0.1" --title "UDP Client" 3>&1 1>&2 2>&3)
    [ -z "$ip" ] && ip="127.0.0.1"
    ./udp_client "$ip" 2>&1 | tee /tmp/udp_client.log
    whiptail --textbox /tmp/udp_client.log 20 80 --title "Kết quả UDP Client"
}

rebuild() {
    if whiptail --yesno "Bạn có chắc muốn biên dịch lại toàn bộ?" 10 60; then
        make clean && make
        if [ $? -eq 0 ]; then
            whiptail --msgbox "✅ Biên dịch lại thành công!" 10 60
        else
            whiptail --msgbox "❌ Biên dịch thất bại. Kiểm tra lỗi." 10 60
        fi
    fi
}

# ==================== BẮT ĐẦU ====================
check_and_build
main_menu
