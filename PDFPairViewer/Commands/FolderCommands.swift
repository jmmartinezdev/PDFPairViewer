import SwiftUI

private struct OpenFolderByPathKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var openFolderByPath: (() -> Void)? {
        get { self[OpenFolderByPathKey.self] }
        set { self[OpenFolderByPathKey.self] = newValue }
    }
}

struct FolderCommands: Commands {
    @FocusedValue(\.openFolderByPath) private var openFolderByPath

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Open Folder by Path…") { openFolderByPath?() }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .disabled(openFolderByPath == nil)
        }
    }
}
