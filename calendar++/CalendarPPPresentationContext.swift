import SwiftUI

enum CalendarPPPresentationContext: Equatable {
    case window
    case menuBar
}

private struct CalendarPPPresentationContextKey: EnvironmentKey {
    static let defaultValue: CalendarPPPresentationContext = .window
}

extension EnvironmentValues {
    var calendarPPPresentationContext: CalendarPPPresentationContext {
        get { self[CalendarPPPresentationContextKey.self] }
        set { self[CalendarPPPresentationContextKey.self] = newValue }
    }
}

private struct CalendarPPModalModifier<ModalContent: View>: ViewModifier {
    @Environment(\.calendarPPPresentationContext) private var presentationContext
    @Binding var isPresented: Bool
    let modalContent: () -> ModalContent

    func body(content: Content) -> some View {
        if presentationContext == .menuBar {
            content.popover(isPresented: $isPresented, content: modalContent)
        } else {
            content.sheet(isPresented: $isPresented, content: modalContent)
        }
    }
}

private struct CalendarPPModalItemModifier<Item: Identifiable, ModalContent: View>: ViewModifier {
    @Environment(\.calendarPPPresentationContext) private var presentationContext
    @Binding var item: Item?
    let modalContent: (Item) -> ModalContent

    func body(content: Content) -> some View {
        if presentationContext == .menuBar {
            content.popover(item: $item, content: modalContent)
        } else {
            content.sheet(item: $item, content: modalContent)
        }
    }
}

extension View {
    func calendarppModal<ModalContent: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> ModalContent
    ) -> some View {
        modifier(CalendarPPModalModifier(isPresented: isPresented, modalContent: content))
    }

    func calendarppModal<Item: Identifiable, ModalContent: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> ModalContent
    ) -> some View {
        modifier(CalendarPPModalItemModifier(item: item, modalContent: content))
    }
}

