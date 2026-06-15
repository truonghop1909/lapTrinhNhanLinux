#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>

#define PORT 8080
#define BUFFER_SIZE 1024

int main() {
    int server_fd, client_fd;
    struct sockaddr_in address;
    int opt = 1;
    int addrlen = sizeof(address);
    char buffer[BUFFER_SIZE] = {0};

    server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) {
        perror("socket failed");
        exit(1);
    }

    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons(PORT);

    if (bind(server_fd, (struct sockaddr *)&address, sizeof(address)) < 0) {
        perror("bind failed");
        exit(1);
    }
    if (listen(server_fd, 3) < 0) {
        perror("listen failed");
        exit(1);
    }
    printf("TCP Server dang lang nghe tren cong %d...\n", PORT);

    client_fd = accept(server_fd, (struct sockaddr *)&address, (socklen_t*)&addrlen);
    if (client_fd < 0) {
        perror("accept failed");
        exit(1);
    }
    printf("Client ket noi: %s\n", inet_ntoa(address.sin_addr));

    read(client_fd, buffer, BUFFER_SIZE);
    printf("Client gui: %s\n", buffer);
    send(client_fd, "Hello from server", strlen("Hello from server"), 0);

    close(client_fd);
    close(server_fd);
    return 0;
}