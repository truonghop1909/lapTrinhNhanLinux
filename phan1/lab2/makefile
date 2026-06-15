CC = gcc
CFLAGS = -Wall

all: process_demo file_io file_mmap tcp_server tcp_client udp_server udp_client network_info

process_demo: process_demo.c
	$(CC) $(CFLAGS) -o process_demo process_demo.c

file_io: file_io.c
	$(CC) $(CFLAGS) -o file_io file_io.c

file_mmap: file_mmap.c
	$(CC) $(CFLAGS) -o file_mmap file_mmap.c

tcp_server: tcp_server.c
	$(CC) $(CFLAGS) -o tcp_server tcp_server.c

tcp_client: tcp_client.c
	$(CC) $(CFLAGS) -o tcp_client tcp_client.c

udp_server: udp_server.c
	$(CC) $(CFLAGS) -o udp_server udp_server.c

udp_client: udp_client.c
	$(CC) $(CFLAGS) -o udp_client udp_client.c

network_info: network_info.c
	$(CC) $(CFLAGS) -o network_info network_info.c

clean:
	rm -f process_demo file_io file_mmap tcp_server tcp_client udp_server udp_client network_info