import UIKit
import AVFoundation
import Vision
import FirebaseMLVision
import IntentsUI
import FirebaseAnalytics

// controlling the pace of the machine vision analysis
var lastAnalysis: TimeInterval = 0
var pace: TimeInterval = 0.33 // in seconds, classification will not repeat faster than this value

// performance tracking
let trackPerformance = false // use "true" for performance logging
var frameCount = 0
let framesPerSample = 10
var startDate = NSDate.timeIntervalSinceReferenceDate


class VisionMLViewController: UIViewController {
    
    /// MARK:- Firebase MLKit properties START
    public var shortcutListItem: ShortcutListItem = ShortcutListItem(
                                                        question: "Text batao",
                                                        messageOnOpen: "Point your camera at the text",
                                                        activityType: "com.starsearth.four.tellTextIntent",
                                                        isUsingFirebase: true,
                                                        isTextDetection: true,
                                                        isLabelDetection: false,
                                                        isYesNo: false,
                                                        textForYesNo: nil
                                                    )
    
    private lazy var vision = Vision.vision()
    private var lastFrame: CMSampleBuffer?
    
    private lazy var previewOverlayView: UIImageView = {
        
        precondition(isViewLoaded)
        let previewOverlayView = UIImageView(frame: .zero)
        previewOverlayView.translatesAutoresizingMaskIntoConstraints = false
        return previewOverlayView
    }()
    
    private lazy var annotationOverlayView: UIView = {
        precondition(isViewLoaded)
        let annotationOverlayView = UIView(frame: .zero)
        annotationOverlayView.translatesAutoresizingMaskIntoConstraints = false
        return annotationOverlayView
    }()
    ///MARK:- Firebase MLKit properties END
  
  @IBOutlet weak var previewView: UIView!
  @IBOutlet weak var stackView: UIStackView!
  @IBOutlet weak var lowerView: UIView!
  
  var previewLayer: AVCaptureVideoPreviewLayer!
  let bubbleLayer = BubbleLayer(string: "")
  
  let queue = DispatchQueue(label: "videoQueue")
  var captureSession = AVCaptureSession()
  var captureDevice: AVCaptureDevice?
  let videoOutput = AVCaptureVideoDataOutput()
  var unknownCounter = 0 // used to track how many unclassified images in a row
  let confidence: Float = 0.7
  
  // MARK: Load the Model
  let targetImageSize = CGSize(width: 227, height: 227) // must match model data input
  
  lazy var classificationRequest: [VNRequest] = {
    do {
      // Load the Custom Vision model.
      // To add a new model, drag it to the Xcode project browser making sure that the "Target Membership" is checked.
      // Then update the following line with the name of your new model.
      let model = try VNCoreMLModel(for: Rupees().model)
      let classificationRequest = VNCoreMLRequest(model: model, completionHandler: self.handleClassification)
      return [ classificationRequest ]
    } catch {
      fatalError("Can't load Vision ML model: \(error)")
    }
  }()
  
  // MARK: Handle image classification results
  
  func handleClassification(request: VNRequest, error: Error?) {
    guard let observations = request.results as? [VNClassificationObservation]
      else { fatalError("unexpected result type from VNCoreMLRequest") }
    
    guard let best = observations.first else {
      fatalError("classification didn't return any results")
    }
    
    // Use results to update user interface (includes basic filtering)
    print("\(best.identifier): \(best.confidence)")
    if best.identifier.starts(with: "Unknown") || best.confidence < confidence {
      if self.unknownCounter < 3 { // a bit of a low-pass filter to avoid flickering
        self.unknownCounter += 1
      } else {
        self.unknownCounter = 0
        DispatchQueue.main.async {
          self.bubbleLayer.string = nil
        }
      }
    } else {
      self.unknownCounter = 0
      DispatchQueue.main.async {
        // Trimming labels because they sometimes have unexpected line endings which show up in the GUI
        self.bubbleLayer.string = best.identifier.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        UIAccessibility.post(notification: UIAccessibility.Notification.announcement, argument: NSLocalizedString(self.bubbleLayer.string!, comment: ""))
      }
    }
  }
  
