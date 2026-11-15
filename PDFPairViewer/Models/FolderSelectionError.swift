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
        case .absolutePathRequired: "Enter an absolute folder path, such as /Users/name/Documents, or a path starting with ~."
        case .notDirectory: "Choose a folder, not a file."
        case .inaccessible: "The folder cannot be read. Use Browse to grant access or choose another folder."
        case .wrongFolder: "The selected folder does not match the submitted path. Use Browse to choose a different folder."
        case .invalidDrop: "Drop exactly one local folder onto the window."
        case .restoreFailed: "The saved folder could not be restored. Use Browse to select it again."
        }
    }
}
