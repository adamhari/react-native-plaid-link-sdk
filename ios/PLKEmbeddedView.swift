import LinkKit
import UIKit

internal final class PLKEmbeddedView: UIView {

    // Properties exposed to React Native.

    @objc var iOSPresentationStyle: String = "" {
        didSet {
            createNativeEmbeddedView()
        }
    }

    @objc var token: String = "" {
        didSet {
            createNativeEmbeddedView()
        }
    }

    @objc var onEmbeddedEvent: RCTDirectEventBlock?

    // MARK: Private

    private var linkHandler: Handler?
    private let embeddedEventName: String = "embeddedEventName"

    private func makeHandler() throws -> Handler {
        var config = LinkTokenConfiguration(
            token: token,
            onSuccess: { [weak self] success in
                guard let self = self else { return }

                let plkLinkSuccess = success.toObjC
                var dictionary = RNLinksdk.dictionary(from: plkLinkSuccess) ?? [:]
                dictionary[embeddedEventName] = "onSuccess"
                self.onEmbeddedEvent?(dictionary)
        })

        config.onEvent = { [weak self] event in
            guard let self = self else { return }

            let plkLinkEvent = event.toObjC
            var dictionary = RNLinksdk.dictionary(from: plkLinkEvent) ?? [:]
            dictionary[embeddedEventName] = "onEvent"
            self.onEmbeddedEvent?(dictionary)
        }

        config.onExit = { [weak self] exit in
            guard let self = self else { return }

            let plkLinkExit = exit.toObjC
            var dictionary = RNLinksdk.dictionary(from: plkLinkExit) ?? [:]
            dictionary[embeddedEventName] = "onExit"
            self.onEmbeddedEvent?(dictionary)
        }

        let handlerCreationResult = Plaid.create(config)

        switch handlerCreationResult {
        case .failure(let error):
            throw(error)
        case .success(let handler):
            return handler
        }
    }

    private func makeEmbeddedView(rctViewController: UIViewController, handler: Handler) throws -> UIView {
        self.linkHandler = handler

        let presentationMethod: PresentationMethod

        if iOSPresentationStyle.uppercased() == "FULL_SCREEN" {
            presentationMethod = .custom({ viewController in
                viewController.modalPresentationStyle = .overFullScreen
                viewController.modalTransitionStyle = .coverVertical

                rctViewController.present(viewController, animated: true)
            })
        } else {
            presentationMethod = .viewController(rctViewController)
        }

        let embeddedResult = handler.createEmbeddedView(presentUsing: presentationMethod)

        switch embeddedResult {
        case .failure(let error):
            throw error

        case .success(let embeddedView):
            return embeddedView
        }
    }

    private func createNativeEmbeddedView() {
        guard let rctViewController = RCTPresentedViewController() else { return }
        guard !token.isEmpty, !iOSPresentationStyle.isEmpty, linkHandler == nil else { return }

        do {
            let handler = try makeHandler()
            let embeddedView = try makeEmbeddedView(rctViewController: rctViewController, handler: handler)
            setup(embeddedView: embeddedView)
        } catch {
            let dict: [String: Any] = [
                embeddedEventName: "onExit",
                "error": "\(error)"
            ]

            onEmbeddedEvent?(dict)
        }
    }

    private func setup(embeddedView: UIView) {
        embeddedView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(embeddedView)

        NSLayoutConstraint.activate([
            embeddedView.topAnchor.constraint(equalTo: topAnchor),
            embeddedView.leadingAnchor.constraint(equalTo: leadingAnchor),
            embeddedView.trailingAnchor.constraint(equalTo: trailingAnchor),
            embeddedView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}