  // MARK: Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
    previewView.layer.addSublayer(previewLayer)
  }
  
  override func viewDidAppear(_ animated: Bool) {
    //setupIntents()
    addSiriButton(to: stackView)
    bubbleLayer.opacity = 0.0
    bubbleLayer.position.x = self.view.frame.width / 2.0
    bubbleLayer.position.y = lowerView.frame.height / 2
    lowerView.layer.addSublayer(bubbleLayer)
    
    setupCamera()
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    previewLayer.frame = previewView.bounds;
    
    sayThis(string: shortcutListItem.messageOnOpen)
  }
    
    override func viewWillDisappear(_ animated: Bool) {
        let device = AVCaptureDevice.default(for: AVMediaType.video)
        if device?.torchMode == AVCaptureDevice.TorchMode.on {
            turnFlashlightOff()
        }
    }
    
  
  // MARK: Camera handling
  
  func setupCamera() {
    let deviceDiscovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back)
    
    if let device = deviceDiscovery.devices.last {
      captureDevice = device
      beginSession()
    }
  }
  
  func beginSession() {
    do {
      videoOutput.videoSettings = [((kCVPixelBufferPixelFormatTypeKey as NSString) as String) : (NSNumber(value: kCVPixelFormatType_32BGRA) as! UInt32)]
      videoOutput.alwaysDiscardsLateVideoFrames = true
      videoOutput.setSampleBufferDelegate(self, queue: queue)
        
        if captureSession.isRunning {
            return
        }
      
      captureSession.sessionPreset = .hd1920x1080
      captureSession.addOutput(videoOutput)
      
      let input = try AVCaptureDeviceInput(device: captureDevice!)
      captureSession.addInput(input)
      
      captureSession.startRunning()
    } catch {
      print("error connecting to capture device")
    }
  }
}

// MARK: Video Data Delegate

extension VisionMLViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
  
  // called for each frame of video
  func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    
    let brightness = getBrightness(sampleBuffer: sampleBuffer)
    let device = AVCaptureDevice.default(for: AVMediaType.video)
    if brightness < -5.0 && device?.torchMode == AVCaptureDevice.TorchMode.off {
        turnFlashLightOn()
    }
    if shortcutListItem.isUsingFirebase == true {
        callFirebaseMLFunctions(sampleBuffer: sampleBuffer)
        return
    }
    
    let currentDate = NSDate.timeIntervalSinceReferenceDate
    
    // control the pace of the machine vision to protect battery life
    if currentDate - lastAnalysis >= pace {
      lastAnalysis = currentDate
    } else {
      return // don't run the classifier more often than we need
    }
    
    // keep track of performance and log the frame rate
    if trackPerformance {
      frameCount = frameCount + 1
      if frameCount % framesPerSample == 0 {
        let diff = currentDate - startDate
        if (diff > 0) {
          if pace > 0.0 {
            print("WARNING: Frame rate of image classification is being limited by \"pace\" setting. Set to 0.0 for fastest possible rate.")
          }
          print("\(String.localizedStringWithFormat("%0.2f", (diff/Double(framesPerSample))))s per frame (average)")
        }
        startDate = currentDate
      }
    }
    
    // Crop and resize the image data.
    // Note, this uses a Core Image pipeline that could be appended with other pre-processing.
    // If we don't want to do anything custom, we can remove this step and let the Vision framework handle
    // crop and resize as long as we are careful to pass the orientation properly.
    guard let croppedBuffer = croppedSampleBuffer(sampleBuffer, targetSize: targetImageSize) else {
      return
    }
    
    do {
      let classifierRequestHandler = VNImageRequestHandler(cvPixelBuffer: croppedBuffer, options: [:])
      try classifierRequestHandler.perform(classificationRequest)
    } catch {
      print(error)
    }
  }
    
    
}

let context = CIContext()
var rotateTransform: CGAffineTransform?
var scaleTransform: CGAffineTransform?
var cropTransform: CGAffineTransform?
var resultBuffer: CVPixelBuffer?

