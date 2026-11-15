import SwiftUI

struct FolderPickerView: View {
    @Binding var path: String
    var pathIsFocused: FocusState<Bool>.Binding
    let submit: () -> Void
    let browse: () -> Void

    var body: some View {
        HStack {
            Text("Folder:")
            TextField("/path/to/folder", text: $path)
                .textFieldStyle(.roundedBorder)
                .focused(pathIsFocused)
                .onSubmit(submit)
                .accessibilityLabel("Folder path")
            Button("Open", action: submit)
            Button("Browse…", action: browse)
                .keyboardShortcut("o", modifiers: .command)
        }
    }
}
