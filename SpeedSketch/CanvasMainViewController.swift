/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The primary view controller.
*/

import UIKit

class CanvasMainViewController: UIViewController {

    var cgView: StrokeCGView!
    @IBOutlet var leftRingControl: RingControl!
    @IBOutlet var leftRingControlHeight: NSLayoutConstraint!
    @IBOutlet var leftRingControlWidth: NSLayoutConstraint!
    @IBOutlet var leftRingControlLeading: NSLayoutConstraint!
    @IBOutlet var leftRingControlTop: NSLayoutConstraint!

    var fingerStrokeRecognizer: StrokeGestureRecognizer!
    var pencilStrokeRecognizer: StrokeGestureRecognizer!

    @IBOutlet var pencilButton: UIButton!
    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet var separatorView: UIView!

    var strokeCollection = StrokeCollection()
    var canvasContainerView: CanvasContainerView!

    /// Prepare the drawing canvas.
    /// - Tag: CanvasMainViewController-viewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        let screenBounds = UIScreen.main.bounds
        let maxScreenDimension = max(screenBounds.width, screenBounds.height)

        let cgView = StrokeCGView(frame: CGRect(origin: .zero, size: CGSize(width: maxScreenDimension, height: maxScreenDimension)))
        cgView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.cgView = cgView
        
        let canvasContainerView = CanvasContainerView(canvasSize: cgView.frame.size)
        canvasContainerView.documentView = cgView
        self.canvasContainerView = canvasContainerView
        scrollView.contentSize = canvasContainerView.frame.size
        scrollView.contentOffset = CGPoint(x: (canvasContainerView.frame.width - scrollView.bounds.width) / 2.0,
                                           y: (canvasContainerView.frame.height - scrollView.bounds.height) / 2.0)
        scrollView.addSubview(canvasContainerView)
        scrollView.backgroundColor = canvasContainerView.backgroundColor
        scrollView.maximumZoomScale = 3.0
        scrollView.minimumZoomScale = 0.5
        scrollView.panGestureRecognizer.allowedTouchTypes = [UITouch.TouchType.direct.rawValue as NSNumber]
        scrollView.pinchGestureRecognizer?.allowedTouchTypes = [UITouch.TouchType.direct.rawValue as NSNumber]
        // We put our UI elements on top of the scroll view, so we don't want any of the
        // delay or cancel machinery in place.
        scrollView.delaysContentTouches = false

        self.fingerStrokeRecognizer = setupStrokeGestureRecognizer(isForPencil: false)
        self.pencilStrokeRecognizer = setupStrokeGestureRecognizer(isForPencil: true)

