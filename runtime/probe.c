#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/utsname.h>
#include <sys/wait.h>
#include <unistd.h>

/* A real bionic ELF executable, installed by Android's package manager. */
int main(int argc, char **argv)
{
    if (argc != 2 || chdir(argv[1]) != 0) { perror("probe directory"); return 2; }
    char file[] = ".officedroid-probe-XXXXXX";
    int fd = mkstemp(file);
    if (fd < 0) { perror("mkstemp"); return 3; }
    unlink(file);
    const char expected[] = "OfficeDroid";
    char actual[sizeof(expected)] = {0};
    if (write(fd, expected, sizeof(expected)) != sizeof(expected) || lseek(fd, 0, SEEK_SET) < 0 ||
        read(fd, actual, sizeof(actual)) != sizeof(actual) || memcmp(actual, expected, sizeof(actual))) {
        perror("filesystem round trip"); close(fd); return 4;
    }
    close(fd);
    long page_size = sysconf(_SC_PAGESIZE);
    void *memory = mmap(NULL, (size_t)page_size, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (memory == MAP_FAILED) { perror("mmap"); return 5; }
    memcpy(memory, expected, sizeof(expected));
    /* Wine needs anonymous executable mappings after loading PE image data. */
    if (mprotect(memory, (size_t)page_size, PROT_READ | PROT_EXEC) != 0) { perror("mprotect RX"); return 6; }
    munmap(memory, (size_t)page_size);
    pid_t child = fork();
    if (child < 0) { perror("fork"); return 7; }
    if (child == 0) _exit(42);
    int status;
    if (waitpid(child, &status, 0) != child || !WIFEXITED(status) || WEXITSTATUS(status) != 42) return 8;
    struct utsname info;
    if (uname(&info) != 0) return 9;
    printf("{\"ok\":true,\"machine\":\"%s\",\"page_size\":%ld,\"uid\":%ld,\"filesystem\":true,\"fork\":true,\"anonymous_rx\":true}\n",
           info.machine, page_size, (long)getuid());
    return 0;
}