func croppedSampleBuffer(_ sampleBuffer: CMSampleBuffer, targetSize: CGSize) -> CVPixelBuffer? {
  
  guard let imageBuffer: CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
    fatalError("Can't convert to CVImageBuffer.")
  }
  
  // Only doing these calculations once for efficiency.
  // If the incoming images could change orientation or size during a session, this would need to be reset when that happens.
  if rotateTransform == nil {
    let imageSize = CVImageBufferGetEncodedSize(imageBuffer)
    let rotatedSize = CGSize(width: imageSize.height, height: imageSize.width)
    
    guard targetSize.width < rotatedSize.width, targetSize.height < rotatedSize.height else {
      fatalError("Captured image is smaller than image size for model.")
    }
    
    let shorterSize = (rotatedSize.width < rotatedSize.height) ? rotatedSize.width : rotatedSize.height
    rotateTransform = CGAffineTransform(translationX: imageSize.width / 2.0, y: imageSize.height / 2.0).rotated(by: -CGFloat.pi / 2.0).translatedBy(x: -imageSize.height / 2.0, y: -imageSize.width / 2.0)
    
    let scale = targetSize.width / shorterSize
    scaleTransform = CGAffineTransform(scaleX: scale, y: scale)
    
    // Crop input image to output size
    let xDiff = rotatedSize.width * scale - targetSize.width
    let yDiff = rotatedSize.height * scale - targetSize.height
    cropTransform = CGAffineTransform(translationX: xDiff/2.0, y: yDiff/2.0)
  }
  
  // Convert to CIImage because it is easier to manipulate
  let ciImage = CIImage(cvImageBuffer: imageBuffer)
  let rotated = ciImage.transformed(by: rotateTransform!)
  let scaled = rotated.transformed(by: scaleTransform!)
  let cropped = scaled.transformed(by: cropTransform!)
  
  // Note that the above pipeline could be easily appended with other image manipulations.
  // For example, to change the image contrast. It would be most efficient to handle all of
  // the image manipulation in a single Core Image pipeline because it can be hardware optimized.
  
  // Only need to create this buffer one time and then we can reuse it for every frame
  if resultBuffer == nil {
    let result = CVPixelBufferCreate(kCFAllocatorDefault, Int(targetSize.width), Int(targetSize.height), kCVPixelFormatType_32BGRA, nil, &resultBuffer)
    
    guard result == kCVReturnSuccess else {
      fatalError("Can't allocate pixel buffer.")
    }
  }
  
  // Render the Core Image pipeline to the buffer
  context.render(cropped, to: resultBuffer!)
  
  //  For debugging
  //  let image = imageBufferToUIImage(resultBuffer!)
  //  print(image.size) // set breakpoint to see image being provided to CoreML
  
  return resultBuffer
}

// Only used for debugging.
// Turns an image buffer into a UIImage that is easier to display in the UI or debugger.
func imageBufferToUIImage(_ imageBuffer: CVImageBuffer) -> UIImage {
  
  CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
  
  let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)
  let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
  
  let width = CVPixelBufferGetWidth(imageBuffer)
  let height = CVPixelBufferGetHeight(imageBuffer)
  
  let colorSpace = CGColorSpaceCreateDeviceRGB()
  let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
  
  let context = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)
  
  let quartzImage = context!.makeImage()
  CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
  
  let image = UIImage(cgImage: quartzImage!, scale: 1.0, orientation: .right)
  
  return image
}

extension VisionMLViewController {
    //Firebase MLKit functions
    
    private func removeDetectionAnnotations() {
        for annotationView in annotationOverlayView.subviews {
            annotationView.removeFromSuperview()
        }
    }
    
