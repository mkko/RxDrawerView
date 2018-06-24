//
//  DrawerView.swift
//  DrawerView
//
//  Created by Mikko Välimäki on 28/10/2017.
//  Copyright © 2017 Mikko Välimäki. All rights reserved.
//

import UIKit

let LOGGING = false

let dateFormat = "yyyy-MM-dd hh:mm:ss.SSS"
let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = dateFormat
    formatter.locale = Locale.current
    formatter.timeZone = TimeZone.current
    return formatter
}()

@objc public enum DrawerPosition: Int {
    case closed = 0
    case collapsed = 1
    case partiallyOpen = 2
    case open = 3
}

extension DrawerPosition: CustomStringConvertible {

    public var description: String {
        switch self {
        case .closed: return "closed"
        case .collapsed: return "collapsed"
        case .partiallyOpen: return "partiallyOpen"
        case .open: return "open"
        }
    }
}

fileprivate extension DrawerPosition {

    static let activePositions: [DrawerPosition] = [
        .open,
        .partiallyOpen,
        .collapsed
    ]

    static let openPositions: [DrawerPosition] = [
        .open,
        .partiallyOpen
    ]

    var visibleName: String {
        switch self {
        case .closed: return "hidden"
        case .open: return "open"
        case .partiallyOpen: return "partiallyOpen"
        case .collapsed: return "collapsed"
        }
    }
}

let kVelocityTreshold: CGFloat = 0

// Vertical leeway is used to cover the bottom with springy animations.
let kVerticalLeeway: CGFloat = 10.0

let kDefaultCornerRadius: CGFloat = 9.0

let kDefaultShadowRadius: CGFloat = 1.0

let kDefaultShadowOpacity: Float = 0.05

let kDefaultBackgroundEffect = UIBlurEffect(style: .extraLight)

let kDefaultBorderColor = UIColor(white: 0.2, alpha: 0.2)


@objc public protocol DrawerViewDelegate {

    @objc optional func drawer(_ drawerView: DrawerView, willTransitionFrom fromPosition: DrawerPosition, to toPosition: DrawerPosition)

    @objc optional func drawer(_ drawerView: DrawerView, didTransitionTo position: DrawerPosition)

    @objc optional func drawerDidMove(_ drawerView: DrawerView, drawerOffset: CGFloat)

    @objc optional func drawerWillBeginDragging(_ drawerView: DrawerView)

    @objc optional func drawerWillEndDragging(_ drawerView: DrawerView)
}

private struct ChildScrollViewInfo {
    var scrollView: UIScrollView
    var scrollWasEnabled: Bool
    var gestureRecognizers: [UIGestureRecognizer] = []
}

@IBDesignable public class DrawerView: UIView {

    // MARK: - Private properties

    private var panGesture: UIPanGestureRecognizer!

    private var overlayTapRecognizer: UITapGestureRecognizer!

    private var panOrigin: CGFloat = 0.0

    private var horizontalPanOnly: Bool = true

    private var startedDragging: Bool = false

    private var animator: UIViewPropertyAnimator? = nil

    private var currentPosition: DrawerPosition = .collapsed

    private var topConstraint: NSLayoutConstraint? = nil

    private var heightConstraint: NSLayoutConstraint? = nil

    private var childScrollViews: [ChildScrollViewInfo] = []

    private var overlay: Overlay?

    private let borderView = UIView()

    private let backgroundView = UIVisualEffectView(effect: kDefaultBackgroundEffect)

    // MARK: - Visual properties

    @IBInspectable public var cornerRadius: CGFloat = kDefaultCornerRadius {
        didSet {
            updateVisuals()
        }
    }

    @IBInspectable public var shadowRadius: CGFloat = kDefaultShadowRadius {
        didSet {
            updateVisuals()
        }
    }

    @IBInspectable public var shadowOpacity: Float = kDefaultShadowOpacity {
        didSet {
            updateVisuals()
        }
    }

    public var backgroundEffect: UIVisualEffect? = kDefaultBackgroundEffect {
        didSet {
            updateVisuals()
        }
    }

