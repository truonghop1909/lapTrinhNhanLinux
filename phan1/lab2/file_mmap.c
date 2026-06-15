#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <string.h>

int main(int argc, char *argv[]) {
    int fd_src, fd_dest;
    struct stat st;
    char *src_map, *dest_map;

    if (argc != 3) {
        fprintf(stderr, "Usage: %s <source> <destination>\n", argv[0]);
        exit(1);
    }

    fd_src = open(argv[1], O_RDONLY);
    if (fd_src < 0) { perror("open src"); exit(1); }
    if (fstat(fd_src, &st) < 0) { perror("fstat"); close(fd_src); exit(1); }

    fd_dest = open(argv[2], O_RDWR | O_CREAT | O_TRUNC, 0644);
    if (fd_dest < 0) { perror("open dest"); close(fd_src); exit(1); }
    if (ftruncate(fd_dest, st.st_size) < 0) { perror("ftruncate"); close(fd_src); close(fd_dest); exit(1); }

    src_map = mmap(NULL, st.st_size, PROT_READ, MAP_PRIVATE, fd_src, 0);
    dest_map = mmap(NULL, st.st_size, PROT_WRITE, MAP_SHARED, fd_dest, 0);
    if (src_map == MAP_FAILED || dest_map == MAP_FAILED) { perror("mmap"); close(fd_src); close(fd_dest); exit(1); }

    memcpy(dest_map, src_map, st.st_size);

    munmap(src_map, st.st_size);
    munmap(dest_map, st.st_size);
    close(fd_src);
    close(fd_dest);
    printf("Copy thanh cong dung mmap.\n");
    return 0;
}