    private func updatePreviewOverlayView() {
        guard let lastFrame = lastFrame,
            let imageBuffer = CMSampleBufferGetImageBuffer(lastFrame)
            else {
                return
        }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return
        }
        let rotatedImage =
            UIImage(cgImage: cgImage, scale: Constant.originalScale, orientation: .right)
        previewOverlayView.image = rotatedImage
    }
    
    private func normalizedPoint(
        fromVisionPoint point: VisionPoint,
        width: CGFloat,
        height: CGFloat
        ) -> CGPoint {
        let cgPoint = CGPoint(x: CGFloat(point.x.floatValue), y: CGFloat(point.y.floatValue))
        var normalizedPoint = CGPoint(x: cgPoint.x / width, y: cgPoint.y / height)
        normalizedPoint = previewLayer.layerPointConverted(fromCaptureDevicePoint: normalizedPoint)
        return normalizedPoint
    }
    
    private func convertedPoints(
        from points: [NSValue]?,
        width: CGFloat,
        height: CGFloat
        ) -> [NSValue]? {
        return points?.map {
            let cgPointValue = $0.cgPointValue
            let normalizedPoint = CGPoint(x: cgPointValue.x / width, y: cgPointValue.y / height)
            let cgPoint = previewLayer.layerPointConverted(fromCaptureDevicePoint: normalizedPoint)
            let value = NSValue(cgPoint: cgPoint)
            return value
        }
    }
    
    private func callFirebaseMLFunctions(sampleBuffer: CMSampleBuffer) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to get image buffer from sample buffer.")
            return
        }
        lastFrame = sampleBuffer
        let visionImage = VisionImage(buffer: sampleBuffer)
        let metadata = VisionImageMetadata()
        let orientation = UIUtilities.imageOrientation(fromDevicePosition: .back)
        let visionOrientation = UIUtilities.visionImageOrientation(from: orientation)
        metadata.orientation = visionOrientation
        visionImage.metadata = metadata
        let imageWidth = CGFloat(CVPixelBufferGetWidth(imageBuffer))
        let imageHeight = CGFloat(CVPixelBufferGetHeight(imageBuffer))
        if shortcutListItem.isTextDetection {
            recognizeTextOnDevice(in: visionImage, width: imageWidth, height: imageHeight)
        }
        else if shortcutListItem.isLabelDetection {
            recognizeLabelsOnDevice(in: visionImage, width: imageWidth, height: imageHeight)
        }
    }
    
    private func recognizeTextOnDevice(in image: VisionImage, width: CGFloat, height: CGFloat) {
        let textRecognizer = vision.onDeviceTextRecognizer()
        textRecognizer.process(image) { text, error in
            self.removeDetectionAnnotations()
            self.updatePreviewOverlayView()
            guard error == nil, let text = text else {
                print("On-Device text recognizer error: " +
                    "\(error?.localizedDescription ?? Constant.noResultsMessage)")
                return
            }
            // Blocks.
            for block in text.blocks {
                let points = self.convertedPoints(from: block.cornerPoints, width: width, height: height)
                UIUtilities.addShape(
                    withPoints: points,
                    to: self.annotationOverlayView,
                    color: UIColor.purple
                )
                
                // Lines.
                for line in block.lines {
                    let points = self.convertedPoints(from: line.cornerPoints, width: width, height: height)
                    UIUtilities.addShape(
                        withPoints: points,
                        to: self.annotationOverlayView,
                        color: UIColor.orange
                    )
                    
                    // Elements.
                    for element in line.elements {
                        let normalizedRect = CGRect(
                            x: element.frame.origin.x / width,
                            y: element.frame.origin.y / height,
                            width: element.frame.size.width / width,
                            height: element.frame.size.height / height
                        )
                        let convertedRect = self.previewLayer.layerRectConverted(
                            fromMetadataOutputRect: normalizedRect
                        )
                        UIUtilities.addRectangle(
                            convertedRect,
                            to: self.annotationOverlayView,
                            color: UIColor.green
                        )
                        let label = UILabel(frame: convertedRect)
                        label.text = element.text
                        if self.shortcutListItem.isUsingFirebase == true
                            && self.shortcutListItem.isYesNo == true
                            && self.shortcutListItem.textForYesNo == "" {
                            self.bubbleLayer.string = "YES"
                            self.sayThis(string: "YES")
                        }
                        else {
                            self.bubbleLayer.string = element.text
                            self.sayThis(string: element.text)
                        }
                        label.adjustsFontSizeToFitWidth = true
                        self.annotationOverlayView.addSubview(label)
                    }
                }
            }
        }
    }
    
    private func recognizeLabelsOnDevice(in image: VisionImage, width: CGFloat, height: CGFloat) {
        let labelDetector = vision.labelDetector()
        labelDetector.detect(in: image) { features, error in
            guard error == nil, let features = features, !features.isEmpty else {
                return
            }
            
            for label in features {
                let labelText = label.label
                let entityId = label.entityID
                let confidence = label.confidence
                
                self.bubbleLayer.string = labelText
                self.sayThis(string: labelText)
            }
        }
    }
    
    private enum Constant {
        static let alertControllerTitle = "Vision Detectors"
        static let alertControllerMessage = "Select a detector"
        static let cancelActionTitleText = "Cancel"
        static let videoDataOutputQueueLabel = "com.google.firebaseml.visiondetector.VideoDataOutputQueue"
        static let sessionQueueLabel = "com.google.firebaseml.visiondetector.SessionQueue"
        static let noResultsMessage = "No Results"
        static let smallDotRadius: CGFloat = 4.0
        static let originalScale: CGFloat = 1.0
    }
}