    public var borderColor: UIColor = kDefaultBorderColor {
        didSet {
            updateVisuals()
        }
    }

    // MARK: - Public properties

    @IBOutlet
    public var delegate: DrawerViewDelegate?

    public var enabled: Bool = true

    public var drawerOffset: CGFloat {
        return convertScrollPositionToOffset(self.topConstraint?.constant ?? 0)
    }

    // IB support, not intended to be used otherwise.
    @IBOutlet
    public var containerView: UIView? {
        willSet {
            // TODO: Instead, check if has been initialized from nib.
            if self.superview != nil {
                abort(reason: "Superview already set, use normal UIView methods to set up the view hierarcy")
            }
        }
        didSet {
            if let containerView = containerView {
                self.attachTo(view: containerView)
            }
        }
    }

    public func attachTo(view: UIView) {

        if self.superview == nil {
            self.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(self)
        } else if self.superview !== view {
            log("Invalid state; superview already set when called attachTo(view:)")
        }

        topConstraint = self.topAnchor.constraint(equalTo: view.topAnchor, constant: self.topMargin)
        heightConstraint = self.heightAnchor.constraint(equalTo: view.heightAnchor, constant: -self.topSpace)
        heightConstraint = self.heightAnchor.constraint(greaterThanOrEqualTo: view.heightAnchor, multiplier: 1, constant: -self.topSpace)
        let bottomConstraint = self.bottomAnchor.constraint(greaterThanOrEqualTo: view.bottomAnchor)

        let constraints = [
            self.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            self.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topConstraint,
            heightConstraint,
            bottomConstraint
        ]

        for constraint in constraints {
            constraint?.isActive = true
        }

        updateVisuals()
    }

    // TODO: Use size classes with the positions.

    public var topMargin: CGFloat = 68.0 {
        didSet {
            self.updateSnapPosition(animated: false)
        }
    }

    public var collapsedHeight: CGFloat = 68.0 {
        didSet {
            self.updateSnapPosition(animated: false)
        }
    }

    public var partiallyOpenHeight: CGFloat = 264.0 {
        didSet {
            self.updateSnapPosition(animated: false)
        }
    }

    public var position: DrawerPosition {
        get {
            return currentPosition
        }
        set {
            self.setPosition(newValue, animated: false)
        }
    }

    public var enabledPositions: [DrawerPosition] = DrawerPosition.activePositions {
        didSet {
            if !enabledPositions.contains(self.position) {
                // Current position is not in the given list, default to the most closed one.
                self.setInitialPosition()
            }
        }
    }

    // MARK: - Initialization

    init() {
        super.init(frame: CGRect())
        self.setup()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setup()
    }

    convenience public init(withView view: UIView) {
        self.init()

        view.frame = self.bounds
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(view)

        for c in [
            view.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            view.heightAnchor.constraint(equalTo: self.heightAnchor),
            view.topAnchor.constraint(equalTo: self.topAnchor)
        ] {
            c.isActive = true
        }
    }

    private func setup() {
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        panGesture.maximumNumberOfTouches = 2
        panGesture.minimumNumberOfTouches = 1
        panGesture.delegate = self
        self.addGestureRecognizer(panGesture)

        self.translatesAutoresizingMaskIntoConstraints = false

        setupBackgroundView()
        setupBorderView()

        updateVisuals()
    }

    func setupBackgroundView() {
        backgroundView.frame = self.bounds
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.clipsToBounds = true

        self.insertSubview(backgroundView, at: 0)

        let backgroundViewConstraints = [
            backgroundView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: kVerticalLeeway),
            backgroundView.topAnchor.constraint(equalTo: self.topAnchor)
        ]

        for constraint in backgroundViewConstraints {
            constraint.isActive = true
        }

