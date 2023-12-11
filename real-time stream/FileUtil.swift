import Foundation

class FileUtil {
    static func deleteFile(at url: URL) {
        DispatchQueue.global(qos: .background).async {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: url.path) {
                do {
                    try fileManager.removeItem(at: url)
                    print("File successfully deleted at url: \(url)")
                } catch {
                    print("Failed to delete file at url: \(url). Error - \(error)")
                }
            }
        }
    }
}