extension VisionMLViewController {
    //Siri Shortcuts
    
    //Using acitivites instead of intents as Siri opens app directly for activity. For intents, it shows button to open app, which we do not want s
    func createActivityForQuestion(shortcutListItem: ShortcutListItem) -> NSUserActivity {
        let activity = NSUserActivity(activityType: shortcutListItem.activityType)
        activity.title = shortcutListItem.question
        activity.userInfo = shortcutListItem.dictionary
        activity.suggestedInvocationPhrase = shortcutListItem.question
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        activity.persistentIdentifier = shortcutListItem.activityType
        view.userActivity = activity
        activity.becomeCurrent()
        return activity
    }
    
    // Add an "Add to Siri" button to a view.
    func addSiriButton(to view: UIView) {
        let button = INUIAddVoiceShortcutButton(style: .blackOutline)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isUserInteractionEnabled = true
        //button.shortcut = INShortcut(intent: WhatTextIntent())
        let activity = createActivityForQuestion(shortcutListItem: shortcutListItem)
        button.shortcut = INShortcut(userActivity: activity)
        button.delegate = self
        
        view.addSubview(button)
        view.centerXAnchor.constraint(equalTo: button.centerXAnchor).isActive = true
        view.centerYAnchor.constraint(equalTo: button.centerYAnchor).isActive = true
    }
    
    private func sayThis(string: String) {
        let utterance = AVSpeechUtterance(string: string)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        
        let synth = AVSpeechSynthesizer()
        synth.speak(utterance)
    }
    
    func getBrightness(sampleBuffer: CMSampleBuffer) -> Double {
        let rawMetadata = CMCopyDictionaryOfAttachments(allocator: nil, target: sampleBuffer, attachmentMode: CMAttachmentMode(kCMAttachmentMode_ShouldPropagate))
        let metadata = CFDictionaryCreateMutableCopy(nil, 0, rawMetadata) as NSMutableDictionary
        let exifData = metadata.value(forKey: "{Exif}") as? NSMutableDictionary
        let brightnessValue : Double = exifData?[kCGImagePropertyExifBrightnessValue as String] as! Double
        return brightnessValue
    }
    
