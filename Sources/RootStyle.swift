#if os(iOS) || os(tvOS)
import UIKit
private typealias View = UIView
private let ViewDidMoveToWindowSelector = #selector(View.didMoveToWindow)
#elseif os(OSX)
import Cocoa
private typealias View = NSView
private let ViewDidMoveToWindowSelector = #selector(View.viewDidMoveToWindow)
#endif

public enum Failure: Error {
    case notOnMainThread
    case alreadyInitialized
    case autoapplyFailed
    case redundantStyles(String)
}

public struct RootStyle {
    private static var isStyleAppliedKey = "isStyleApplied"

    public enum AutoapplyMethod {
        case swizzle
        @available(OSX, unavailable)
        case appearance
    }

    public private(set) static var style: StyleApplicator?

    public static func set(style: StyleApplicator) throws {
        try safeguard()
        self.style = style
    }

    /// Apply the root style to `some` object once. Subsequent calls do nothing.
    public static func apply(to some: AnyObject) {
        if objc_getAssociatedObject(some, &isStyleAppliedKey) == nil {
            objc_setAssociatedObject(some, &isStyleAppliedKey, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            style?.apply(to: some, marker: nil)
        }
    }

    // Apply the root style to every `UIView` automatically once.
    public static func autoapply(style: StyleApplicator, mode: AutoapplyMethod = .swizzle) throws {
        try safeguard()
        self.style = style
        switch mode {
        case .swizzle:
            do {

                try swizzleInstance(View.self, originalSelector: ViewDidMoveToWindowSelector, swizzledSelector: #selector(View.__stylesheet_didMoveToWindow))
                #if os(iOS) || os(tvOS)
                try swizzleInstance(UIViewController.self, originalSelector: #selector(UIViewController.viewDidLoad), swizzledSelector: #selector(UIViewController.__stylesheet_viewDidLoad))
                #endif
            } catch {
                throw Failure.autoapplyFailed
            }
        case .appearance:
            #if os(iOS) || os(tvOS)
            View.appearance().__stylesheet_applyRootStyle()
            #endif
        }
    }

    private static func safeguard() throws {
        if !Thread.isMainThread {
            throw Failure.notOnMainThread
        }
        if style != nil {
            throw Failure.alreadyInitialized
        }
    }
}

private extension View {
    @objc dynamic
    func __stylesheet_didMoveToWindow() {
        __stylesheet_didMoveToWindow()
        RootStyle.apply(to: self)
    }

    // This method should look like a setter to be compatible with `UIAppearance`.
    @objc dynamic
    func __stylesheet_applyRootStyle(_: Any? = nil) {
        RootStyle.apply(to: self)
    }
}

/// Based on http://nshipster.com/method-swizzling/
private func swizzleInstance<T: NSObject>(_ cls: T.Type, originalSelector: Selector, swizzledSelector: Selector) throws {
    guard
        let originalMethod = class_getInstanceMethod(cls, originalSelector),
        let swizzledMethod = class_getInstanceMethod(cls, swizzledSelector)
        else { throw SwizzleError.selectorNotFound }

    let didAddMethod = class_addMethod(cls, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))

    if (didAddMethod) {
        class_replaceMethod(cls, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod))
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
}

private enum SwizzleError: Error {
    case selectorNotFound
}

#if os(iOS) || os(tvOS)
public extension UIView {

    @discardableResult
    public func styled(_ marker: Protocol) -> Self {
        RootStyle.style?.apply(to: self, marker: marker)
        return self
    }

    public convenience init(style marker: Protocol) {
        self.init(frame: .zero)
        RootStyle.style?.apply(to: self, marker: marker)
    }

}

private extension UIViewController {

    @objc dynamic
    func __stylesheet_viewDidLoad() {
        __stylesheet_viewDidLoad()
        RootStyle.apply(to: self)
    }

}
#endif
