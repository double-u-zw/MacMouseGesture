#include <sys/file.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <errno.h>

// Shares the experiment's lock. Keep it open across exec until packaging finishes.
// Running apps and concurrent builds therefore cannot have their bundle replaced.
int main(int argc, char **argv) {
    if (argc < 3) return 64;
    int fd = open(argv[1], O_CREAT | O_RDWR, 0600);
    if (fd < 0) { perror("build lock"); return 1; }
    if (flock(fd, LOCK_EX | LOCK_NB) != 0) {
        fprintf(stderr, "Build stopped: MacMouseGesture is running or another build holds the lock. Quit the app first; its authorized bundle was not changed.\n");
        close(fd); return 2;
    }
    // FD_CLOEXEC is deliberately unset; the build process holds this lock.
    execvp(argv[2], &argv[2]);
    perror("build exec"); close(fd); return 1;
}
