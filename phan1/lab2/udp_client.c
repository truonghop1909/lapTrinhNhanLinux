#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>

#define PORT 9090

int main() {
    int sockfd;
    struct sockaddr_in servaddr;
    char *message = "Hello from UDP client";
    char reply[1024];
    socklen_t len = sizeof(servaddr);

    sockfd = socket(AF_INET, SOCK_DGRAM, 0);
    if (sockfd < 0) { perror("socket failed"); exit(1); }

    memset(&servaddr, 0, sizeof(servaddr));
    servaddr.sin_family = AF_INET;
    servaddr.sin_port = htons(PORT);
    inet_pton(AF_INET, "127.0.0.1", &servaddr.sin_addr);

    sendto(sockfd, message, strlen(message), 0, (struct sockaddr *)&servaddr, len);
    recvfrom(sockfd, reply, 1024, 0, (struct sockaddr *)&servaddr, &len);
    printf("Server tra loi: %s\n", reply);

    close(sockfd);
    return 0;
}