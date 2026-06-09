import SwiftUI

// 统一轻提示 顶部滑入的深色浮层 用于操作失败/提示 自动消失 也可点掉
private struct ToastModifier: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let text = message {
                    banner(text)
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.top, AppSpacing.sm)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(1)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: message)
            .task(id: message) {
                guard message != nil else { return }
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                message = nil
            }
    }

    private func banner(_ text: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(.white.opacity(0.85))
            Text(text)
                .font(AppFont.body(14))
                .foregroundStyle(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 10)
        .background(Color.accentInk)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        .appCardShadow()
        .contentShape(Rectangle())
        .onTapGesture { message = nil }
    }
}

extension View {
    // 绑定一个 String? 非空即浮现一条提示 用于把 ViewModel 的 errorMessage 显式呈现给用户
    func toast(_ message: Binding<String?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}
