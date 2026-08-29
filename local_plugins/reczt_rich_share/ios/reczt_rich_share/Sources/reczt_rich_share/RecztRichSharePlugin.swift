import Flutter
import UIKit
import LinkPresentation

/// Adds a native iOS Link Presentation share path for Reczt.
///
/// Flutter sends a URL, title, message, and an optional local preview-image
/// path. The image is used only as LPLinkMetadata artwork. The actual shared
/// item is the Reczt URL, so Messages can render a tappable rich-link card
/// instead of receiving a PNG attachment.
public final class RecztRichSharePlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "reczt/rich_share",
            binaryMessenger: registrar.messenger()
        )
        let instance = RecztRichSharePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "shareRichLink" else {
            result(FlutterMethodNotImplemented)
            return
        }

        guard #available(iOS 13.0, *) else {
            result(FlutterError(
                code: "unsupported_ios_version",
                message: "Rich link sharing requires iOS 13 or newer.",
                details: nil
            ))
            return
        }

        guard
            let args = call.arguments as? [String: Any],
            let urlString = args["url"] as? String,
            let url = URL(string: urlString),
            let title = args["title"] as? String,
            let message = args["message"] as? String
        else {
            result(FlutterError(
                code: "invalid_arguments",
                message: "Missing title, message, or URL for rich sharing.",
                details: nil
            ))
            return
        }

        let previewImagePath = args["previewImagePath"] as? String
        share(
            url: url,
            title: title,
            message: message,
            previewImagePath: previewImagePath,
            result: result
        )
    }

    @available(iOS 13.0, *)
    private func share(
        url: URL,
        title: String,
        message: String,
        previewImagePath: String?,
        result: @escaping FlutterResult
    ) {
        DispatchQueue.main.async {
            guard let presenter = Self.topViewController() else {
                result(FlutterError(
                    code: "no_presenter",
                    message: "Could not find a view controller for the iOS share sheet.",
                    details: nil
                ))
                return
            }

            let source = RecztLinkItemSource(
                url: url,
                title: title,
                previewImagePath: previewImagePath
            )

            // The source supplies the tappable URL + LPLinkMetadata.
            // Keeping the message as a second activity item preserves the
            // friendly text users already get with QuickShare.
            let activityViewController = UIActivityViewController(
                activityItems: [source, message],
                applicationActivities: nil
            )

            // Required for a stable share sheet presentation on iPad.
            if let popover = activityViewController.popoverPresentationController {
                popover.sourceView = presenter.view
                popover.sourceRect = CGRect(
                    x: presenter.view.bounds.midX,
                    y: presenter.view.bounds.midY,
                    width: 1,
                    height: 1
                )
                popover.permittedArrowDirections = []
            }

            presenter.present(activityViewController, animated: true) {
                result(true)
            }
        }
    }

    private static func topViewController(
        from base: UIViewController? = keyWindowRootViewController()
    ) -> UIViewController? {
        if let navigation = base as? UINavigationController {
            return topViewController(from: navigation.visibleViewController)
        }
        if let tab = base as? UITabBarController,
           let selected = tab.selectedViewController {
            return topViewController(from: selected)
        }
        if let presented = base?.presentedViewController {
            return topViewController(from: presented)
        }
        return base
    }

    private static func keyWindowRootViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }

        for scene in scenes {
            if let window = scene.windows.first(where: { $0.isKeyWindow }) {
                return window.rootViewController
            }
        }

        return scenes
            .flatMap { $0.windows }
            .first(where: { !$0.isHidden })?
            .rootViewController
    }
}

@available(iOS 13.0, *)
private final class RecztLinkItemSource: NSObject, UIActivityItemSource {
    private let url: URL
    private let title: String
    private let previewImage: UIImage?

    init(url: URL, title: String, previewImagePath: String?) {
        self.url = url
        self.title = title
        if let previewImagePath, !previewImagePath.isEmpty {
            self.previewImage = UIImage(contentsOfFile: previewImagePath)
        } else {
            self.previewImage = nil
        }
        super.init()
    }

    func activityViewControllerPlaceholderItem(
        _ activityViewController: UIActivityViewController
    ) -> Any {
        return url
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        return url
    }

    func activityViewControllerLinkMetadata(
        _ activityViewController: UIActivityViewController
    ) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.originalURL = url
        metadata.url = url
        metadata.title = title

        if let previewImage {
            metadata.imageProvider = NSItemProvider(object: previewImage)
        }

        return metadata
    }
}
