import SwiftUI

// 成员头像 有图显示图 没图显示昵称首字 + 墨绿圆底
struct AvatarView: View {
    let user: AppUser?
    var size: CGFloat = 24
    var ring: Bool = false

    var body: some View {
        Group {
            if let url = APIConfig.imageURL(user?.avatar) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        initialCircle
                    }
                }
            } else {
                initialCircle
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            if ring {
                Circle().strokeBorder(Color.brandGreen.opacity(0.3), lineWidth: 1)
            }
        }
    }

    private var initialCircle: some View {
        ZStack {
            Color.brandGreen.opacity(0.85)
            Text(String((user?.displayName ?? "?").prefix(1)))
                .font(.system(size: size * 0.46, weight: .medium))
                .foregroundStyle(.white)
        }
    }
}