        if #available(iOS 12.1, *) {
            let pencilInteraction = UIPencilInteraction()
            pencilInteraction.delegate = self
            view.addInteraction(pencilInteraction)
        }

        setupDrawingTools()
        setupPencilUI()
        // color picker
        configureStackViews()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scrollView.flashScrollIndicators()
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }

    func configureStackViews() {
        bottomColorButton.layer.cornerRadius = 16
        colorPickerBackgroundView.layer.cornerRadius = 22
        colorPickerBackgroundView.layer.shadowColor = UIColor.gray.cgColor
        colorPickerBackgroundView.layer.shadowOpacity = 0.8
        colorPickerBackgroundView.layer.shadowOffset = .zero
        colorPickerStackView.subviews.forEach { $0.layer.cornerRadius = 16 }
    }
    
    /// A helper method that creates stroke gesture recognizers.
    /// - Tag: setupStrokeGestureRecognizer
    func setupStrokeGestureRecognizer(isForPencil: Bool) -> StrokeGestureRecognizer {
        let recognizer = StrokeGestureRecognizer(target: self, action: #selector(strokeUpdated(_:)))
        recognizer.delegate = self
        recognizer.cancelsTouchesInView = false
        scrollView.addGestureRecognizer(recognizer)
        recognizer.coordinateSpaceView = cgView
        recognizer.isForPencil = isForPencil
        return recognizer
    }

    func setupDrawingTools() {
        let ringDiameter = CGFloat(74.0)
        let ringImageInset = CGFloat(14.0)
        let borderWidth = CGFloat(1.0)
        let ringOutset = ringDiameter / 2.0 - (floor(sqrt((ringDiameter * ringDiameter) / 8.0) - borderWidth))

        leftRingControlHeight.constant = ringDiameter
        leftRingControlWidth.constant = ringDiameter
        leftRingControlTop.constant = -ringDiameter + (ringOutset * 2)
        leftRingControlLeading.constant = -ringOutset

        leftRingControl.setupRings(itemCount: StrokeViewDisplayOptions.allCases.count)
        leftRingControl.setupInitialSelectionState()

        for (index, ringView) in leftRingControl.ringViews.enumerated() {
            let option = StrokeViewDisplayOptions.allCases[index]
            // sets the input mode here. when actionClosure called we set the display options here
            ringView.actionClosure = { self.cgView.displayOptions = option }
            let imageView = UIImageView(frame: ringView.bounds.insetBy(dx: ringImageInset, dy: ringImageInset))
            imageView.image = UIImage(named: option.description)
            imageView.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
            ringView.addSubview(imageView)
        }
    }
    
    func receivedAllUpdatesForStroke(_ stroke: Stroke) {
        cgView.setNeedsDisplay(for: stroke)
        stroke.clearUpdateInfo()
    }

    @IBAction func clearButtonAction(_ sender: AnyObject) {
        self.strokeCollection = StrokeCollection()
        cgView.strokeCollection = self.strokeCollection
    }

    /// Handles the gesture for `StrokeGestureRecognizer`.
    /// This is the drawing mechanism
    /// - Tag: strokeUpdate
    @objc
    func strokeUpdated(_ strokeGesture: StrokeGestureRecognizer) {
        
        if strokeGesture === pencilStrokeRecognizer {
            lastSeenPencilInteraction = Date()
        }
        
        var stroke: Stroke?
        if strokeGesture.state != .cancelled {
            stroke = strokeGesture.stroke
            if strokeGesture.state == .began ||
               (strokeGesture.state == .ended && strokeCollection.activeStroke == nil) {
                strokeCollection.activeStroke = stroke
                leftRingControl.cancelInteraction()
            }
        } else {
            strokeCollection.activeStroke = nil
        }
        
        if let stroke = stroke {
            if strokeGesture.state == .ended {
                if strokeGesture === pencilStrokeRecognizer {
                    // Make sure we get the final stroke update if needed.
                    stroke.receivedAllNeededUpdatesBlock = { [weak self] in
                        self?.receivedAllUpdatesForStroke(stroke)
                    }
                }
               strokeCollection.takeActiveStroke()
            }
        }

        cgView.strokeCollection = strokeCollection
    }

    // MARK: Pencil Recognition and UI Adjustments
    /*
         Since usage of the Apple Pencil can be very temporary, the best way to
         actually check for it being in use is to remember the last interaction.
         Also make sure to provide an escape hatch if you modify your UI for
         times when the pencil is in use vs. not.
     */

    // Timeout the pencil mode if no pencil has been seen for 5 minutes and the app is brought back in foreground.
    let pencilResetInterval = TimeInterval(60.0 * 5)

    var lastSeenPencilInteraction: Date? {
        didSet {
            if lastSeenPencilInteraction != nil && !pencilMode {
                pencilMode = true
            }
        }
    }

    func shouldTimeoutPencilMode() -> Bool {
        guard let lastSeenPencilInteraction = self.lastSeenPencilInteraction else { return true }
        return abs(lastSeenPencilInteraction.timeIntervalSinceNow) > self.pencilResetInterval
    }
    
    private func setupPencilUI() {
        self.pencilMode = false

        self.willEnterForegroundNotification = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: UIApplication.shared,
            queue: nil) { [unowned self](_) in
                if self.pencilMode && self.shouldTimeoutPencilMode() {
                    self.stopPencilButtonAction(nil)
                }
        }
    }

    var willEnterForegroundNotification: NSObjectProtocol?

    /// Toggles pencil mode for the app.
    /// - Tag: pencilMode
    var pencilMode = false {
        didSet {
            if pencilMode {
                scrollView.panGestureRecognizer.minimumNumberOfTouches = 1
                pencilButton.isHidden = false
                if let view = fingerStrokeRecognizer.view {
                    view.removeGestureRecognizer(fingerStrokeRecognizer)
                }
            } else {
                scrollView.panGestureRecognizer.minimumNumberOfTouches = 2
                pencilButton.isHidden = true
                if fingerStrokeRecognizer.view == nil {
                    scrollView.addGestureRecognizer(fingerStrokeRecognizer)
                }
            }
        }
    }
    
    @IBAction func stopPencilButtonAction(_ sender: AnyObject?) {
        lastSeenPencilInteraction = nil
        pencilMode = false
    }

    
    // MARK: - Color Picker Controls

    @IBOutlet var colorPickerStackView: UIStackView!
    @IBOutlet var colorPickerBackgroundView: UIView!
    
    @IBAction func changeColor(sender: AnyObject) {
        guard let button = sender as? UIButton else {
            return
        }
        switch button.tag {
        case 0:
            if !colorPickerStackView.isHidden {
                drawingColor = drawColor.blue
            }
        case 1:
            drawingColor = drawColor.red
          
        case 2:
            drawingColor = drawColor.orange
        case 3:
            drawingColor = drawColor.green
        case 4:
            drawingColor = drawColor.cyan
        case 5:
            drawingColor = drawColor.yellow
        case 6:
            drawingColor = drawColor.magenta
        default:
            print("Unknown color")
            return
        }
        animateColorPicker()
       // changeFillColor()
    }
    
    @IBOutlet var bottomColorButton: UIButton!
    @IBOutlet var colorPickerHeight: NSLayoutConstraint!

    func animateColorPicker() {
        if colorPickerHeight.constant == 288 {
            shrinkColorPicker()
        } else {
            expandColorPicker()
        }
    }

    // TODO: - Refactor these functions
    func expandColorPicker() {
        // to change bottom image color
        let origImage = bottomColorButton.imageView?.image
        let tintedImage = origImage?.withRenderingMode(.alwaysTemplate)

        colorPickerHeight.constant = 288
        colorPickerStackView.subviews.forEach { $0.alpha = 0.01 }

        UIView.animate(
            withDuration: 0.15, delay: 0.1, options: .curveEaseOut,
            animations: {
                self.view.layoutIfNeeded()
            })
        UIView.animate(
            withDuration: 0.3, delay: 0.2, options: .curveEaseOut,
            animations: { [self] in
                colorPickerStackView.subviews.forEach { $0.isHidden = false }
                colorPickerStackView.subviews.forEach { $0.alpha = 1.0 }
                colorPickerStackView.subviews.forEach {
                    switch drawingColor {
                    case .magenta:
                        if $0.tag == 6 {
                            $0.layer.borderWidth = 3
                            $0.layer.borderColor = UIColor.gray.cgColor
                        } else {
                            $0.layer.borderWidth = 0
                        }
                    case .yellow:
                        if $0.tag == 5 {
                            $0.layer.borderWidth = 3
                            $0.layer.borderColor = UIColor.gray.cgColor
                        } else {
                            $0.layer.borderWidth = 0
                        }
                    case .cyan:
                        if $0.tag == 4 {
                            $0.layer.borderWidth = 3
                            $0.layer.borderColor = UIColor.gray.cgColor
                        } else {
                            $0.layer.borderWidth = 0
                        }
                    case .green:
                        if $0.tag == 3 {
                            $0.layer.borderWidth = 3
                            $0.layer.borderColor = UIColor.gray.cgColor
                        } else {
                            $0.layer.borderWidth = 0
                        }
                    case .orange:
                        if $0.tag == 2 {
                            $0.layer.borderWidth = 3
                            $0.layer.borderColor = UIColor.gray.cgColor
                        } else {
                            $0.layer.borderWidth = 0
                        }
                    case .red:
                        if $0.tag == 1 {
                            $0.layer.borderWidth = 3
                            $0.layer.borderColor = UIColor.gray.cgColor
                        } else {
                            $0.layer.borderWidth = 0
                        }
                    case .blue:
                        print("not inside this stackView")
                    }
                }
                colorPickerStackView.isHidden = false
                self.view.layoutIfNeeded()

                bottomColorButton.setImage(tintedImage, for: .normal)
                bottomColorButton.tintColor = drawColor.blue.associatedColor.withAlphaComponent(1.0)
                bottomColorButton.layer.borderWidth = 0

            })
    }

    func shrinkColorPicker() {
        // to change bottom image color
        let origImage = bottomColorButton.imageView?.image
        let tintedImage = origImage?.withRenderingMode(.alwaysTemplate)
        colorPickerHeight.constant = 48
        UIView.animate(
            withDuration: 0.3, delay: 0.1, options: .curveEaseOut,
            animations: {
                self.view.layoutIfNeeded()
            })
        UIView.animate(
            withDuration: 0.2, delay: 0.1, options: .curveEaseOut,
            animations: { [self] in
                colorPickerStackView.subviews.forEach { $0.isHidden = true }
                colorPickerStackView.isHidden = true

                bottomColorButton.setImage(tintedImage, for: .normal)
                bottomColorButton.tintColor = drawingColor.associatedColor.withAlphaComponent(1.0)
                bottomColorButton.layer.borderWidth = 3
                bottomColorButton.layer.cornerRadius = 16
                bottomColorButton.layer.borderColor = UIColor.gray.cgColor

            })
    }
 
    var colorInfo = UIColor()
    private var drawingColor: drawColor = drawColor.blue {
        didSet {
               colorInfo = drawingColor.associatedColor
         }
    }
    
    enum drawColor {
        case magenta
        case yellow
        case cyan
        case green
        case orange
        case red
        case blue

        var associatedColor: UIColor {
            switch self {
            case .magenta: return UIColor(red: 157 / 255, green: 31 / 255, blue: 129 / 255, alpha: 0.250)
            case .yellow: return UIColor(red: 249 / 255, green: 253 / 255, blue: 65 / 255, alpha: 0.250)
            case .cyan: return UIColor(red: 65 / 255, green: 255 / 255, blue: 253 / 255, alpha: 0.250)
            case .green: return UIColor(red: 54 / 255, green: 199 / 255, blue: 73 / 255, alpha: 0.250)
            case .orange: return UIColor(red: 248 / 255, green: 152 / 255, blue: 45 / 255, alpha: 0.250)
            case .red: return UIColor(red: 252 / 255, green: 96 / 255, blue: 90 / 255, alpha: 0.250)
            case .blue: return UIColor(red: 58 / 255, green: 155 / 255, blue: 251 / 255, alpha: 0.250)
            }
        }
    }
    
}

