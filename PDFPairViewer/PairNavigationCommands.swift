import SwiftUI

struct PairNavigationActions {
    let previous: (() -> Void)?
    let next: (() -> Void)?
}

private struct PairNavigationKey: FocusedValueKey {
    typealias Value = PairNavigationActions
}

extension FocusedValues {
    var pairNavigation: PairNavigationActions? {
        get { self[PairNavigationKey.self] }
        set { self[PairNavigationKey.self] = newValue }
    }
}

struct PairNavigationCommands: Commands {
    @FocusedValue(\.pairNavigation) private var navigation

    var body: some Commands {
        CommandMenu("Go") {
            Button("Previous Pair") { navigation?.previous?() }
                .keyboardShortcut(.upArrow, modifiers: [])
                .disabled(navigation?.previous == nil)
            Button("Next Pair") { navigation?.next?() }
                .keyboardShortcut(.downArrow, modifiers: [])
                .disabled(navigation?.next == nil)
        }
    }
}