        self.backgroundColor = UIColor.clear
    }

    func setupBorderView() {
        borderView.translatesAutoresizingMaskIntoConstraints = false
        borderView.clipsToBounds = true
        borderView.isUserInteractionEnabled = false
        borderView.backgroundColor = UIColor.clear
        borderView.layer.cornerRadius = 10

        self.addSubview(borderView)

        let borderViewConstraints = [
            borderView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: -0.5),
            borderView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: 0.5),
            borderView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: kVerticalLeeway),
            borderView.topAnchor.constraint(equalTo: self.topAnchor, constant: -0.5)
        ]

        for constraint in borderViewConstraints {
            constraint.isActive = true
        }
    }

    // MARK: - View methods

    public override func layoutSubviews() {
        super.layoutSubviews()

        // Update snap position, if not dragging.
        let isAnimating = animator?.isRunning ?? false
        if !isAnimating && !startedDragging {
            // Handle possible layout changes, e.g. rotation.
            self.updateSnapPosition(animated: false)
        }

        // NB: For some reason the subviews of the blur
        // background don't keep up with sudden change.
        for view in self.backgroundView.subviews {
            view.frame.origin.y = 0
        }
    }

    // MARK: - Scroll position methods

    public func setPosition(_ position: DrawerPosition, animated: Bool) {
        guard let superview = self.superview else {
            log("ERROR: Not contained in a view.")
            log("ERROR: Could not evaluate snap position for \(position.visibleName)")
            return
        }

        updateBackgroundVisuals(self.backgroundView)
        // Get the next available position. Closed position is always supported.
        let nextPosition: DrawerPosition
        if position != .closed && !self.enabledPositions.contains(position) {
            nextPosition = position.advance(by: 1, inPositions: self.enabledPositions)
                ?? position.advance(by: -1, inPositions: self.enabledPositions)
                ?? position
        } else {
            nextPosition = position
        }

        // Notify only if position changed.
        let notify = (currentPosition != nextPosition)
        if notify {
            self.delegate?.drawer?(self, willTransitionFrom: currentPosition, to: nextPosition)
        }

        self.currentPosition = nextPosition

        let nextSnapPosition = snapPosition(for: nextPosition, in: superview)
        self.scrollToPosition(nextSnapPosition, animated: animated) {
            if notify {
                self.delegate?.drawer?(self, didTransitionTo: position)
            }
        }
    }

    private func scrollToPosition(_ scrollPosition: CGFloat, animated: Bool, completion: @escaping () -> Void) {
        if animated {
            self.animator?.stopAnimation(true)
            // Create the animator.
            let springParameters = UISpringTimingParameters(dampingRatio: 0.8)
            self.animator = UIViewPropertyAnimator(duration: 0.5, timingParameters: springParameters)
            self.animator?.addAnimations {
                self.setScrollPosition(scrollPosition)
            }
            self.animator?.addCompletion({ _ in
                self.superview?.layoutIfNeeded()
                self.layoutIfNeeded()
                completion()
            })

            // Add extra height to make sure that bottom doesn't show up.
            self.superview?.layoutIfNeeded()

            self.animator?.startAnimation()
        } else {
            self.setScrollPosition(scrollPosition)
        }
    }

    private func updateScrollPosition(whileDraggingAtPoint dragPoint: CGFloat) {
        guard let superview = superview else {
            log("ERROR: Cannot set position, no superview defined")
            return
        }

        let positions = self.enabledPositions
            .compactMap { self.snapPosition(for: $0, in: superview) }
            .sorted()

        let position: CGFloat
        if let lowerBound = positions.first, dragPoint < lowerBound {
            position = lowerBound - damp(value: lowerBound - dragPoint, factor: 50)
        } else if let upperBound = positions.last, dragPoint > upperBound {
            position = upperBound + damp(value: dragPoint - upperBound, factor: 50)
        } else {
            position = dragPoint
        }

        self.setScrollPosition(position)
    }

    private func updateSnapPosition(animated: Bool) {
        guard let superview = superview else {
            log("ERROR: Cannot update snap position, no superview defined")
            return
        }
        let expectedPos = self.snapPosition(for: currentPosition, in: superview)
        if let topConstraint = self.topConstraint, expectedPos != topConstraint.constant {
            self.setPosition(currentPosition, animated: animated)
        }
    }

    private func setScrollPosition(_ scrollPosition: CGFloat) {
        self.topConstraint?.constant = scrollPosition
        self.setOverlayOpacity(forScrollPosition: scrollPosition)
        self.setShadowOpacity(forScrollPosition: scrollPosition)

        let drawerOffset = convertScrollPositionToOffset(scrollPosition)
        self.delegate?.drawerDidMove?(self, drawerOffset: drawerOffset)

        self.superview?.layoutIfNeeded()
    }

    private func setInitialPosition() {
        self.position = self.enabledPositionsSorted.last ?? .collapsed
    }

    // MARK: - Pan handling

    @objc private func handlePan(_ sender: UIPanGestureRecognizer) {
        switch sender.state {
        case .began:
            self.delegate?.drawerWillBeginDragging?(self)

            self.animator?.stopAnimation(true)

            // Get the actual position of the view.
            let frame = self.layer.presentation()?.frame ?? self.frame
            self.panOrigin = frame.origin.y
            self.horizontalPanOnly = true

            updateScrollPosition(whileDraggingAtPoint: panOrigin)

            break
        case .changed:

            let translation = sender.translation(in: self)
            let velocity = sender.velocity(in: self)
            if velocity.y == 0 {
                break
            }

            // If scrolling upwards a scroll view, ignore the events.
            if self.childScrollViews.count > 0 {

                // Detect if directional lock should be respected.
                let panGestures = self.childScrollViews
                    .filter { $0.scrollWasEnabled }
                    .flatMap { $0.gestureRecognizers }
                    .compactMap { g -> UIPanGestureRecognizer? in
                        g as? UIPanGestureRecognizer
                }

                let simultaneousPanGestures = panGestures.filter { $0.isActive() }

                let panningHorizontally = simultaneousPanGestures.count > 0
                    && simultaneousPanGestures
                        .map { $0.translation(in: self) }
                        .all { p in p.x != 0 && p.y == 0 }

                if !panningHorizontally {
                    self.horizontalPanOnly = false
                }

                if self.horizontalPanOnly {
                    log("Vertical pan cancelled due to direction lock")
                    break
                }

                let activeScrollViews = simultaneousPanGestures
                    .compactMap { $0.view as? UIScrollView }

                let childReachedTheTop = activeScrollViews.contains { $0.contentOffset.y <= 0 }
                let isFullyOpen = self.enabledPositionsSorted.last == self.position
                let childScrollEnabled = activeScrollViews.contains { $0.isScrollEnabled }

                let scrollingToBottom = velocity.y < 0

                let shouldScrollChildView: Bool
                if !childScrollEnabled {
                    shouldScrollChildView = false
                } else if !childReachedTheTop && !scrollingToBottom {
                    shouldScrollChildView = true
                } else if childReachedTheTop && !scrollingToBottom {
                    shouldScrollChildView = false
                } else if !isFullyOpen {
                    shouldScrollChildView = false
                } else {
                    shouldScrollChildView = true
                }

                // Disable child view scrolling
                if !shouldScrollChildView && childScrollEnabled {

                    startedDragging = true

                    sender.setTranslation(CGPoint.zero, in: self)

                    // Scrolling downwards and content was consumed, so disable
                    // child scrolling and catch up with the offset.
                    let frame = self.layer.presentation()?.frame ?? self.frame
                    let minContentOffset = activeScrollViews.map { $0.contentOffset.y }.min() ?? 0

                    if minContentOffset < 0 {
                        self.panOrigin = frame.origin.y - minContentOffset
                    } else {
                        self.panOrigin = frame.origin.y
                    }

                    // Also animate to the proper scroll position.
                    log("Animating to target position...")

                    self.animator?.stopAnimation(true)
                    self.animator = UIViewPropertyAnimator.runningPropertyAnimator(
                        withDuration: 0.2,
                        delay: 0.0,
                        options: [.allowUserInteraction, .beginFromCurrentState],
                        animations: {
                            // Disabling the scroll removes negative content offset
                            // in the scroll view, so make it animate here.
                            log("Disabled child scrolling")
                            activeScrollViews.forEach { $0.isScrollEnabled = false }
                            let pos = self.panOrigin
                            self.updateScrollPosition(whileDraggingAtPoint: pos)
                    }, completion: nil)
                } else if !shouldScrollChildView {
                    // Scroll only if we're not scrolling the subviews.
                    startedDragging = true
                    let pos = panOrigin + translation.y
                    updateScrollPosition(whileDraggingAtPoint: pos)
                }
            } else {
                startedDragging = true
                let pos = panOrigin + translation.y
                updateScrollPosition(whileDraggingAtPoint: pos)
            }

        case.failed:
            log("ERROR: UIPanGestureRecognizer failed")
            fallthrough
        case .ended:
            let velocity = sender.velocity(in: self)
            log("Ending with vertical velocity \(velocity.y)")

            let activeScrollViews = self.childScrollViews.filter { sv in
                sv.scrollView.isScrollEnabled &&
                    sv.scrollView.gestureRecognizers?.contains { $0.isActive() } ?? false
            }

            if activeScrollViews.contains(where: { $0.scrollView.contentOffset.y > 0 }) {
                // Let it scroll.
                log("Let child view scroll.")
            } else if startedDragging {
                self.delegate?.drawerWillEndDragging?(self)

                // Check velocity and snap position separately:
                // 1) A treshold for velocity that makes drawer slide to the next state
                // 2) A prediction that estimates the next position based on target offset.
                // If 2 doesn't evaluate to the current position, use that.
                let targetOffset = self.frame.origin.y + velocity.y / 100
                let targetPosition = positionFor(offset: targetOffset)

                // The positions are reversed, reverse the sign.
                let advancement = velocity.y > 0 ? -1 : 1

                let nextPosition: DrawerPosition
                if targetPosition == self.position && abs(velocity.y) > kVelocityTreshold,
                    let advanced = targetPosition.advance(by: advancement, inPositions: self.enabledPositionsSorted) {
                    nextPosition = advanced
                } else {
                    nextPosition = targetPosition
                }
                self.setPosition(nextPosition, animated: true)
            }

            self.childScrollViews.forEach { $0.scrollView.isScrollEnabled = $0.scrollWasEnabled }
            self.childScrollViews = []

            startedDragging = false

        default:
            break
        }
    }

    @objc private func onTapOverlay(_ sender: UITapGestureRecognizer) {
        if sender.state == .ended {

            if let prevPosition = self.position.advance(by: -1, inPositions: self.enabledPositionsSorted) {

                self.delegate?.drawer?(self, willTransitionFrom: currentPosition, to: prevPosition)

                self.setPosition(prevPosition, animated: true)

                self.delegate?.drawer?(self, didTransitionTo: prevPosition)
            }
        }
    }

    // MARK: - Dynamically evaluated properties

    private func snapPositions(for positions: [DrawerPosition], in superview: UIView) -> [(position: DrawerPosition, snapPosition: CGFloat)]  {
        return positions
            // Group the info on position together. For the sake of
            // robustness, hide the ones without snap position.
            .map { p in (
                position: p,
                snapPosition: self.snapPosition(for: p, in: superview)
                )
        }
    }

    private func snapPosition(for position: DrawerPosition, in superview: UIView) -> CGFloat {
        switch position {
        case .open:
            return self.topMargin
        case .partiallyOpen:
            return superview.bounds.height - self.partiallyOpenHeight
        case .collapsed:
            return superview.bounds.height - self.collapsedHeight
        case .closed:
            return superview.bounds.height
        }
    }

    private func opacityFactor(for position: DrawerPosition) -> CGFloat {
        switch position {
        case .open:
            return 1
        case .partiallyOpen:
            return 0
        case .collapsed:
            return 0
        case .closed:
            return 0
        }
    }

    private func shadowOpacityFactor(for position: DrawerPosition) -> Float {
        switch position {
        case .open:
            return self.shadowOpacity
        case .partiallyOpen:
            return self.shadowOpacity
        case .collapsed:
            return self.shadowOpacity
        case .closed:
            return 0
        }
    }

    private func positionFor(offset: CGFloat) -> DrawerPosition {
        guard let superview = superview else {
            return DrawerPosition.collapsed
        }
        let distances = self.enabledPositions
            .compactMap { pos in (pos: pos, y: snapPosition(for: pos, in: superview)) }
            .sorted { (p1, p2) -> Bool in
                return abs(p1.y - offset) < abs(p2.y - offset)
        }

        return distances.first.map { $0.pos } ?? DrawerPosition.collapsed
    }

    // MARK: - Visuals handling

    private func updateVisuals() {
        updateLayerVisuals(self.layer)
        updateBorderVisuals(self.borderView)
        updateOverlayVisuals(self.overlay)
        updateBackgroundVisuals(self.backgroundView)
        heightConstraint?.constant = -self.topSpace

        self.setNeedsDisplay()
    }

    private func updateLayerVisuals(_ layer: CALayer) {
        layer.shadowRadius = shadowRadius
        layer.shadowOpacity = shadowOpacity
        layer.cornerRadius = self.cornerRadius
    }

    private func updateBorderVisuals(_ borderView: UIView) {
        borderView.layer.cornerRadius = self.cornerRadius
        borderView.layer.borderColor = self.borderColor.cgColor
        borderView.layer.borderWidth = 0.5
    }

    private func updateOverlayVisuals(_ overlay: Overlay?) {
        overlay?.backgroundColor = UIColor.black
        overlay?.cutCornerSize = self.cornerRadius
    }

    private func updateBackgroundVisuals(_ backgroundView: UIVisualEffectView) {

        backgroundView.effect = self.backgroundEffect
        if #available(iOS 11.0, *) {
            backgroundView.layer.cornerRadius = self.cornerRadius
            backgroundView.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
        } else {
            // Fallback on earlier versions
            let mask: CAShapeLayer = {
                let m = CAShapeLayer()
                let frame = backgroundView.bounds.insetBy(top: 0, bottom: -kVerticalLeeway, left: 0, right: 0)
                let path = UIBezierPath(roundedRect: frame, byRoundingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: self.cornerRadius, height: self.cornerRadius))
                m.path = path.cgPath
                return m
            }()
            backgroundView.layer.mask = mask
        }
    }

    private func createOverlay() -> Overlay? {
        guard let superview = self.superview else {
            log("ERROR: Could not create overlay.")
            return nil
        }

        let overlay = Overlay(frame: superview.bounds)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.alpha = 0
        overlayTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(onTapOverlay))
        overlay.addGestureRecognizer(overlayTapRecognizer)

        superview.insertSubview(overlay, belowSubview: self)

        let constraints = [
            overlay.leadingAnchor.constraint(equalTo: superview.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: superview.trailingAnchor),
            overlay.heightAnchor.constraint(equalTo: superview.heightAnchor),
            overlay.bottomAnchor.constraint(equalTo: self.topAnchor)
        ]

        for constraint in constraints {
            constraint.isActive = true
        }

        updateOverlayVisuals(overlay)

        return overlay
    }

    private func setOverlayOpacity(forScrollPosition position: CGFloat) {
        guard let superview = self.superview else {
            log("ERROR: Could not set up overlay.")
            return
        }

        let values = snapPositions(for: enabledPositions + [.closed], in: superview)
            .map {(
                position: $0.snapPosition,
                value: self.opacityFactor(for: $0.position)
                )}

        let opacityFactor = interpolate(
            values: values,
            position: position)

        let maxOpacity: CGFloat = 0.5

        self.overlay = self.overlay ?? createOverlay()
        self.overlay?.alpha = opacityFactor * maxOpacity
    }

    private func setShadowOpacity(forScrollPosition position: CGFloat) {
        guard let superview = self.superview else {
            log("ERROR: Could not set up shadow.")
            return
        }

        let values = snapPositions(for: enabledPositions + [.closed], in: superview)
            .map {(
                position: $0.snapPosition,
                value: CGFloat(self.shadowOpacityFactor(for: $0.position))
                )}

        let shadowOpacity = interpolate(
            values: values,
            position: position)

        self.layer.shadowOpacity = Float(shadowOpacity)
    }

    // MARK: - Helpers

    private var topSpace: CGFloat {
        // Use only the open positions for determining the top space.
        let topPosition = DrawerPosition.openPositions
            .sorted(by: compareSnapPositions)
            .reversed()
            .first(where: self.enabledPositions.contains)
            ?? .open

        return superview.map { self.snapPosition(for: topPosition, in: $0) } ?? 0
    }

    private var enabledPositionsSorted: [DrawerPosition] {
        return self.enabledPositions.sorted(by: compareSnapPositions)
    }

    private func compareSnapPositions(first: DrawerPosition, second: DrawerPosition) -> Bool {
        if let superview = superview {
            return snapPosition(for: first, in: superview) > snapPosition(for: second, in: superview)
        } else {
            // Fall back to comparison between the enumerations.
            return first.rawValue > second.rawValue
        }
    }

    private func convertScrollPositionToOffset(_ position: CGFloat) -> CGFloat {
        guard let superview = self.superview else {
            return 0
        }

        return superview.bounds.height - position
    }

    private func damp(value: CGFloat, factor: CGFloat) -> CGFloat {
        return factor * (log10(value + factor/log(10)) - log10(factor/log(10)))
    }
}