// MARK: - UIGestureRecognizerDelegate

extension CanvasMainViewController: UIGestureRecognizerDelegate {

    // Since our gesture recognizer is beginning immediately, we do the hit test ambiguation here
    // instead of adding failure requirements to the gesture for minimizing the delay
    // to the first action sent and therefore the first lines drawn.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {

        return leftRingControl.hitTest(touch.location(in: leftRingControl), with: nil) == nil
        
    }

    // We want the pencil to recognize simultaniously with all others.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === pencilStrokeRecognizer {
            return otherGestureRecognizer !== fingerStrokeRecognizer
        }

        return false
    }

}

// MARK: - UIScrollViewDelegate

extension CanvasMainViewController: UIScrollViewDelegate {

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.canvasContainerView
    }
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        var desiredScale = self.traitCollection.displayScale
        let existingScale = cgView.contentScaleFactor
        
        if scale >= 2.0 {
            desiredScale *= 2.0
        }
        
        if abs(desiredScale - existingScale) > 0.000_01 {
            cgView.contentScaleFactor = desiredScale
            cgView.setNeedsDisplay()
        }
    }
}

// MARK: - UIPencilInteractionDelegate

@available(iOS 12.1, *)
extension CanvasMainViewController: UIPencilInteractionDelegate {

    /// Handles double taps that the user makes on an Apple Pencil.
    /// - Tag: pencilInteractionDidTap
    func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        if UIPencilInteraction.preferredTapAction == .switchPrevious {
            leftRingControl.switchToPreviousTool()
        }
    }

}
