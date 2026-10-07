#include <sys/file.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <errno.h>
#include <libproc.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>

// The app uses a user-level instance lock. Check the actual destination executable
// separately, so a running app at another path does not block a new dev package.
static int check_bundle(const char *bundle) {
    char executable[PATH_MAX], resolved[PATH_MAX];
    int length = snprintf(executable, sizeof(executable), "%s/Contents/MacOS/MacMouseGesture", bundle);
    if (length < 0 || (size_t)length >= sizeof(executable)) {
        fprintf(stderr, "Build stopped: bundle path is too long.\n"); return 1;
    }
    if (realpath(executable, resolved)) strcpy(executable, resolved);
    else if (errno != ENOENT) { perror("bundle path"); return 1; }
    int count = proc_listallpids(NULL, 0);
    if (count <= 0) { perror("running process list"); return 1; }
    int capacity = count + 64;
    pid_t *pids = calloc((size_t)capacity, sizeof(*pids));
    if (!pids) { perror("running process list"); return 1; }
    count = proc_listallpids(pids, capacity * (int)sizeof(*pids));
    if (count <= 0 || count >= capacity) {
        fprintf(stderr, "Build stopped: could not inspect the complete running process list.\n");
        free(pids); return 1;
    }
    for (int i = 0; i < count; ++i) {
        char path[PROC_PIDPATHINFO_MAXSIZE];
        if (proc_pidpath(pids[i], path, sizeof(path)) <= 0) continue;
        const char *candidate = realpath(path, resolved) ? resolved : path;
        if (strcmp(candidate, executable) == 0) {
            fprintf(stderr, "Build stopped: the destination app is running; its bundle was not changed.\n");
            free(pids); return 2;
        }
    }
    free(pids); return 0;
}

// Keep the build lock open across exec until packaging finishes.
int main(int argc, char **argv) {
    if (argc == 3 && strcmp(argv[1], "--check-bundle") == 0) return check_bundle(argv[2]);
    if (argc < 3) return 64;
    int fd = open(argv[1], O_CREAT | O_RDWR, 0600);
    if (fd < 0) { perror("build lock"); return 1; }
    if (flock(fd, LOCK_EX | LOCK_NB) != 0) {
        fprintf(stderr, "Build stopped: another build holds the lock.\n");
        close(fd); return 2;
    }
    int command = 2;
    if (strcmp(argv[2], "--bundle") == 0) {
        if (argc < 5) { close(fd); return 64; }
        int result = check_bundle(argv[3]);
        if (result != 0) { close(fd); return result; }
        command = 4;
    }
    // FD_CLOEXEC is deliberately unset; the build process holds this lock.
    execvp(argv[command], &argv[command]);
    perror("build exec"); close(fd); return 1;
}