    func turnFlashLightOn() {
        guard let device = AVCaptureDevice.default(for: AVMediaType.video) else { return }
        guard device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            
            if (device.torchMode == AVCaptureDevice.TorchMode.off) {
                device.torchMode = AVCaptureDevice.TorchMode.on
            }
            
            device.unlockForConfiguration()
        } catch {
            print(error)
        }
    }
    
    func turnFlashlightOff() {
        guard let device = AVCaptureDevice.default(for: AVMediaType.video) else { return }
        guard device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            
            if (device.torchMode == AVCaptureDevice.TorchMode.on) {
                device.torchMode = AVCaptureDevice.TorchMode.off
            }
            
            device.unlockForConfiguration()
        } catch {
            print(error)
        }
    }
    
    func getDeviceType() -> String {
        switch UIDevice.current.userInterfaceIdiom {
        case .phone:
            return "iPhone"
        case .pad:
            return "iPad"
        case .unspecified:
            return "unspecified"
        default:
            return "unknown"
        }
    }
    
    /*
     Used as sample code to open view controller from siri
    */
    public func openFromSiri() {
        let alert = UIAlertController(title: "Hi There!", message: "Hey there! Glad to see you got this working!", preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}

///MARK:- Add or Edit Button
extension VisionMLViewController: INUIAddVoiceShortcutButtonDelegate {
    func present(_ addVoiceShortcutViewController: INUIAddVoiceShortcutViewController, for addVoiceShortcutButton: INUIAddVoiceShortcutButton) {
        Analytics.logEvent("se4_add_to_siri_tapped", parameters: [
            "os_version": UIDevice.current.systemVersion,
            "device_type": getDeviceType(),
            "mode": "add",
            "question": shortcutListItem.question.prefix(100)
            ])
        
        addVoiceShortcutViewController.delegate = self
        addVoiceShortcutViewController.modalPresentationStyle = .formSheet
        present(addVoiceShortcutViewController, animated: true, completion: nil)
    }
    
    func present(_ editVoiceShortcutViewController: INUIEditVoiceShortcutViewController, for addVoiceShortcutButton: INUIAddVoiceShortcutButton) {
        Analytics.logEvent("se4_add_to_siri_tapped", parameters: [
            "os_version": UIDevice.current.systemVersion,
            "device_type": getDeviceType(),
            "mode": "edit",
            "question": shortcutListItem.question.prefix(100)
            ])
        
        editVoiceShortcutViewController.delegate = self
        editVoiceShortcutViewController.modalPresentationStyle = .formSheet
        present(editVoiceShortcutViewController, animated: true, completion: nil)
    }
    
    
}

extension VisionMLViewController: INUIAddVoiceShortcutViewControllerDelegate {
    func addVoiceShortcutViewController(_ controller: INUIAddVoiceShortcutViewController, didFinishWith voiceShortcut: INVoiceShortcut?, error: Error?) {
        Analytics.logEvent("se4_add_to_siri_completed", parameters: [
            "os_version": UIDevice.current.systemVersion,
            "device_type": getDeviceType(),
            "mode": "add",
            "question": shortcutListItem.question.prefix(100)
            ])
        dismiss(animated: true, completion: nil)
    }
    
    func addVoiceShortcutViewControllerDidCancel(_ controller: INUIAddVoiceShortcutViewController) {
        Analytics.logEvent("se4_add_to_siri_cancelled", parameters: [
            "os_version": UIDevice.current.systemVersion,
            "device_type": getDeviceType(),
            "mode": "add",
            "question": shortcutListItem.question.prefix(100)
            ])
        
        dismiss(animated: true, completion: nil)
    }
    
    
}

extension VisionMLViewController : INUIEditVoiceShortcutViewControllerDelegate {
    func editVoiceShortcutViewController(_ controller: INUIEditVoiceShortcutViewController, didUpdate voiceShortcut: INVoiceShortcut?, error: Error?) {
        Analytics.logEvent("se4_add_to_siri_completed", parameters: [
            "os_version": UIDevice.current.systemVersion,
            "device_type": getDeviceType(),
            "mode": "edit",
            "question": shortcutListItem.question.prefix(100)
            ])
        
        dismiss(animated: true, completion: nil)
    }
    
    func editVoiceShortcutViewController(_ controller: INUIEditVoiceShortcutViewController, didDeleteVoiceShortcutWithIdentifier deletedVoiceShortcutIdentifier: UUID) {
        Analytics.logEvent("se4_add_to_siri_cancelled", parameters: [
            "os_version": UIDevice.current.systemVersion,
            "device_type": getDeviceType(),
            "mode": "edit",
            "question": shortcutListItem.question.prefix(100)
            ])
        
        dismiss(animated: true, completion: nil)
    }
    
    func editVoiceShortcutViewControllerDidCancel(_ controller: INUIEditVoiceShortcutViewController) {
        dismiss(animated: true, completion: nil)
    }
    
    
}



