import SwiftUI

struct ImageAdjusterView: View {
    let originalImage: UIImage
    
    // Callbacks to communicate with whatever view presented this one
    var onSave: (UIImage?) -> Void
    var onCancel: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    // Hardcoded to match the standard hero header height in the app
    let frameHeight: CGFloat = 320 
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.07, blue: 0.08).ignoresSafeArea()
                
                VStack(spacing: 40) {
                    Text("Pinch to zoom. Drag to frame.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    // The Cropping Canvas
                    GeometryReader { geometry in
                        let frameWidth = geometry.size.width
                        
                        ZStack {
                            Image(uiImage: originalImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: frameWidth, height: frameHeight)
                                .scaleEffect(scale)
                                .offset(offset)
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            offset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                        }
                                        .onEnded { _ in
                                            lastOffset = offset
                                        }
                                )
                                .simultaneousGesture(
                                    MagnificationGesture()
                                        .onChanged { value in
                                            scale = lastScale * value
                                        }
                                        .onEnded { _ in
                                            lastScale = scale
                                        }
                                )
                        }
                        .frame(width: frameWidth, height: frameHeight)
                        .clipped() // Creates the visual bounding box
                        .overlay(
                            Rectangle()
                                .stroke(Color.amberGold.opacity(0.8), lineWidth: 2)
                        )
                    }
                    .frame(height: frameHeight)
                    
                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationTitle("Adjust Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                        .foregroundColor(.gray)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        // Passing the screen width to the renderer
                        renderAndSave(frameWidth: UIScreen.main.bounds.width)
                    }
                    .font(.headline)
                    .foregroundColor(.amberGold)
                }
            }
        }
    }
    
    @MainActor
    private func renderAndSave(frameWidth: CGFloat) {
        // 1. Recreate the exact geometry of the cropped area without the UI borders
        let targetView = ZStack {
            Image(uiImage: originalImage)
                .resizable()
                .scaledToFill()
                .frame(width: frameWidth, height: frameHeight)
                .scaleEffect(scale)
                .offset(offset)
        }
        .frame(width: frameWidth, height: frameHeight)
        .clipped()
        
        // 2. Flatten the view into a lightweight UIImage
        let renderer = ImageRenderer(content: targetView)
        // Maintain screen sharpness without inflating the file footprint
        renderer.scale = UIScreen.main.scale 
        
        onSave(renderer.uiImage)
    }
}
