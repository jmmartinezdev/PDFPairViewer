import Foundation

enum FolderSelectionError: LocalizedError {
    case absolutePathRequired
    case notDirectory
    case inaccessible
    case wrongFolder
    case invalidDrop
    case restoreFailed

    var errorDescription: String? {
        switch self {
        case .absolutePathRequired:
            String(localized: "Enter an absolute folder path, such as /Users/name/Documents, or a path starting with ~.")
        case .notDirectory:
            String(localized: "Choose a folder, not a file.")
        case .inaccessible:
            String(localized: "The folder cannot be read. Use Browse to grant access or choose another folder.")
        case .wrongFolder:
            String(localized: "The selected folder does not match the submitted path. Use Browse to choose a different folder.")
        case .invalidDrop:
            String(localized: "Drop exactly one local folder onto the window.")
        case .restoreFailed:
            String(localized: "The saved folder could not be restored. Use Browse to select it again.")
        }
    }
}
