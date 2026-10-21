import SwiftUI

struct PhotoStickerSheet: View {
    var onAdded: (String) -> Void

    var body: some View {
        CameraCaptureView(mode: .sticker) { photo in
            guard let png = photo.cutoutData else { throw CocoaError(.fileReadCorruptFile) }
            let uploaded = try await UploadService.shared.uploadImage(png, filename: "sticker.png", mime: "image/png")
            onAdded(uploaded.path)
        }
    }
}
