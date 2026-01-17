//
//  SessionPhotoViewerView.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/16/26.
//

import SwiftUI

struct SessionPhotoViewerView: View {
    let photos: [SessionPhoto]
    @State var startIndex: Int

    @Environment(\.dismiss) private var dismiss
    @State private var selection: Int

    init(photos: [SessionPhoto], startIndex: Int) {
        self.photos = photos
        self.startIndex = startIndex
        self._selection = State(initialValue: startIndex)
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $selection) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { idx, p in
                    ZoomableImage(relativePath: p.relativePath)
                        .tag(idx)
                        .ignoresSafeArea()
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .background(Color.black.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(selection + 1) / \(photos.count)")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
        }
    }
}

private struct ZoomableImage: View {
    let relativePath: String

    var body: some View {
        Group {
            if let img = PhotoStore.loadImage(relativePath: relativePath) {
                ZoomableScrollView {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                ContentUnavailableView("Photo unavailable", systemImage: "photo", description: Text("The image file couldn’t be loaded."))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.maximumZoomScale = 4
        scrollView.minimumZoomScale = 1
        scrollView.bouncesZoom = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor = .black

        let hosting = UIHostingController(rootView: content)
        hosting.view.backgroundColor = .black
        hosting.view.translatesAutoresizingMaskIntoConstraints = false

        scrollView.addSubview(hosting.view)

        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),

            hosting.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            hosting.view.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        context.coordinator.hosting = hosting
        scrollView.delegate = context.coordinator
        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.hosting?.rootView = content
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var hosting: UIHostingController<Content>?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            hosting?.view
        }
    }
}
