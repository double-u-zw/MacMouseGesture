import Foundation
import Darwin

/// Kernel-owned lifetime lock. Never unlink: doing so allows two different inodes
/// to be locked at once. An exited/crashed process automatically releases flock.
final class SingleInstance {
    enum Result: Equatable { case acquired, alreadyRunning, unavailable }
    private var descriptor: Int32 = -1
    // LEGACY_PRODUCT_ID: stable compatibility namespace shared with Builds 13–15.
    // Do not migrate or unlink this inode when the product bundle identifier changes.
    static var directory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/local.macmousegesture.poc", isDirectory: true)
    }
    func acquire(directory: URL = SingleInstance.directory) -> Result {
        guard descriptor == -1 else { return .acquired }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700])
        } catch { return .unavailable }
        let fd = Darwin.open(directory.appendingPathComponent("instance.lock").path,
                             O_CREAT | O_RDWR | O_CLOEXEC | O_NOFOLLOW, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { return .unavailable }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_uid == getuid(), (info.st_mode & S_IFMT) == S_IFREG,
              info.st_nlink == 1 else { close(fd); return .unavailable }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            let busy = errno == EWOULDBLOCK
            close(fd)
            return busy ? .alreadyRunning : .unavailable
        }
        descriptor = fd
        return .acquired
    }
    deinit { if descriptor >= 0 { close(descriptor) } }
}
