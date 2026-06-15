#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>   // <--- DÒNG NÀY RẤT QUAN TRỌNG
#include <sys/wait.h>
#include <signal.h>

void sigint_handler(int sig) {
    printf("\n[CHA] Nhan tin hieu SIGINT (%d). Thoat chuong trinh.\n", sig);
    exit(0);
}

int main() {
    pid_t pid;
    int status;
    signal(SIGINT, sigint_handler);
    pid = fork();
    if (pid < 0) { perror("fork loi"); return 1; }
    if (pid == 0) {
        printf("[CON] PID = %d, cha PID = %d\n", getpid(), getppid());
        printf("[CON] Thuc thi lenh 'ls -l'\n");
        sleep(5);  // chờ 5 giây trước khi chạy ls
        execlp("ls", "ls", "-l", NULL);
        execlp("ls", "ls", "-l", NULL);
        perror("execlp loi");
        exit(1);
    } else {
        printf("[CHA] Da tao con voi PID = %d. Dang cho con ket thuc...\n", pid);
        wait(&status);
        if (WIFEXITED(status))
            printf("[CHA] Con ket thuc voi ma %d\n", WEXITSTATUS(status));
        else
            printf("[CHA] Con ket thuc bat thuong\n");
    }
    return 0;
}