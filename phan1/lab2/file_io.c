#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/types.h>
#include <string.h>

int main(int argc, char *argv[]) {
    int fd_src, fd_dest;
    char buffer[1024];
    ssize_t bytes_read, bytes_written;

    if (argc != 3) {
        fprintf(stderr, "Usage: %s <source> <destination>\n", argv[0]);
        exit(1);
    }

    fd_src = open(argv[1], O_RDONLY);
    if (fd_src < 0) {
        perror("open source file");
        exit(1);
    }

    // SỬA: O_RDWR thay vì O_WRONLY
    fd_dest = open(argv[2], O_RDWR | O_CREAT | O_TRUNC, 0644);
    if (fd_dest < 0) {
        perror("open destination file");
        close(fd_src);
        exit(1);
    }

    while ((bytes_read = read(fd_src, buffer, sizeof(buffer))) > 0) {
        bytes_written = write(fd_dest, buffer, bytes_read);
        if (bytes_written != bytes_read) {
            perror("write error");
            break;
        }
    }
    if (bytes_read < 0) perror("read error");

    // Đọc lại file đích và in ra stdout
    lseek(fd_dest, 0, SEEK_SET);
    printf("\n=== Noi dung file dich ===\n");
    while ((bytes_read = read(fd_dest, buffer, sizeof(buffer))) > 0) {
        write(1, buffer, bytes_read);
    }
    printf("\n");

    close(fd_src);
    close(fd_dest);
    return 0;
}
