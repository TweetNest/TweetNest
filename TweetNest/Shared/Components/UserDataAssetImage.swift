//
//  UserDataAssetImage.swift
//  UserDataAssetImage
//
//  Created by Jaehong Kang on 2021/08/08.
//

import SwiftUI
import ImageIO
import UniformTypeIdentifiers
import CoreData
import TweetNestKit
import UnifiedLogging

struct UserDataAssetImage: View {
    let url: URL?
    let isExportable: Bool

    @State private var dataAssetsFetchedResultsController: FetchedResultsController<ManagedUserDataAsset>

    struct ImageData: Equatable {
        var data: Data
        var dataMIMEType: String?
    }
    @State private var imageData: ImageData?

    @State private var cgImage: CGImage?
    @State private var cgImageScale: CGFloat?

    @State private var isDetailProfileImagePresented: Bool = false

    var body: some View {
        Group {
            #if os(macOS) || os(iOS)
            if
                isExportable,
                let url = url,
                let cgImage = cgImage,
                let imageData = imageData
            {
                let utType = imageData.dataMIMEType.flatMap({ UTType(mimeType: $0, conformingTo: .image) }) ?? UTType.image
                let filename = url.pathExtension.isEmpty ? url.appendingPathExtension(for: utType).lastPathComponent : url.lastPathComponent

                Group {
                    #if os(macOS)
                    resizableImage(cgImage, scale: cgImageScale)
                        .onTapGesture {
                            isDetailProfileImagePresented = true
                        }
                        .contextMenu {
                            menuItems(imageData: imageData.data)
                        }
                    #else
                    Menu {
                        menuItems(imageData: imageData.data)
                    } label: {
                        resizableImage(cgImage, scale: cgImageScale)
                    } primaryAction: {
                        isDetailProfileImagePresented = true
                    }
                    .menuStyle(.borderlessButton)
                    #endif
                }
                .onDrag {
                    let itemProvider = NSItemProvider()
                    itemProvider.registerDataRepresentation(forTypeIdentifier: utType.identifier, visibility: .all) { loadHandler in
                        loadHandler(imageData.data, nil)
                        return nil
                    }
                    itemProvider.suggestedName = filename

                    return itemProvider
                } preview: {
                    Image(decorative: cgImage, scale: cgImageScale ?? 1.0)
                }
                .sheet(isPresented: $isDetailProfileImagePresented) {
                    #if os(macOS)
                    DetailImageView(imageData: imageData.data, image: cgImage, imageScale: cgImageScale ?? 1.0, filename: filename)
                        .frame(minWidth: 120, idealWidth: 410, minHeight: 120, idealHeight: 410)
                    #else
                    NavigationView {
                        DetailImageView(imageData: imageData.data, image: cgImage, imageScale: cgImageScale ?? 1.0, filename: filename)
                    }
                    #endif
                }
            } else {
                resizableImage(cgImage, scale: cgImageScale)
            }
            #else
            resizableImage(cgImage, scale: cgImageScale)
            #endif
        }
        .onReceive(
            dataAssetsFetchedResultsController.objectWillChange
                .receive(on: RunLoop.main)
        ) { _ in
            Task(priority: .utility) {
                let imageData: ImageData? = await dataAssetsFetchedResultsController.managedObjectContext.perform {
                    dataAssetsFetchedResultsController.fetchedObjects.first?.data.flatMap { data in
                        ImageData(
                            data: data,
                            dataMIMEType: dataAssetsFetchedResultsController.fetchedObjects.first?.dataMIMEType
                        )
                    }
                }

                await updateImage(
                    from: imageData
                )
            }
        }
        .task {
            let imageData: ImageData? = await dataAssetsFetchedResultsController.managedObjectContext.perform {
                dataAssetsFetchedResultsController.fetchedObjects.first?.data.flatMap { data in
                    ImageData(
                        data: data,
                        dataMIMEType: dataAssetsFetchedResultsController.fetchedObjects.first?.dataMIMEType
                    )
                }
            }

            await updateImage(
                from: imageData
            )
        }
    }

    init(url: URL?, isExportable: Bool = false) {
        self.url = url
        self.isExportable = isExportable

        self._dataAssetsFetchedResultsController = State(
            wrappedValue: FetchedResultsController<ManagedUserDataAsset>(
                fetchRequest: {
                    let fetchRequest = ManagedUserDataAsset.fetchRequest()
                    fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ManagedUserDataAsset.creationDate, ascending: false)]
                    fetchRequest.predicate = url.flatMap { NSPredicate(format: "url == %@", $0 as NSURL) } ?? NSPredicate(value: false)
                    fetchRequest.propertiesToFetch = ["data", "dataMIMEType"]
                    fetchRequest.returnsObjectsAsFaults = false
                    fetchRequest.fetchLimit = 1

                    return fetchRequest
                }(),
                managedObjectContext: TweetNestApp.session.persistentContainer.newBackgroundContext()
            )
        )
    }

    @ViewBuilder
    private func resizableImage(_ cgImage: CGImage?, scale: CGFloat?) -> some View {
        if let cgImage = cgImage {
            Image(decorative: cgImage, scale: scale ?? 1.0)
                #if !os(watchOS)
                .interpolation(.high)
                #else
                .interpolation(.medium)
                #endif
                .resizable()
        } else {
            Color.gray
        }
    }

    @ViewBuilder
    private func menuItems(imageData: Data) -> some View {
        Button(
            action: {
                #if canImport(AppKit)
                NSPasteboard.general.setData(imageData, forType: .fileContents)
                #elseif canImport(UIKit) && !os(watchOS)
                UIPasteboard.general.image = UIImage(data: imageData)
                #endif
            },
            label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
        )
    }

    private func updateImage(from imageData: ImageData?) async {
        let cgImageAndImageScale: (cgImage: CGImage, imageScale: CGFloat?)? = {
            guard let imageData = imageData else {
                return nil
            }

            guard let imageSource = CGImageSourceCreateWithData(
                imageData.data as CFData,
                nil
            ) else {
                return nil
            }

            guard let image = CGImageSourceCreateThumbnailAtIndex(
                imageSource,
                0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceShouldCache as String: true,
                    kCGImageSourceShouldCacheImmediately as String: true,
                    kCGImageSourceCreateThumbnailWithTransform as String: true,
                ] as CFDictionary
            ) else {
                return nil
            }

            let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any]

            let imageDPI = [
                imageProperties?[kCGImagePropertyDPIWidth],
                imageProperties?[kCGImagePropertyDPIHeight]
            ]
            .compactMap { ($0 as? NSNumber)?.doubleValue }
            .min()

            return (cgImage: image, imageScale: imageDPI.flatMap { $0 / 72 })
        }()

        await MainActor.run {
            self.imageData = imageData
            self.cgImage = cgImageAndImageScale?.cgImage
            self.cgImageScale = cgImageAndImageScale?.imageScale
        }
    }
}

#if DEBUG
struct UserDataAssetImage_Previews: PreviewProvider {

    static var previews: some View {
        ZStack {
            Rectangle()
            .fill(.black)
            .ignoresSafeArea()
            UserDataAssetImage(url: .init(string: "https://pbs.twimg.com/profile_images/1373878674903113729/JL3SGoch.png"))
            .aspectRatio(contentMode: .fit)
        }
    }
}
#endif
