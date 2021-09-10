/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The app's main view controller object.
*/

import UIKit
import AVFoundation
import Vision

class CameraViewController: UIViewController {

    private var cameraView: CameraView { view as! CameraView }
    
    private let videoDataOutputQueue = DispatchQueue(label: "CameraFeedDataOutput", qos: .userInteractive)
    private var cameraFeedSession: AVCaptureSession?
    private var handPoseRequest = VNDetectHumanHandPoseRequest()
    
    private var pickerSelectedChar : String? = nil
    private let tv = UITextView()
    private let tvMiddleBig = UITextView()
    private let label = UILabel()
    private let drawOverlay = CAShapeLayer()
    private let drawPath = UIBezierPath()
    private var lastDrawPoint: CGPoint?
    private var isFirstSegment = true
    private var lastObservationTimestamp = Date()
    private var isCharAdded : Bool? //This is used to ensure the same character is not repeated multiple times when a sign language alphabet is detected
    
    @objc private func handleChangeLetter(sender: UIButton) {
        
    }
    
    private var gestureProcessor = HandGestureProcessor()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        label.text = pickerSelectedChar ?? "" + "\nRaise your hand to sign this letter"
        label.numberOfLines = 0
        label.frame = CGRect(x: 10,y: 50,width: 350, height: 60)
        label.textAlignment = .center
        label.lineBreakMode = .byWordWrapping
        label.backgroundColor = UIColor.black
        view.addSubview(label)
        
        tv.text = ""
        tv.font = UIFont.systemFont(ofSize: 20)
        tv.sizeToFit()
        tv.backgroundColor = UIColor.red
        //tv.textContainerInset = UIEdgeInsets(top: 0,left: 1,bottom: 0,right: 1)
        tv.frame = CGRect(x: 10,y: 50,width: 350, height: 60) // x , y, width , height
        //tv.center = view.center
        //view.addSubview(tv)
        
        tvMiddleBig.text = "✓" //"✔"
        tvMiddleBig.font = UIFont.systemFont(ofSize: 150)
        tvMiddleBig.sizeToFit()
        tvMiddleBig.textColor = .green
        tvMiddleBig.backgroundColor = .none
        tvMiddleBig.center = view.center
        tvMiddleBig.isHidden = true
        view.addSubview(tvMiddleBig)
        