extension DrawerView: UIGestureRecognizerDelegate {

    override public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === panGesture || gestureRecognizer === overlayTapRecognizer {
            return enabled
        }
        return true
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if let sv = otherGestureRecognizer.view as? UIScrollView {

            let gestureRecognizers: [UIGestureRecognizer]
            if let index = self.childScrollViews.index(where: { $0.scrollView === sv }) {
                let scrollInfo = self.childScrollViews[index]
                self.childScrollViews.remove(at: index)
                gestureRecognizers = scrollInfo.gestureRecognizers + [otherGestureRecognizer]
            } else {
                gestureRecognizers = []
            }

            self.childScrollViews.append(ChildScrollViewInfo(
                scrollView: sv,
                scrollWasEnabled: sv.isScrollEnabled,
                gestureRecognizers: gestureRecognizers))
        }
        return true
    }
}

fileprivate extension CGRect {

    func insetBy(top: CGFloat = 0, bottom: CGFloat = 0, left: CGFloat = 0, right: CGFloat = 0) -> CGRect {
        return CGRect(
            x: self.origin.x + left,
            y: self.origin.y + top,
            width: self.size.width - left - right,
            height: self.size.height - top - bottom)
    }
}

fileprivate extension DrawerPosition {

    func advance(by: Int, inPositions positions: [DrawerPosition]) -> DrawerPosition? {
        guard !positions.isEmpty else {
            return nil
        }

        let index = (positions.index(of: self) ?? 0)
        let nextIndex = index + by
        return positions.indices.contains(nextIndex) ? positions[nextIndex] : nil
    }
}

fileprivate extension Collection {

    func all(_ predicate: (Element) throws -> Bool) rethrows -> Bool {
        return try !self.contains(where: { try !predicate($0) })
    }
}

fileprivate extension UIGestureRecognizer {

    func isActive() -> Bool {
        return self.isEnabled && (self.state == .changed || self.state == .began)
    }
}

#if !swift(>=4.2)
extension Array {
    // Backwards support for compactMap.
    public func compactMap<ElementOfResult>(_ transform: (Element) throws -> ElementOfResult?) rethrows -> [ElementOfResult] {
        return try self.flatMap(transform)
    }
}
#endif


func abort(reason: String) -> Never  {
    NSLog("DrawerView: \(reason)")
    abort()
}

func log(_ message: String) {
    if LOGGING {
        print("\(dateFormatter.string(from: Date())): \(message)")
    }
}

