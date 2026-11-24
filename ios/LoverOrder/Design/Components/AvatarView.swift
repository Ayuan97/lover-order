import SwiftUI
import UIKit

// 成员头像 有图显示图 没图显示昵称首字 + 墨绿圆底（统一走 RemoteImageCache 避免更新头像时闪烁回首字）
struct AvatarView: View {
    let user: AppUser?
    var size: CGFloat = 24
    var ring: Bool = false

    @State private var loadedImage: UIImage?
    @State private var loadedURL: URL?

    private var resolvedURL: URL? {
        APIConfig.imageURL(user?.avatar)
    }

    var body: some View {
        let displayImage = (loadedURL == resolvedURL ? loadedImage : nil)
            ?? resolvedURL.flatMap { RemoteImageCache.shared.cachedImage(for: $0) }
        Group {
            if let displayImage {
                Image(uiImage: displayImage)
                    .resizable()
                    .scaledToFill()
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
        .task(id: resolvedURL) {
            guard let url = resolvedURL else {
                loadedURL = nil
                loadedImage = nil
                return
            }
            if let cached = RemoteImageCache.shared.cachedImage(for: url) {
                loadedURL = url
                loadedImage = cached
                return
            }
            loadedURL = url
            loadedImage = nil
            let fetched = await RemoteImageCache.shared.load(url: url)
            if !Task.isCancelled {
                loadedURL = url
                loadedImage = fetched
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