        let button = UIButton()
        button.frame = CGRect(x: 10, y: 50, width: 350, height: 60)
        button.backgroundColor = .blue
        button.setTitle("Tap to change", for: .normal)
        button.addTarget(self, action:#selector(handleChangeLetter(sender:)), for: .touchUpInside)
        //view.addSubview(button)
        
        let picker = UIPickerView()
        picker.delegate = self
        picker.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(picker)
        picker.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor).isActive = true
        picker.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor).isActive = true
        picker.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        picker.selectRow(26, inComponent: 0, animated: false)
        label.text = "Fingerspelling"
        
        drawOverlay.frame = view.layer.bounds
        drawOverlay.lineWidth = 5
        drawOverlay.backgroundColor = #colorLiteral(red: 0.9999018312, green: 1, blue: 0.9998798966, alpha: 0.5).cgColor
        drawOverlay.strokeColor = #colorLiteral(red: 0.6, green: 0.1, blue: 0.3, alpha: 1).cgColor
        drawOverlay.fillColor = #colorLiteral(red: 0.9999018312, green: 1, blue: 0.9998798966, alpha: 0).cgColor
        drawOverlay.lineCap = .round
        view.layer.addSublayer(drawOverlay)
        // This sample app detects one hand only.
        handPoseRequest.maximumHandCount = 1
        // Add state change handler to hand gesture processor.
        gestureProcessor.didChangeStateClosure = { [weak self] state in
            self?.handleGestureStateChange(state: state)
        }
        // Add double tap gesture recognizer for clearing the draw path.
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleGesture(_:)))
        recognizer.numberOfTouchesRequired = 1
        recognizer.numberOfTapsRequired = 2
        view.addGestureRecognizer(recognizer)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        do {
            if cameraFeedSession == nil {
                cameraView.previewLayer.videoGravity = .resizeAspectFill
                try setupAVSession()
                cameraView.previewLayer.session = cameraFeedSession
            }
            cameraFeedSession?.startRunning()
        } catch {
            AppError.display(error, inViewController: self)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        cameraFeedSession?.stopRunning()
        super.viewWillDisappear(animated)
    }
    
    func setupAVSession() throws {
        // Select a front facing camera, make an input.
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw AppError.captureSessionSetup(reason: "Could not find a front facing camera.")
        }
        
        guard let deviceInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            throw AppError.captureSessionSetup(reason: "Could not create video device input.")
        }
        
        let session = AVCaptureSession()
        session.beginConfiguration()
        session.sessionPreset = AVCaptureSession.Preset.high
        
        // Add a video input.
        guard session.canAddInput(deviceInput) else {
            throw AppError.captureSessionSetup(reason: "Could not add video device input to the session")
        }
        session.addInput(deviceInput)
        
        let dataOutput = AVCaptureVideoDataOutput()
        if session.canAddOutput(dataOutput) {
            session.addOutput(dataOutput)
            // Add a video data output.
            dataOutput.alwaysDiscardsLateVideoFrames = true
            dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
            dataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        } else {
            throw AppError.captureSessionSetup(reason: "Could not add video data output to the session")
        }
        session.commitConfiguration()
        cameraFeedSession = session
}
    
    func processPoints(wrist: CGPoint?, thumbTip: CGPoint?, thumbIp: CGPoint?, thumbMp: CGPoint?, thumbCMC: CGPoint?, indexTip: CGPoint?, indexDip: CGPoint?, indexPip: CGPoint?, indexMcp: CGPoint?, middleTip: CGPoint?, middleDip: CGPoint?, middlePip: CGPoint?, middleMcp: CGPoint?, ringTip: CGPoint?, ringDip: CGPoint?, ringPip: CGPoint?, ringMcp: CGPoint?, littleTip: CGPoint?, littleDip: CGPoint?, littlePip: CGPoint?, littleMcp: CGPoint?) {
        // Check that we have both points.
        guard let wristPoint = wrist,
              let thumbPoint = thumbTip,
              let thumbIpPoint = thumbIp,
              let thumbMpPoint = thumbMp,
              let thumbCmcPoint = thumbCMC,
              let indexTipPoint = indexTip,
              let indexDipPoint = indexDip,
              let indexPipPoint = indexPip,
              let indexMcpPoint = indexMcp,
              let middleTipPoint = middleTip,
              let middleDipPoint = middleDip,
              let middlePipPoint = middlePip,
              let middleMcp = middleMcp,
              let ringTipPoint = ringTip,
              let ringDipPoint = ringDip,
              let ringPipPoint = ringPip,
              let ringMcpPoint = ringMcp,
              let littleTipPoint = littleTip,
              let littleDipPoint = littleDip,
              let littlePipPoint = littlePip,
              let littleMcpPoint = littleMcp else {
            // If there were no observations for more than 2 seconds reset gesture processor.
            if Date().timeIntervalSince(lastObservationTimestamp) > 2 {
                gestureProcessor.reset()
            }
            cameraView.showPoints([], color: .clear)
            return
        }
        
        // Convert points from AVFoundation coordinates to UIKit coordinates.
        let previewLayer = cameraView.previewLayer
        let wristPointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: wristPoint)
        let thumbPointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: thumbPoint)
        let thumbIpPointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: thumbIpPoint)
        let thumbMpPointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: thumbMpPoint)
        let thumbCmcPointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: thumbCmcPoint)
        let indexTipPointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: indexTipPoint)
        let indexDipPointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: indexDipPoint)
        let indexPipPointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: indexPipPoint)
        let indexMcpPointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: indexMcpPoint)
        let middleTipPointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: middleTipPoint)
        let middleDipPointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: middleDipPoint)
        let middlePipPointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: middlePipPoint)
        let middleMcpConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: middleMcp)
        let ringTipPointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: ringTipPoint)
        let ringDipPointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: ringDipPoint)
        let ringPipPointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: ringPipPoint)
        let ringMcpPointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: ringMcpPoint)
        let littleTipPointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: littleTipPoint)
        let littleDipPointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: littleDipPoint)
        let littlePipPointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: littlePipPoint)
        let littleMcpPointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: littleMcpPoint)
        
        // Process new points
        gestureProcessor.processPointsSet((wristPointConverted, thumbPointConverted, thumbIpPointConverted, thumbMpPointConverted, thumbCmcPointConverted, indexTipPointConverted, indexDipPointConverted, indexPipPointConverted, indexMcpPointConverted, middleTipPointConverted, middleDipPointConverted, middlePipPointConverted, middleMcpConverted, ringTipPointConverted, ringDipPointConverted, ringPipPointConverted, ringMcpPointConverted, littleTipPointConverted, littleDipPointConverted, littlePipPointConverted, littleMcpPointConverted))
    }
    
    private func handleGestureStateChange(state: HandGestureProcessor.State) {
        let pointsSet = gestureProcessor.lastProcessedPointsSet
        var tipsColor: UIColor
        var charToBeAdded = ""
        switch state {
        case .possiblePinch, .possibleApart, .possibleLetter:
            tipsColor = .yellow
        case .clear:
            tipsColor = .green
            tv.text = ""
        case .spacebar:
            tipsColor = .green
            charToBeAdded += isCharAdded == false ? " " : ""
            isCharAdded = true
        case .aslLetterA:
            tipsColor = .green
            charToBeAdded += isCharAdded == false ? "A" : ""
            isCharAdded = true
        case .aslLetterB:
            tipsColor = .green
            charToBeAdded += isCharAdded == false ? "B" : ""
            isCharAdded = true
        case .aslLetterC:
            tipsColor = .green
            charToBeAdded += isCharAdded == false ? "C" : ""
            isCharAdded = true
        case .aslLetterD:
            tipsColor = .green
            charToBeAdded += isCharAdded == false ? "D" : ""
            isCharAdded = true
        case .aslLetterE:
            tipsColor = .green
            charToBeAdded += isCharAdded == false ? "E" : ""
            isCharAdded = true
        case .aslLetterF:
            tipsColor = .green
            charToBeAdded += isCharAdded == false ? "F" : ""
            isCharAdded = true
        case .aslLetterG:
            tipsColor = .green
            charToBeAdded += isCharAdded == false ? "G" : ""
            isCharAdded = true
        case .aslLetterH:
            tipsColor = .green
            charToBeAdded += isCharAdded == false ? "H" : ""
            isCharAdded = true
        case .aslLetterI:
            tipsColor = .green
            charToBeAdded += isCharAdded == false ? "I" : ""
            isCharAdded = true
        case .aslLetterJ:
            tipsColor = .green
            charToBeAdded += isCharAdded == false ? "J" : ""
            isCharAdded = true
        case .aslLetterK:
            tipsColor = .green
            charToBeAdded += isCharAdded == false ? "K" : ""
            isCharAdded = true
        case .aslLetterL:
            tipsColor = .green
            charToBeAdded += isCharAdded == false ? "L" : ""
            isCharAdded = true
        case .aslLetterM:
            tipsColor = .green
            charToBeAdded += isCharAdded == false ? "M" : ""
            isCharAdded = true
        case .aslLetterN:
            tipsColor = .green
            charToBeAdded += isCharAdded == false ? "N" : ""
            isCharAdded = true
        case .aslLetterO:
            tipsColor = .green
            charToBeAdded += isCharAdded == false ? "O" : ""
            isCharAdded = true
        case .aslLetterP:
            tipsColor = .green
            charToBeAdded += isCharAdded == false ? "P" : ""
            isCharAdded = true
        case .aslLetterQ:
            tipsColor = .green
            charToBeAdded += isCharAdded == false ? "Q" : ""
            isCharAdded = true
        case .aslLetterR:
            tipsColor = .green
            charToBeAdded += isCharAdded == false ? "R" : ""
            isCharAdded = true
        case .aslLetterS:
            tipsColor = .green
            charToBeAdded += isCharAdded == false ? "S" : ""
            isCharAdded = true
        case .aslLetterT:
            tipsColor = .green
            charToBeAdded += isCharAdded == false ? "T" : ""
            isCharAdded = true
        case .aslLetterU:
            tipsColor = .green
            charToBeAdded += isCharAdded == false ? "U" : ""
            isCharAdded = true
        case .aslLetterV:
            tipsColor = .green
            charToBeAdded += isCharAdded == false ? "V" : ""
            isCharAdded = true
        case .aslLetterW:
            tipsColor = .green
            charToBeAdded += isCharAdded == false ? "W" : ""
            isCharAdded = true
        case .aslLetterX:
            tipsColor = .green
            charToBeAdded += isCharAdded == false ? "X" : ""
            isCharAdded = true
        case .aslLetterY:
            tipsColor = .green
            charToBeAdded += isCharAdded == false ? "Y" : ""
            isCharAdded = true
        case .apart, .unknown:
            tipsColor = .red
            tv.text += ""
            isCharAdded = false
        }
        if charToBeAdded.isEmpty == false && pickerSelectedChar == nil {
            animateSignResult(letter: charToBeAdded)
        }
        if charToBeAdded == pickerSelectedChar {
            animateSignResult(letter: nil)
        }
        tv.text! += charToBeAdded
        cameraView.showPoints([
                                pointsSet.thumbTip, pointsSet.indexTip, pointsSet.middleTip, pointsSet.ringTip,pointsSet.littleTip,
                               //pointsSet.thumbIp, pointsSet.indexDip, pointsSet.middleDip, pointsSet.ringDip, pointsSet.ringPip, pointsSet.ringMcp,
                               //pointsSet.thumbMp, pointsSet.indexPip, pointsSet.middlePip, pointsSet.ringPip, pointsSet.littlePip,
                               //pointsSet.thumbCmc,  pointsSet.indexMcp, pointsSet.middleMcp, pointsSet.ringMcp, pointsSet.littleMcp,
                                pointsSet.wrist
                            ], color: tipsColor)
    }
    
    private func animateSignResult(letter : String?) {
        if letter != nil {
            self.tvMiddleBig.text = letter
        }
        else {
            self.tvMiddleBig.text = "✓"
        }
        self.tvMiddleBig.isHidden = false
        self.tvMiddleBig.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        UIView.animate(withDuration: 1.0,
                       delay: 0,
                       usingSpringWithDamping: 0.2,
                       initialSpringVelocity: 6.0,
                       options: .allowUserInteraction,
                       animations: { [weak self] in
                        self?.tvMiddleBig.transform = .identity
            },
                       completion: { _ in
                           self.tvMiddleBig.isHidden = true
                       })
    }
    
    private func updatePath(with points: HandGestureProcessor.PointsPair, isLastPointsPair: Bool) {
        // Get the mid point between the tips.
        let (thumbTip, indexTip) = points
        let drawPoint = CGPoint.midPoint(p1: thumbTip, p2: indexTip)

        if isLastPointsPair {
            if let lastPoint = lastDrawPoint {
                // Add a straight line from the last midpoint to the end of the stroke.
                drawPath.addLine(to: lastPoint)
            }
            // We are done drawing, so reset the last draw point.
            lastDrawPoint = nil
        } else {
            if lastDrawPoint == nil {
                // This is the beginning of the stroke.
                drawPath.move(to: drawPoint)
                isFirstSegment = true
            } else {
                let lastPoint = lastDrawPoint!
                // Get the midpoint between the last draw point and the new point.
                let midPoint = CGPoint.midPoint(p1: lastPoint, p2: drawPoint)
                if isFirstSegment {
                    // If it's the first segment of the stroke, draw a line to the midpoint.
                    drawPath.addLine(to: midPoint)
                    isFirstSegment = false
                } else {
                    // Otherwise, draw a curve to a midpoint using the last draw point as a control point.
                    drawPath.addQuadCurve(to: midPoint, controlPoint: lastPoint)
                }
            }
            // Remember the last draw point for the next update pass.
            lastDrawPoint = drawPoint
        }
        // Update the path on the overlay layer.
        drawOverlay.path = drawPath.cgPath
    }
    
    @IBAction func handleGesture(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else {
            return
        }
        drawPath.removeAllPoints()
        drawOverlay.path = drawPath.cgPath
    }
}

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        var wrist: CGPoint?
        var thumbTip: CGPoint?
        var thumbIp: CGPoint?
        var thumbMp: CGPoint?
        var thumbCMC: CGPoint?
        var indexTip: CGPoint?
        var indexDip: CGPoint?
        var indexPip: CGPoint?
        var indexMcp: CGPoint?
        var middleTip: CGPoint?
        var middleDip: CGPoint?
        var middlePip: CGPoint?
        var middleMcp: CGPoint?
        var ringTip: CGPoint?
        var ringDip: CGPoint?
        var ringPip: CGPoint?
        var ringMcp: CGPoint?
        var littleTip: CGPoint?
        var littleDip: CGPoint?
        var littlePip: CGPoint?
        var littleMcp: CGPoint?
        
        defer {
            DispatchQueue.main.sync {
                self.processPoints(wrist: wrist, thumbTip: thumbTip, thumbIp: thumbIp, thumbMp: thumbMp, thumbCMC: thumbCMC, indexTip: indexTip, indexDip: indexDip, indexPip: indexPip, indexMcp: indexMcp, middleTip: middleTip, middleDip: middleDip, middlePip: middlePip, middleMcp: middleMcp, ringTip: ringTip, ringDip: ringDip, ringPip: ringPip, ringMcp: ringMcp, littleTip: littleTip, littleDip: littleDip, littlePip: littlePip, littleMcp: littleMcp)
            }
        }

        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])
        do {
            // Perform VNDetectHumanHandPoseRequest
            try handler.perform([handPoseRequest])
            // Continue only when a hand was detected in the frame.
            // Since we set the maximumHandCount property of the request to 1, there will be at most one observation.
            guard let observation = handPoseRequest.results?.first else {
                return
            }
            // Get points for thumb and index finger.
            let wristPoint = try observation.recognizedPoint(.wrist)
            let thumbPoints = try observation.recognizedPoints(.thumb)
            let indexFingerPoints = try observation.recognizedPoints(.indexFinger)
            let middleFingerPoints = try observation.recognizedPoints(.middleFinger)
            let ringFingerPoints = try observation.recognizedPoints(.ringFinger)
            let littleFingerPoints = try observation.recognizedPoints(.littleFinger)
            // Look for tip points.
            guard let thumbTipPoint = thumbPoints[.thumbTip],
                  let indexTipPoint = indexFingerPoints[.indexTip],
                  let middleTipPoint = middleFingerPoints[.middleTip],
                  let ringTipPoint = ringFingerPoints[.ringTip],
                  let littleTipPoint = littleFingerPoints[.littleTip] else {
                return
            }
            // Look for second level points. (DIP)
            guard let thumbIpPoint = thumbPoints[.thumbIP],
                  let indexDipPoint = indexFingerPoints[.indexDIP],
                  let middleDipPoint = middleFingerPoints[.middleDIP],
                  let ringDipPoint = ringFingerPoints[.ringDIP],
                  let littleDipPoint = littleFingerPoints[.littleDIP] else {
                return
            }
            // Look for third level points. (PIP)
            guard let thumbMpPoint = thumbPoints[.thumbMP],
                  let indexPipPoint = indexFingerPoints[.indexPIP],
                  let middlePipPoint = middleFingerPoints[.middlePIP],
                  let ringPipPoint = ringFingerPoints[.ringPIP],
                  let littlePipPoint = littleFingerPoints[.littlePIP] else {
                return
            }
            // Look for base of fingers. (MCP)
            guard let thumbCmcPoint = thumbPoints[.thumbCMC],
                  let indexMcpPoint = indexFingerPoints[.indexMCP],
                  let middleMcpPoint = middleFingerPoints[.middleMCP],
                  let ringMcpPoint = ringFingerPoints[.ringMCP],
                  let littleMcpPoint = littleFingerPoints[.littleMCP] else {
                return
            }
            // Ignore low confidence points.
            guard thumbTipPoint.confidence > 0.5
                    || indexTipPoint.confidence > 0.5
                    || middleTipPoint.confidence > 0.5
                    || ringTipPoint.confidence > 0.5
                    || littleTipPoint.confidence > 0.5 else {
                return
            }
            // Convert points from Vision coordinates to AVFoundation coordinates.
            wrist = wristPoint.confidence > 0.5 ? CGPoint(x: wristPoint.location.x, y: 1 - wristPoint.location.y) : nil
            thumbTip = thumbTipPoint.confidence > 0.5 ? CGPoint(x: thumbTipPoint.location.x, y: 1 - thumbTipPoint.location.y) : nil
            thumbIp = thumbIpPoint.confidence > 0.5 ? CGPoint(x: thumbIpPoint.location.x, y: 1 - thumbIpPoint.location.y) : nil
            thumbMp = thumbMpPoint.confidence > 0.5 ? CGPoint(x: thumbMpPoint.location.x, y: 1 - thumbMpPoint.location.y) : nil
            thumbCMC = thumbCmcPoint.confidence > 0.5 ? CGPoint(x: thumbCmcPoint.location.x, y: 1 - thumbCmcPoint.location.y) : nil
            indexTip = indexTipPoint.confidence > 0.5 ? CGPoint(x: indexTipPoint.location.x, y: 1 - indexTipPoint.location.y) : nil
            indexDip = indexDipPoint.confidence > 0.3 ? CGPoint(x: indexDipPoint.location.x, y: 1 - indexDipPoint.location.y) : nil
            indexPip = indexPipPoint.confidence > 0.3 ? CGPoint(x: indexPipPoint.location.x, y: 1 - indexPipPoint.location.y) : nil
            indexMcp = indexMcpPoint.confidence > 0.3 ? CGPoint(x: indexMcpPoint.location.x, y: 1 - indexMcpPoint.location.y) : nil
            middleTip = middleTipPoint.confidence > 0.3 ? CGPoint(x: middleTipPoint.location.x, y: 1 - middleTipPoint.location.y) : nil
            middleDip = middleDipPoint.confidence > 0.3 ? CGPoint(x: middleDipPoint.location.x, y: 1 - middleDipPoint.location.y) : nil
            middlePip = middlePipPoint.confidence > 0.3 ? CGPoint(x: middlePipPoint.location.x, y: 1 - middlePipPoint.location.y) : nil
            middleMcp = middleMcpPoint.confidence > 0.3 ? CGPoint(x: middleMcpPoint.location.x, y: 1 - middleMcpPoint.location.y) : nil
            ringTip = ringTipPoint.confidence > 0.3 ? CGPoint(x: ringTipPoint.location.x, y: 1 - ringTipPoint.location.y) : nil
            ringDip = ringDipPoint.confidence > 0.3 ? CGPoint(x: ringDipPoint.location.x, y: 1 - ringDipPoint.location.y) : nil
            ringPip = ringPipPoint.confidence > 0.3 ? CGPoint(x: ringPipPoint.location.x, y: 1 - ringPipPoint.location.y) : nil
            ringMcp = ringMcpPoint.confidence > 0.3 ? CGPoint(x: ringMcpPoint.location.x, y: 1 - ringMcpPoint.location.y) : nil
            littleTip = littleTipPoint.confidence > 0.3 ? CGPoint(x: littleTipPoint.location.x, y: 1 - littleTipPoint.location.y) : nil
            littleDip = littleDipPoint.confidence > 0.3 ? CGPoint(x: littleDipPoint.location.x, y: 1 - littleDipPoint.location.y) : nil
            littlePip = littlePipPoint.confidence > 0.3 ? CGPoint(x: littlePipPoint.location.x, y: 1 - littlePipPoint.location.y) : nil
            littleMcp = littleMcpPoint.confidence > 0.3 ? CGPoint(x: littleMcpPoint.location.x, y: 1 - littleMcpPoint.location.y) : nil
        } catch {
            cameraFeedSession?.stopRunning()
            let error = AppError.visionError(error: error)
            DispatchQueue.main.async {
                error.displayInViewController(self)
            }
        }
    }
}

extension CameraViewController : UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return 27
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if row == 26 {
            pickerSelectedChar = nil
            label.text = "Fingerspelling"
        }
        else {
            var string = ""
            string.append(Character(UnicodeScalar(row + 65)!))
            pickerSelectedChar = string
            let str2 = (pickerSelectedChar ?? "") + "\nRaise your hand to sign this letter"
            label.text = str2
        }
    }
}

extension CameraViewController : UIPickerViewDataSource {
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if row == 26 {
            return "Fingerspelling"
        }
        var string = ""
        string.append(Character(UnicodeScalar(row + 65)!))
        return string
    }
}

