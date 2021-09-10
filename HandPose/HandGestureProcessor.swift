/*
See LICENSE folder for this sample’s licensing information.

Abstract:
This class is a state machine that transitions between states based on pair
    of points stream. These points are the tips for thumb and index finger.
    If the tips are closer than the desired distance, the state is "pinched", otherwise it's "apart".
    There are also "possiblePinch" and "possibeApart" states that are used to smooth out state transitions.
    During these possible states HandGestureProcessor collects the required amount of evidence before committing to a definite state.
*/

import CoreGraphics

class HandGestureProcessor {
    enum State {
        case aslLetterA
        case aslLetterB
        case aslLetterC
        case aslLetterD
        case aslLetterE
        case aslLetterF
        case aslLetterG
        case aslLetterH
        case aslLetterI
        case aslLetterJ
        case aslLetterK
        case aslLetterL
        case aslLetterM
        case aslLetterN
        case aslLetterO
        case aslLetterP
        case aslLetterQ
        case aslLetterR
        case aslLetterS
        case aslLetterT
        case aslLetterU
        case aslLetterV
        case aslLetterW
        case aslLetterX
        case aslLetterY
        
        case possibleLetter
        case clear
        case spacebar
        case possiblePinch
        case possibleApart
        case apart
        case unknown
    }
    
    enum Finger {
        //Not using Apple's enum as it involces importing Vision
        case THUMB
        case INDEX
        case MIDDLE
        case RING
        case LITTLE
    }
    
    typealias PointsPair = (thumbTip: CGPoint, indexTip: CGPoint)
    typealias PointsSet = (wrist: CGPoint, thumbTip: CGPoint, thumbIp: CGPoint, thumbMp: CGPoint, thumbCmc: CGPoint, indexTip: CGPoint, indexDip: CGPoint, indexPip: CGPoint, indexMcp: CGPoint, middleTip: CGPoint, middleDip: CGPoint, middlePip: CGPoint, middleMcp: CGPoint, ringTip: CGPoint, ringDip: CGPoint, ringPip: CGPoint, ringMcp: CGPoint, littleTip: CGPoint, littleDip: CGPoint, littlePip: CGPoint, littleMcp: CGPoint)
    
    private var state = State.unknown {
        didSet {
            didChangeStateClosure?(state)
        }
    }
    private var letterEvidenceCounter = 0
    private var pinchEvidenceCounter = 0
    private var apartEvidenceCounter = 0
    private let pinchMaxDistance: CGFloat
    private let touchingMaxAngle: CGFloat = 25
    private let evidenceCounterStateTrigger: Int
    
    var didChangeStateClosure: ((State) -> Void)?
    private (set) var lastProcessedPointsSet = PointsSet(.zero, .zero, .zero, .zero, .zero, .zero, .zero, .zero, .zero, .zero, .zero, .zero, .zero, .zero, .zero, .zero, .zero, .zero, .zero, .zero, .zero)
    
    init(pinchMaxDistance: CGFloat = 50, evidenceCounterStateTrigger: Int = 10) {
        self.pinchMaxDistance = pinchMaxDistance
        self.evidenceCounterStateTrigger = evidenceCounterStateTrigger
    }
    
    func reset() {
        state = .unknown
        pinchEvidenceCounter = 0
        apartEvidenceCounter = 0
    }
    
    func processPointsSet(_ pointsSet: PointsSet) {
        lastProcessedPointsSet = pointsSet
        //Distance from neighbor
        let distanceThumbIndex = pointsSet.thumbTip.distance(from: pointsSet.indexTip)
        let distanceIndexMiddle = pointsSet.indexTip.distance(from: pointsSet.middleTip)
        let distanceMiddleRing = pointsSet.middleTip.distance(from: pointsSet.ringTip)
        let distanceRingLittle = pointsSet.ringTip.distance(from: pointsSet.littleTip)
        
        //Distance from thumb tip
        let distanceThumbMiddle = pointsSet.thumbTip.distance(from: pointsSet.middleTip)
        let distanceThumbMiddleMcp = pointsSet.thumbTip.distance(from: pointsSet.middleMcp)
        let distanceThumbRing = pointsSet.thumbTip.distance(from: pointsSet.ringTip)
        let distanceThumbLittle = pointsSet.thumbTip.distance(from: pointsSet.littleTip)
        let distanceThumbIndexPip = pointsSet.thumbTip.distance(from: pointsSet.indexPip)
        let distanceThumbMiddlePip = pointsSet.thumbTip.distance(from: pointsSet.middlePip)
        let distanceThumbTipRingDip = pointsSet.thumbTip.distance(from: pointsSet.ringDip)
        let distanceThumbTipLittleDip = pointsSet.thumbTip.distance(from: pointsSet.littleDip)
        let distanceThumbTipLittleTip = pointsSet.thumbTip.distance(from: pointsSet.littleTip)
        
        //Distance from thumb IP (2nd level)
        let distanceThumbIpIndexTip = pointsSet.thumbIp.distance(from: pointsSet.indexTip)
        let distanceThumbIpIndexPip = pointsSet.thumbIp.distance(from: pointsSet.indexPip)
        let distanceThumbIpIndexMcp = pointsSet.thumbIp.distance(from: pointsSet.indexMcp) //Is thumb baside index finger?
        let distanceThumbIpMiddle = pointsSet.thumbIp.distance(from: pointsSet.middleTip)
        
        //Distance from thumb MP (3rd level)
        let distanceThumbMpIndexTip = pointsSet.thumbMp.distance(from: pointsSet.indexTip)
        
        //Distance from thumb CMC(base)
        let distanceThumbCmcIndexTip = pointsSet.thumbCmc.distance(from: pointsSet.indexTip)
        
        //Distance from wrist
        let distanceWristThumb = pointsSet.wrist.distance(from: pointsSet.thumbTip)
        let distanceWristIndex = pointsSet.wrist.distance(from: pointsSet.indexTip)
        let distanceWristMiddle = pointsSet.wrist.distance(from: pointsSet.middleTip)
        let distanceWristRing = pointsSet.wrist.distance(from: pointsSet.ringTip)
        let distanceWristLittle = pointsSet.wrist.distance(from: pointsSet.littleTip)
        
        //Distances within same finger - Index finger
        let distanceIndexTipIndexMcp = pointsSet.indexTip.distance(from: pointsSet.indexMcp)
        
        let fingersTogetherIndexMiddle = areTwoFingersTogether(pointsSet: pointsSet, finger1: Finger.INDEX, finger2: Finger.MIDDLE)
        let fingersTogetherMiddleRing = areTwoFingersTogether(pointsSet: pointsSet, finger1: Finger.MIDDLE, finger2: Finger.RING)
        let fingersTogetherRingLittle = areTwoFingersTogether(pointsSet: pointsSet, finger1: Finger.RING, finger2: Finger.LITTLE)
        let fourFingersTogether = fingersTogetherIndexMiddle && fingersTogetherMiddleRing && fingersTogetherRingLittle
        let pointingUpIndex = isFingerPointingUp(finger: Finger.INDEX, pointsSet: pointsSet)
        let pointingUpMiddle = isFingerPointingUp(finger: Finger.MIDDLE, pointsSet: pointsSet)
        let pointingUpRing = isFingerPointingUp(finger: Finger.RING, pointsSet: pointsSet)
        let pointingUpLittle = isFingerPointingUp(finger: Finger.LITTLE, pointsSet: pointsSet)
        let fourFingersPointingUp = pointingUpIndex && pointingUpMiddle && pointingUpRing && pointingUpLittle
        let pointingDownIndex = isFingerPointingDown(finger: Finger.INDEX, pointsSet: pointsSet)
        let pointingDownMiddle = isFingerPointingDown(finger: Finger.MIDDLE, pointsSet: pointsSet)
        let pointingDownRing = isFingerPointingDown(finger: Finger.RING, pointsSet: pointsSet)
        let pointingDownLittle = isFingerPointingDown(finger: Finger.LITTLE, pointsSet: pointsSet)
        let fourFingersPointingDown = pointingDownIndex && pointingDownMiddle && pointingDownRing && pointingDownLittle
        let pointingUpIndexMiddleOnly = pointingUpIndex && pointingUpMiddle && pointingDownRing && pointingDownLittle
        let thumbAndIndexFingerCurlingTowardsEachOther = isThumbAndIndexFingerCurlingTowardsEachOther(pointsSet: pointsSet)
        let indexMiddleCorrectForASL_R = isIndexMiddleCorrectForAslR(pointsSet: pointsSet)
        let indexMiddleCorrectForASL_U = isIndexMiddleCorrectForAslU(pointsSet: pointsSet)
        let thumbCorrectForASL_A = isThumbCorrectForAslA(pointsSet: pointsSet)
        let thumbCorrectForASL_B = isThumbCorrectForAslB(pointsSet: pointsSet)
        let thumbCorrectForASL_C = isThumbCorrectForAslC(pointsSet: pointsSet)
        let thumbAndIndexSpacingCorrectForASL_C = isThumbAndIndexFingerSpacingCorrectForAslC(pointsSet: pointsSet)
        let thumbAndMiddleCorrectForASL_D = isThumbAndMiddleFingerSpacingCorrectForAslD(pointsSet: pointsSet)
        let thumbCorrectForASL_E = isThumbCorrectForAslE(pointsSet: pointsSet)
        let thumbAndIndexCorrectForASL_F = isThumbAndIndexFingerSpacingCorrectForAslF(pointsSet: pointsSet)
        let thumbCorrectForASL_I = isThumbCorrectForAslI(pointsSet: pointsSet)
        let thumbCorrectForASL_K = isThumbCorrectForAslK(pointsSet: pointsSet)
        let thumbCorrectForASL_L = isThumbPointingSidewaysAndAwayFromPalm(pointsSet: pointsSet)
        let thumbCorrectForASL_N = isThumbCorrectForAslN(pointsSet: pointsSet)
        let thumbAndIndexSpacingCorrectForASL_O = isThumbAndIndexFingerSpacingCorrectForAslO(pointsSet: pointsSet)
        let thumbCorrectForASL_P = isThumbCorrectForAslP(pointsSet: pointsSet)
        let thumbCorrectForASL_Q = isFingerPointingDown(finger: Finger.THUMB, pointsSet: pointsSet)
        let thumbCorrectForASL_S = isThumbCorrectForAslS(pointsSet: pointsSet)
        let thumbCorrectForASL_T = isThumbCorrectForAslT(pointsSet: pointsSet)
        let thumbCorrectForASL_U_V_R = isThumbCorrectForAslU(pointsSet: pointsSet)
        let thumbCorrectForASL_W = isThumbCorrectForAslW(pointsSet: pointsSet)
        let thumbCorrectForASL_X = isThumbCorrectForAslX(pointsSet: pointsSet)
        let thumbCorrectForASL_Y = isThumbPointingSidewaysAndAwayFromPalm(pointsSet: pointsSet)
        let indexCorrectForASL_Q = isFingerPointingDown(finger: Finger.INDEX, pointsSet: pointsSet)
        let indexCorrectForASL_G_H_P = isFingerPointingSideways(pointsSet: pointsSet, finger: Finger.INDEX)
        let indexCirrectForASL_C = isIndexFingerCorrectForAslC(pointsSet: pointsSet)
        let indexCorrectForASL_X = isIndexFingerCorrectForAslX(pointsSet: pointsSet)
        let middleCorrectForASL_H = isFingerPointingSideways(pointsSet: pointsSet, finger: Finger.MIDDLE)
        let middleCorrectForASL_P = isMiddleFingerCorrectForAslP(pointsSet: pointsSet)
        let littleFingerCorrectForASL_J = isLittleFingerCorrectForAslJ(pointsSet: pointsSet)
        //print("A: "+String(fourFingersTogether)+" "+String(fourFingersPointingDown)+" "+String(thumbPointingUp)+" "+String(thumbCorrectForASL_A))
        //print("B: "+String(fourFingersPointingUp)+" "+String(fourFingersTogether)+" "+String(thumbCorrectForASL_B))
        //print("C: "+String(indexCirrectForASL_C)+" "+String(thumbCorrectForASL_C))
        //print("D: "+String(pointingUpIndex)+" "+String(pointingUpMiddle)+" "+String(pointingUpRing)+" "+String(pointingUpLittle)+" "+String(thumbAndMiddleCorrectForASL_D)+" "+String(fingersTogetherMiddleRing)+" "+String(fingersTogetherRingLittle))
        print("E: "+String(fourFingersPointingDown)+" "+String(thumbCorrectForASL_E))
        //print("F: "+String(pointingUpMiddle)+" "+String(pointingUpRing)+" "+String(pointingUpLittle)+" "+String(thumbAndIndexCorrectForASL_F))
        //print("G: "+String(indexCorrectForASL_G_H)+" "+String(middleCorrectForASL_H))
        //print("H: "+String(indexCorrectForASL_G_H)+" "+String(middleCorrectForASL_H))
        //print("I: "+String(thumbCorrectForASL_I)+" "+String(pointingDownIndex)+" "+String(pointingDownMiddle)+" "+String(pointingDownRing)+" "+String(pointingUpLittle))
        //print("J: "+String(thumbCorrectForASL_A)+" "+String(pointingDownIndex)+" "+String(pointingDownMiddle)+" "+String(pointingDownRing)+" "+String(pointingUpLittle)+" "+String(littleFingerCorrectForASL_J))
        //print("K: "+String(thumbCorrectForASL_K)+" "+String(fingersTogetherIndexMiddle)+" "+String(pointingDownRing)+" "+String(pointingDownLittle))
        //print("L: "+String(thumbCorrectForASL_L)+" "+String(pointingUpIndex)+" "+String(pointingDownMiddle)+" "+String(pointingDownRing)+" "+String(pointingDownLittle))
        //print("M: "+String(thumbCorrectForASL_A)+" "+String(fourFingersPointingDown)+" "+String(fourFingersTogether))
        //print("N: "+String(thumbCorrectForASL_N)+" "+String(fourFingersPointingDown)+" "+String(fourFingersTogether))
        //print("O: "+String(thumbAndIndexFingerCurlingTowardsEachOther)+" "+String(thumbAndIndexSpacingCorrectForASL_O))   //STOPPED HERE
        //print("P: "+String(indexCorrectForASL_G_H_P)+" "+String(middleCorrectForASL_P)+" "+String(thumbCorrectForASL_P))
        //print("Q: "+String(thumbCorrectForASL_Q)+" "+String(indexCorrectForASL_Q))
        //print("S: "+String(fourFingersPointingDown)+" "+String(thumbCorrectForASL_S))
        //print("T: "+String(thumbCorrectForASL_T)+" "+String(fourFingersPointingDown)+" "+String(fourFingersTogether))
        //print("U: "+String(fingersTogetherIndexMiddle)+" "+String(pointingUpIndex)+" "+String(pointingUpMiddle)+" "+String(pointingDownRing)+" "+String(pointingDownLittle)+" "+String(thumbCorrectForASL_U_V))
        //print("V: "+String(fingersTogetherIndexMiddle)+" "+String(pointingUpIndex)+" "+String(pointingUpMiddle)+" "+String(pointingDownRing)+" "+String(pointingDownLittle)+" "+String(thumbCorrectForASL_U_V))
        //print("W: "+String(pointingUpIndex)+" "+String(pointingUpMiddle)+" "+String(pointingUpRing)+" "+String(pointingUpLittle))
        //print("X: "+String(thumbCorrectForASL_X)+" "+String(indexCorrectForASL_X)+" "+String(pointingDownMiddle)+" "+String(pointingDownRing)+" "+String(pointingDownLittle))
        //print("Y: "+String(thumbCorrectForASL_Y)+" "+String(pointingDownIndex)+" "+String(pointingDownMiddle)+" "+String(pointingDownRing)+" "+String(pointingUpLittle))
        
        if fourFingersPointingDown //&& fourFingersTogether
        {
            print("********FOUR FINGERS POINTING DOWN**********")
            //Letters A, E, S, T, N, M
            //It is done in this order based on thumb position.
            if  thumbCorrectForASL_A
            {
                print("******** A **********")
                        //Thumb outside the palm region
                        // Keep accumulating evidence for letter A.
                        letterEvidenceCounter += 1
                        apartEvidenceCounter = 0
                        // Set new state based on evidence amount.
                        state = (letterEvidenceCounter >= evidenceCounterStateTrigger) ? .aslLetterA : .possibleLetter
            }
            else if thumbAndIndexSpacingCorrectForASL_O
                    && thumbAndIndexFingerCurlingTowardsEachOther
            {
                print("********** O ***************")
                // Keep accumulating evidence for letter O.
                pinchEvidenceCounter += 1
                apartEvidenceCounter = 0
                // Set new state based on evidence amount.
                state = (pinchEvidenceCounter >= evidenceCounterStateTrigger) ? .aslLetterO : .possibleLetter
            }
            else {
                //Thumb inside the palm region
                if thumbCorrectForASL_T
                {
                    print("******** T **********")
                    // Keep accumulating evidence for letter T.
                    pinchEvidenceCounter += 1
                    apartEvidenceCounter = 0
                    // Set new state based on evidence amount.
                    state = (pinchEvidenceCounter >= evidenceCounterStateTrigger) ? .aslLetterT : .possibleLetter
                }
                else if thumbCorrectForASL_N
                {
                    print("******** N **********")
                    // Keep accumulating evidence for letter N.
                    pinchEvidenceCounter += 1
                    apartEvidenceCounter = 0
                    // Set new state based on evidence amount.
                    state = (pinchEvidenceCounter >= evidenceCounterStateTrigger) ? .aslLetterN : .possibleLetter
                }
                else if thumbCorrectForASL_E
                {
                    print("******** E **********")
                    //NOT WORKING
                    // Keep accumulating evidence for letter E.
                    letterEvidenceCounter += 1
                    apartEvidenceCounter = 0
                    // Set new state based on evidence amount.
                    state = (letterEvidenceCounter >= evidenceCounterStateTrigger) ? .aslLetterE : .possibleLetter
                }
                else if thumbCorrectForASL_S
                {
                    print("******** S **********")
                    //NOT WORKING
                    // Keep accumulating evidence for letter S.
                    pinchEvidenceCounter += 1
                    apartEvidenceCounter = 0
                    // Set new state based on evidence amount.
                    state = (pinchEvidenceCounter >= evidenceCounterStateTrigger) ? .aslLetterS : .possibleLetter
                }
                else
                {
                    print("******** M **********")
                    //NOT WORKING
                    // Keep accumulating evidence for letter M.
                    pinchEvidenceCounter += 1
                    apartEvidenceCounter = 0
                    // Set new state based on evidence amount.
                    state = (pinchEvidenceCounter >= evidenceCounterStateTrigger) ? .aslLetterM : .possibleLetter
                }
            }

        }
        else if pointingUpIndexMiddleOnly
        {
            //Letter V,K,U,R
                    if thumbCorrectForASL_K
                            && fingersTogetherIndexMiddle == false
                    {
                        // Keep accumulating evidence for letter K.
                        letterEvidenceCounter += 1
                        apartEvidenceCounter = 0
                        // Set new state based on evidence amount.
                        state = (letterEvidenceCounter >= evidenceCounterStateTrigger) ? .aslLetterK : .possibleLetter
                    }
                    else if thumbCorrectForASL_U_V_R
                    {
                        
                        if fingersTogetherIndexMiddle == false
                        {
                            // Keep accumulating evidence for letter V.
                            letterEvidenceCounter += 1
                            apartEvidenceCounter = 0
                            // Set new state based on evidence amount.
                            state = (letterEvidenceCounter >= evidenceCounterStateTrigger) ? .aslLetterV : .possibleLetter
                        }
                        else if indexMiddleCorrectForASL_U
                        {
                            // Keep accumulating evidence for letter U.
                            letterEvidenceCounter += 1
                            apartEvidenceCounter = 0
                            // Set new state based on evidence amount.
                            state = (letterEvidenceCounter >= evidenceCounterStateTrigger) ? .aslLetterU : .possibleLetter
                        }
                        else if indexMiddleCorrectForASL_R
                        {
                            // Keep accumulating evidence for letter R.
                            letterEvidenceCounter += 1
                            apartEvidenceCounter = 0
                            // Set new state based on evidence amount.
                            state = (letterEvidenceCounter >= evidenceCounterStateTrigger) ? .aslLetterR : .possibleLetter
                        }
                    }
        }
        else if indexCorrectForASL_G_H_P
        {
            //For letters H,P,G
            if indexCorrectForASL_G_H_P
                            && middleCorrectForASL_H
            {
                    // Keep accumulating evidence for letter H.
                    letterEvidenceCounter += 1
                    apartEvidenceCounter = 0
                    // Set new state based on evidence amount.
                    state = (letterEvidenceCounter >= evidenceCounterStateTrigger) ? .aslLetterH : .possibleLetter
            }
            else if indexCorrectForASL_G_H_P
                    && middleCorrectForASL_P
                    && thumbCorrectForASL_P
            {
                // Keep accumulating evidence for letter P.
                letterEvidenceCounter += 1
                apartEvidenceCounter = 0
                // Set new state based on evidence amount.
                state = (letterEvidenceCounter >= evidenceCounterStateTrigger) ? .aslLetterP : .possibleLetter
            }
            else if indexCorrectForASL_G_H_P
                            && middleCorrectForASL_H == false
            {
                    // Keep accumulating evidence for letter G.
                    letterEvidenceCounter += 1
                    apartEvidenceCounter = 0
                    // Set new state based on evidence amount.
                    state = (letterEvidenceCounter >= evidenceCounterStateTrigger) ? .aslLetterG : .possibleLetter
            }

        }
        else if fourFingersPointingUp
                && fourFingersTogether
                && thumbCorrectForASL_B
        {
                    // Keep accumulating evidence for letter B.
                    letterEvidenceCounter += 1
                    apartEvidenceCounter = 0
                    // Set new state based on evidence amount.
                    state = (letterEvidenceCounter >= evidenceCounterStateTrigger) ? .aslLetterB : .possibleLetter
        }
        else if thumbCorrectForASL_C
                    && indexCirrectForASL_C
        {
                // Keep accumulating evidence for letter C.
                letterEvidenceCounter += 1
                apartEvidenceCounter = 0
                // Set new state based on evidence amount.
                state = (letterEvidenceCounter >= evidenceCounterStateTrigger) ? .aslLetterC : .possibleLetter
        }
        else if pointingUpIndex
                            && pointingUpMiddle == false
                            && pointingUpRing == false
                            && pointingUpLittle == false
                            && thumbAndMiddleCorrectForASL_D
                            && fingersTogetherMiddleRing
                            && fingersTogetherRingLittle
        {
                    // Keep accumulating evidence for letter D.
                    letterEvidenceCounter += 1
                    apartEvidenceCounter = 0
                    // Set new state based on evidence amount.
                    state = (letterEvidenceCounter >= evidenceCounterStateTrigger) ? .aslLetterD : .possibleLetter
        }
        else if thumbAndIndexCorrectForASL_F
                && pointingUpMiddle
                && pointingUpRing
                && pointingUpLittle
        {
                    // Keep accumulating evidence for letter F.
                    letterEvidenceCounter += 1
                    apartEvidenceCounter = 0
                    // Set new state based on evidence amount.
                    state = (letterEvidenceCounter >= evidenceCounterStateTrigger) ? .aslLetterF : .possibleLetter
        }
        else if thumbCorrectForASL_I
                && pointingDownIndex
                && pointingDownMiddle
                && pointingDownRing
                && pointingUpLittle
        {
            // Keep accumulating evidence for letter I.
            letterEvidenceCounter += 1
            apartEvidenceCounter = 0
            // Set new state based on evidence amount.
            state = (letterEvidenceCounter >= evidenceCounterStateTrigger) ? .aslLetterI : .possibleLetter
        }
        else if thumbCorrectForASL_A
                && pointingDownIndex
                && pointingDownMiddle
                && pointingDownRing
                && pointingUpLittle
                && littleFingerCorrectForASL_J
        {
            // Keep accumulating evidence for letter J.
            letterEvidenceCounter += 1
            apartEvidenceCounter = 0
            // Set new state based on evidence amount.
            state = (letterEvidenceCounter >= evidenceCounterStateTrigger) ? .aslLetterJ : .possibleLetter
        }
        else if thumbCorrectForASL_L
                && pointingUpIndex
                && pointingDownMiddle
                && pointingDownRing
                && pointingDownLittle
        {
            // Keep accumulating evidence for letter L.
            letterEvidenceCounter += 1
            apartEvidenceCounter = 0
            // Set new state based on evidence amount.
            state = (letterEvidenceCounter >= evidenceCounterStateTrigger) ? .aslLetterL : .possibleLetter
        }
        else if thumbCorrectForASL_Q
                && indexCorrectForASL_Q
        {
            // Keep accumulating evidence for letter Q.
            pinchEvidenceCounter += 1
            apartEvidenceCounter = 0
            // Set new state based on evidence amount.
            state = (pinchEvidenceCounter >= evidenceCounterStateTrigger) ? .aslLetterQ : .possibleLetter
        }
        else if pointingUpIndex
                && pointingUpMiddle
                && pointingUpRing
                && pointingUpLittle == false
                //&& pointingDownLittle //Finger is getting overlapped by thumb. Very poor recognition
                //&& thumbCorrectForASL_W //Quick recognition but also recognizes letter B. WRONG
                //&& fingersTogetherIndexMiddle == false //No need to check these as this is the only letter where index, middle and ring are up and little is down
        {
            // Keep accumulating evidence for letter W.
            letterEvidenceCounter += 1
            apartEvidenceCounter = 0
            // Set new state based on evidence amount.
            state = (letterEvidenceCounter >= evidenceCounterStateTrigger) ? .aslLetterW : .possibleLetter
        }
        else if thumbCorrectForASL_X
                && indexCorrectForASL_X
                && pointingDownMiddle
                && pointingDownRing
                && pointingDownLittle
        {
            // Keep accumulating evidence for letter X.
            letterEvidenceCounter += 1
            apartEvidenceCounter = 0
            // Set new state based on evidence amount.
            state = (letterEvidenceCounter >= evidenceCounterStateTrigger) ? .aslLetterX : .possibleLetter
        }
        else if thumbCorrectForASL_Y
                && pointingDownIndex
                && pointingDownMiddle
                && pointingDownRing
                && pointingUpLittle
        {
            // Keep accumulating evidence for letter Y.
            letterEvidenceCounter += 1
            apartEvidenceCounter = 0
            // Set new state based on evidence amount.
            state = (letterEvidenceCounter >= evidenceCounterStateTrigger) ? .aslLetterY : .possibleLetter
        }
        
        
     /*   else if distanceIndexMiddle > pinchMaxDistance //all fingers apart. Like signally five
                    && distanceMiddleRing > pinchMaxDistance
                    && distanceRingLittle > pinchMaxDistance
                    && distanceThumbIpIndexMcp > pinchMaxDistance {
                    // Keep accumulating evidence for state spacebar.
                    pinchEvidenceCounter += 1
                    apartEvidenceCounter = 0
                    // Set new state based on evidence amount.
                    state = (pinchEvidenceCounter >= evidenceCounterStateTrigger) ? .spacebar : .possibleLetter
        }   */
        else {
            // Keep accumulating evidence for apart state.
            apartEvidenceCounter += 1
            pinchEvidenceCounter = 0
            // Set new state based on evidence amount.
            state = (apartEvidenceCounter >= evidenceCounterStateTrigger) ? .apart : .possibleApart
        }
    }
    
    // MARK: - Finger position helpers
    
    private func isThumbPointingSideways(pointsSet: PointsSet) -> Bool {
        return isThumbTopPortionPointingSideways(pointsSet: pointsSet) && isThumbBottomPortionPointingSideways(pointsSet: pointsSet)
    }
    
    /*
        Analysis of thumb position for ASL letter R.
     */
    private func isIndexMiddleCorrectForAslR(pointsSet: PointsSet) -> Bool {
        let diffTips = pointsSet.indexTip.x - pointsSet.middleTip.x
        let diffMcps = pointsSet.indexMcp.x - pointsSet.middleMcp.x
        //Can use XOR but no time
        //True if the 2 distances have different signs
        return (diffTips > 0 && diffMcps < 0) || (diffTips < 0 && diffMcps > 0)
    }
    
    /*
        Analysis of thumb position for ASL letter U.
     */
    private func isIndexMiddleCorrectForAslU(pointsSet: PointsSet) -> Bool {
        let diffTips = pointsSet.indexTip.x - pointsSet.middleTip.x
        let diffMcps = pointsSet.indexMcp.x - pointsSet.middleMcp.x
        //Can use XOR but no time
        //True if the 2 distances have same signs
        let greaterZero = (diffTips > 0 && diffMcps > 0)
        let lessZero = (diffTips < 0 && diffMcps < 0)
        return greaterZero || lessZero
    }
    
    /*
        Analysis of thumb position for ASL letter A.
     */
    private func isThumbCorrectForAslA(pointsSet: PointsSet) -> Bool {
        //Is thumb beside index finger
        let thumbBottomPointingUp =  isThumbBottomPortionPointingUp(pointsSet: pointsSet)
        let thumbTopPortionPointingUp = isThumbTopPortionPointingUp(pointsSet: pointsSet)
        let thumbTipWithinPalmRegionX = isThumbWithinPalmXDirection(pointsSet: pointsSet)
        let ret = (!thumbTipWithinPalmRegionX) && thumbBottomPointingUp && thumbTopPortionPointingUp
        
        return ret
    }
    
    /*
        Analysis of thumb position for ASL letter B.
     */
    private func isThumbCorrectForAslB(pointsSet: PointsSet) -> Bool {
        //Is thumb TIP (1st level) close to middle base. Using middle base as it is the highest base
        //Using thumb tip and thumb ip (2nd level) distance as reference
        let distanceThumbTipThumbIp = pointsSet.thumbTip.distance(from: pointsSet.thumbIp)
        let distanceThumbTipMiddleMcp = pointsSet.thumbTip.distance(from: pointsSet.middleMcp)
        let thumbTipCloseToMiddleMcp = distanceThumbTipMiddleMcp < (distanceThumbTipThumbIp/2)
        let thumbBottomPointingUp =  isThumbBottomPortionPointingUp(pointsSet: pointsSet)
        let thumbTopPortionPointingSideways = isThumbTopPortionPointingSideways(pointsSet: pointsSet)
        let thumbTipWithinPalmRegionX = isThumbWithinPalmXDirection(pointsSet: pointsSet)
        let ret = /*thumbTipCloseToMiddleMcp && thumbBottomPointingUp && thumbTopPortionPointingSideways &&*/ thumbTipWithinPalmRegionX
        
        return ret
    }
    
    /*
        Analysis of thumb position for ASL letter C.
     */
    private func isThumbCorrectForAslC(pointsSet: PointsSet) -> Bool {
        let thumbPointingSideways = isThumbPointingSideways(pointsSet: pointsSet)
        return thumbPointingSideways
    }
    
    /*
        Analysis of thumb and index tip distance for ASL letter C.
     */
    private func isThumbAndIndexFingerSpacingCorrectForAslC(pointsSet: PointsSet) -> Bool {
        //Reference distance is distance between thumb tip (1st layer) and thumb IP (2nd layer)
        let distanceThumbTipThumbIp = pointsSet.thumbTip.distance(from: pointsSet.thumbIp)
        let distanceThumbTipIndexTip = pointsSet.thumbTip.distance(from: pointsSet.indexTip)
        let ret = distanceThumbTipIndexTip > distanceThumbTipThumbIp && distanceThumbTipIndexTip < (distanceThumbTipThumbIp*2)
        
        return ret
    }
    
    /*
        Analysis of thumb and middle tip distance for ASL letter D.
     */
    private func isThumbAndMiddleFingerSpacingCorrectForAslD(pointsSet: PointsSet) -> Bool {
        //Reference distance is distance between thumb tip (1st layer) and thumb IP (2nd layer)
        let distanceThumbTipThumbIp = pointsSet.thumbTip.distance(from: pointsSet.thumbIp)
        let distanceThumbTipMiddleTip = pointsSet.thumbTip.distance(from: pointsSet.middleTip)
        let ret = distanceThumbTipMiddleTip < (distanceThumbTipThumbIp/2)
        
        return ret
    }
    
    /*
        Analysis of thumb position for ASL letter E.
     */
    private func isThumbCorrectForAslE(pointsSet: PointsSet) -> Bool {
        //Is thumb TIP (1st level) below finger tips
        //Correction: We will use fingers Dips instead as there is a change thumb tip may overlap finger tips
        let thumbTipIndexDipDY = pointsSet.thumbTip.y - pointsSet.indexDip.y
        let thumbTipBelowIndexDip = thumbTipIndexDipDY > 0
        let thumbTipMiddleDipDY = pointsSet.thumbTip.y - pointsSet.middleDip.y
        let thumbTipBelowMiddleDip = thumbTipMiddleDipDY > 0
        let thumbTipRingDipDY = pointsSet.thumbTip.y - pointsSet.ringDip.y
        let thumbTipBelowRingDip = thumbTipRingDipDY > 0
        let thumbTipLittleDipDY = pointsSet.thumbTip.y - pointsSet.littleDip.y
        let thumbTipBelowLittleDip = thumbTipLittleDipDY > 0
        let thumbBelowFingers = thumbTipBelowMiddleDip && thumbTipBelowRingDip //Thumb tip will usually rest below middle and ring
        let thumbBottomPointingUp =  isThumbBottomPortionPointingUp(pointsSet: pointsSet)
        let thumbTopPortionPointingSideways = isThumbTopPortionPointingSideways(pointsSet: pointsSet)
        let thumbTipWithinPalmRegionX = isThumbWithinPalmXDirection(pointsSet: pointsSet)
        let ret = thumbBelowFingers && thumbTipWithinPalmRegionX //&& thumbBottomPointingUp && thumbTopPortionPointingSideways
        
        return ret
    }
    
    /*
        Analysis of thumb and middle tip distance for ASL letter F.
     */
    private func isThumbAndIndexFingerSpacingCorrectForAslF(pointsSet: PointsSet) -> Bool {
        //Reference distance is distance between thumb tip (1st layer) and thumb IP (2nd layer)
        let distanceThumbTipThumbIp = pointsSet.thumbTip.distance(from: pointsSet.thumbIp)
        let distanceThumbTipIndexTip = pointsSet.thumbTip.distance(from: pointsSet.indexTip)
        let ret = distanceThumbTipIndexTip < (distanceThumbTipThumbIp/2)
        
        return ret
    }
    
    /*
        Analysis of thumb position for ASL letter I.
     */
    private func isThumbCorrectForAslI(pointsSet: PointsSet) -> Bool {
        //Is thumb beside index finger
        let thumbBottomPointingUp =  isThumbBottomPortionPointingUp(pointsSet: pointsSet)
        let thumbTopPortionPointingUp = isThumbTopPortionPointingUp(pointsSet: pointsSet)
        let thumbTipWithinPalmRegionX = isThumbWithinPalmXDirection(pointsSet: pointsSet)
        let ret = thumbTipWithinPalmRegionX //&& thumbBottomPointingUp && thumbTopPortionPointingUp
        
        return ret
    }
    
    /*
        Analysis of thumb and index tip distance for ASL letter K.
     */
    private func isThumbCorrectForAslK(pointsSet: PointsSet) -> Bool {
        let thumbPointingUp = isThumbPointingUp(pointsSet: pointsSet)
        
        let thumbTipX = pointsSet.thumbTip.x
        let middleTipX = pointsSet.middleTip.x //was pip
        let indexTipX = pointsSet.indexTip.x  //was pip
        //Get bounds
        let lowerBoundX = middleTipX < indexTipX ? middleTipX : indexTipX
        let upperBoundX = middleTipX > indexTipX ? middleTipX : indexTipX
        let thumbGreaterThanLowerBound = thumbTipX > lowerBoundX
        let thumbLessThanUpperBound = thumbTipX < upperBoundX
        let thumbTipBetweenMiddleRingX = thumbGreaterThanLowerBound && thumbLessThanUpperBound
        let ret = thumbPointingUp && thumbTipBetweenMiddleRingX
        return ret
    }
    
    /*
        Analysis of thumb and index tip distance for ASL letter N.
     */
    private func isThumbCorrectForAslN(pointsSet: PointsSet) -> Bool {
        let thumbTipX = pointsSet.thumbTip.x
        let middlePipX = pointsSet.middlePip.x
        let littlePipX = pointsSet.littlePip.x //Using little instead of ring as there is a chance thumb tip will overlap with ring
        //Get bounds
        let lowerBoundX = middlePipX < littlePipX ? middlePipX : littlePipX
        let upperBoundX = middlePipX > littlePipX ? middlePipX : littlePipX
        let thumbGreaterThanLower = thumbTipX > lowerBoundX
        let thumbLessThanUpper = thumbTipX < upperBoundX
        let thumbTipBetweenMiddleLittle = thumbGreaterThanLower && thumbLessThanUpper
        
        let thumbTipY = pointsSet.thumbTip.y
        let middlePipY = pointsSet.middlePip.y
        let ringTipY = pointsSet.ringTip.y
        let thumbTipOverRing =  thumbTipY < ringTipY //Using ring tip instead of ring dip/pip because there are issues with recognition. The thumb tips recognition dot lowers when the thumb is straightened
        let ret = thumbTipBetweenMiddleLittle && thumbTipOverRing
        
        return ret
    }
    
    /*
        Analysis of thumb and index tip distance for ASL letter O.
     */
    private func isThumbAndIndexFingerSpacingCorrectForAslO(pointsSet: PointsSet) -> Bool {
        //Reference distance is distance between thumb tip (1st layer) and thumb IP (2nd layer)
        let distanceThumbTipThumbIp = pointsSet.thumbTip.distance(from: pointsSet.thumbIp)
        let distanceThumbTipIndexTip = pointsSet.thumbTip.distance(from: pointsSet.indexTip)
        let ret = distanceThumbTipIndexTip < distanceThumbTipThumbIp
        
        return ret
    }
    
    /*
        Analysis of thumb for ASL letter P.
     */
    private func isThumbCorrectForAslP(pointsSet: PointsSet) -> Bool {
        let topSectionDY = pointsSet.thumbTip.y - pointsSet.thumbIp.y
        let topSectionPointingDownNotUp = topSectionDY > 0
        let topSectionDX = pointsSet.thumbTip.x - pointsSet.thumbIp.x
        let topSectionPointingVerticalNotHorizontal = abs(topSectionDY) > abs(topSectionDX) //This is not working. DY < DX even when vertical
        let topSectionPointingDown = topSectionPointingDownNotUp //&& topSectionPointingVerticalNotHorizontal
        let middleSectionDY = pointsSet.thumbIp.y - pointsSet.thumbMp.y
        let middleSectionPointingDownNotUp = middleSectionDY > 0
        let middleSectionDX = pointsSet.thumbIp.x - pointsSet.thumbMp.x
        let middleSectionPointingVerticalNotHorizontal = abs(middleSectionDY) > abs(middleSectionDX) //This is not working. DY < DX even when vertical
        let middleSectionPointingDown = middleSectionPointingDownNotUp //&& middleSectionPointingVerticalNotHorizontal
        let ret = topSectionPointingDown && middleSectionPointingDown
        
        return ret
    }
    
    /*
        Analysis of thumb and index tip distance for ASL letter S. 
     */
    private func isThumbCorrectForAslS(pointsSet: PointsSet) -> Bool {
        /*
        let thumbTopPortionSideways = isThumbTopPortionPointingSideways(pointsSet: pointsSet)
        //Reference distance is distance between thumb tip (1st layer) and thumb IP (2nd layer)
        //Aim is to ensure that thumb is close to finger DIPS
        let distanceThumbTipThumbIp = pointsSet.thumbTip.distance(from: pointsSet.thumbIp)
        let distanceThumbTipIndexDip = pointsSet.thumbTip.distance(from: pointsSet.indexDip)
        let distanceThumbTipMiddleDip = pointsSet.thumbTip.distance(from: pointsSet.middleDip)
        let thumbOnIndexOrMiddleDip = (distanceThumbTipIndexDip < (distanceThumbTipThumbIp/2)) || (distanceThumbTipMiddleDip < (distanceThumbTipThumbIp/2))
        
        let thumbTipIndexTipDY = pointsSet.thumbTip.y - pointsSet.indexTip.y
        let thumbTipMiddleTipDY = pointsSet.thumbTip.y - pointsSet.middleTip.y
        let thumbTipRingTipDY = pointsSet.thumbTip.y - pointsSet.ringTip.y
        let thumbTipLittleTipDY = pointsSet.thumbTip.y - pointsSet.littleTip.y
        let thumbTipIndexPipDY = pointsSet.thumbTip.y - pointsSet.indexPip.y
        let thumbTipMiddlePipDY = pointsSet.thumbTip.y - pointsSet.middlePip.y
        let thumbTipRingPipDY = pointsSet.thumbTip.y - pointsSet.ringPip.y
        let thumbTipLittlePipDY = pointsSet.thumbTip.y - pointsSet.littlePip.y
        //Must be between TIP and PIP (3rd level)
        let thumbTipAboveFingerTips = thumbTipIndexTipDY < 0 && thumbTipMiddleTipDY < 0 && thumbTipRingTipDY < 0 && thumbTipLittleTipDY < 0
        let thumbTipBelowFingerPips = thumbTipIndexPipDY > 0 && thumbTipMiddlePipDY > 0 && thumbTipRingPipDY > 0 && thumbTipLittlePipDY > 0
        let thumbTipBetweenTipsAndPips = thumbTipAboveFingerTips && thumbTipBelowFingerPips
        */
        let thumbTipWithinPalmRegionX = isThumbWithinPalmXDirection(pointsSet: pointsSet)

        let ret =  thumbTipWithinPalmRegionX //&& thumbTopPortionSideways && thumbTipBetweenTipsAndPips
        
        return ret
    }
    
    /*
        Analysis of thumb correct for ASL letter T.
     */
    private func isThumbCorrectForAslT(pointsSet: PointsSet) -> Bool {
        let thumbTipX = pointsSet.thumbTip.x
        let indexPipX = pointsSet.indexPip.x
        let middlePipX = pointsSet.middlePip.x
        //Get bounds
        let lowerBoundX = indexPipX < middlePipX ? indexPipX : middlePipX
        let upperBoundX = indexPipX > middlePipX ? indexPipX : middlePipX
        let thumbBetweenIndexMiddle = thumbTipX > lowerBoundX && thumbTipX < upperBoundX
        
        let thumbTipY = pointsSet.thumbTip.y
        let middlePipY = pointsSet.middlePip.y
        let ringTipY = pointsSet.ringTip.y
        let thumbTipOverRing =  thumbTipY < ringTipY //Using ring tip instead of ring dip/pip because there are issues with recognition. The thumb tips recognition dot lowers when the thumb is straightened
        let ret = thumbBetweenIndexMiddle && thumbTipOverRing
        
        return ret
    }
    
    /*
        Analysis of thumb for ASL letter U and V and R.
     */
    private func isThumbCorrectForAslU(pointsSet: PointsSet) -> Bool {
        //Reference distance is distance between thumb tip (1st layer) and thumb MP (3rd layer)
        let distanceThumbTipThumbMp = pointsSet.thumbTip.distance(from: pointsSet.thumbMp)
        let distanceThumbTipRingPip = pointsSet.thumbTip.distance(from: pointsSet.ringPip)
        let ret = distanceThumbTipRingPip < distanceThumbTipThumbMp
        return ret
    }
    
    /*
        Analysis of thumb for ASL letter W.
     */
    private func isThumbCorrectForAslW(pointsSet: PointsSet) -> Bool {
        //Reference distance is distance between thumb tip (1st layer) and thumb IP (2nd layer)
        //Not using little tip or little dip(2nd layer) as there is a chance those will get covered by the thumn
        let distanceThumbTipThumbIp = pointsSet.thumbTip.distance(from: pointsSet.thumbIp)
        let distanceThumbTipLittlePip = pointsSet.thumbTip.distance(from: pointsSet.littlePip)
        let ret = distanceThumbTipLittlePip < distanceThumbTipThumbIp
        
        return ret
    }
    
    /*
        Analysis of thumb for ASL letter X.
     */
    private func isThumbCorrectForAslX(pointsSet: PointsSet) -> Bool {
        let thumbWithinPalmXDirection = isThumbWithinPalmXDirection(pointsSet: pointsSet)
        let ret = thumbWithinPalmXDirection //thumbTopPortionSideways && thumbOnMiddleDip
        
        return ret
    }
    
    /*
        Analysis of thumb for ASL letter Y.
     */
    private func isThumbPointingSidewaysAndAwayFromPalm(pointsSet: PointsSet) -> Bool {
        //Reference distance is distance between thumb tip (1st layer) and thumb IP (2nd layer)
        let thumbPointingSideways = isThumbPointingSideways(pointsSet: pointsSet)
        let thumbWithinPalmXDirection = isThumbWithinPalmXDirection(pointsSet: pointsSet)
        let ret = thumbPointingSideways && !thumbWithinPalmXDirection
        
        return ret
    }
    
    /*
        Making sure it is perfectly horizontal. Applicable to G and other letters
     */
    private func isFingerPointingSideways(pointsSet: PointsSet, finger: Finger) -> Bool {
        let tip = finger == Finger.INDEX ? pointsSet.indexTip :
                            finger == Finger.MIDDLE ? pointsSet.middleTip :
                            finger == Finger.RING ? pointsSet.ringTip :
                                                        pointsSet.littleTip
        let dip = finger == Finger.INDEX ? pointsSet.indexDip :
                            finger == Finger.MIDDLE ? pointsSet.middleDip :
                            finger == Finger.RING ? pointsSet.ringDip :
                                                        pointsSet.littleDip
        let pip = finger == Finger.INDEX ? pointsSet.indexPip :
                    finger == Finger.MIDDLE ? pointsSet.middlePip :
                    finger == Finger.RING ? pointsSet.ringPip :
                                                pointsSet.littlePip
        let mcp = finger == Finger.INDEX ? pointsSet.indexMcp :
                    finger == Finger.MIDDLE ? pointsSet.middleMcp :
                    finger == Finger.RING ? pointsSet.ringMcp :
                                                pointsSet.littleMcp
        //Tip - dip is used as reference distance as it is the shortest. This is used to ensure the finger is indeed pointing outwards
        let distanceTipDip = tip.distance(from: dip)
        
        let bottomSectionDY = pip.y - mcp.y
        let bottomSectionDX = pip.x - mcp.x
        let distancePipMcp = pip.distance(from: mcp)
        let bottomSectionPointingSideNotUpOrDown = abs(bottomSectionDY) < abs(bottomSectionDX)
        let bottomSectionPointingOutNotCurledIn = distancePipMcp >= distanceTipDip
        let middleSectionDY = dip.y - pip.y
        let middleSectionDX = dip.x - pip.x
        let distanceDipPip = dip.distance(from: pip)
        let middleSectionPointingSideNotUpOrDown = abs(middleSectionDY) < abs(middleSectionDX)
        let middleSectionPointingOutNotCurledIn = distanceDipPip >= distanceTipDip
        //let ret = (bottomSectionPointingSideNotUpOrDown && bottomSectionPointingOutNotCurledIn) && (middleSectionPointingSideNotUpOrDown && middleSectionPointingOutNotCurledIn)
        let ret = bottomSectionPointingSideNotUpOrDown && middleSectionPointingSideNotUpOrDown
        
        return ret
    }
    
    /*
        Analysis of index finger for ASL C.
     */
    private func isIndexFingerCorrectForAslC(pointsSet: PointsSet) -> Bool {
        let dip = pointsSet.indexDip
        let pip = pointsSet.indexPip
        let mcp = pointsSet.indexMcp
        let middleSectionDY = dip.y - pip.y
        let middleSectionDX = dip.x - pip.x
        let middleSectionPointingSideNotUpOrDown = abs(middleSectionDY) < abs(middleSectionDX)
        let ret = middleSectionPointingSideNotUpOrDown
        return ret
    }

    
    /*
        Analysis of index finger for ASL letter X.
     */
    private func isIndexFingerCorrectForAslX(pointsSet: PointsSet) -> Bool {
        let bottomSectionDY = pointsSet.indexPip.y - pointsSet.indexMcp.y
        let bottomSectionPointingUpNotDown = bottomSectionDY < 0
        let bottomSectionDX = pointsSet.indexPip.x - pointsSet.indexMcp.x
        let bottomSectionPointingUpNotSide = abs(bottomSectionDY) > abs(bottomSectionDX)
        let bottomSectionPointUp = bottomSectionPointingUpNotDown && bottomSectionPointingUpNotSide
        let middleSectionDY = pointsSet.indexDip.y - pointsSet.indexPip.y
        let middleSectionPointingUpNotDown = middleSectionDY < 0
        let middleSectionDX = pointsSet.indexDip.x - pointsSet.indexPip.x
        let middleSectionPointingSideNotUp = abs(middleSectionDY) < abs(middleSectionDX)
        let middleSectionPointingSideUp = middleSectionPointingUpNotDown && middleSectionPointingSideNotUp
        let ret = bottomSectionPointUp && middleSectionPointingSideUp
        return ret
    }
    
    /*
        Analysis of middle finger for ASL letter P.
     */
    private func isMiddleFingerCorrectForAslP(pointsSet: PointsSet) -> Bool {
        let bottomSectionDY = pointsSet.middlePip.y - pointsSet.middleMcp.y
        let bottomSectionPointingDownNotUp = bottomSectionDY > 0
        let bottomSectionDX = pointsSet.middlePip.x - pointsSet.middleMcp.x
        let bottomSectionPointingVerticalNotHorizontal = abs(bottomSectionDY) > abs(bottomSectionDX)
        let bottomSectionPointDown = bottomSectionPointingDownNotUp && bottomSectionPointingVerticalNotHorizontal
        let middleSectionDY = pointsSet.middleDip.y - pointsSet.middlePip.y
        let middleSectionPointingDownNotUp = middleSectionDY > 0
        let middleSectionDX = pointsSet.middleDip.x - pointsSet.middlePip.x
        let middleSectionPointingVerticalNotHorizontal = abs(middleSectionDY) > abs(middleSectionDX)
        let middleSectionPointingDown = middleSectionPointingDownNotUp && middleSectionPointingVerticalNotHorizontal
        let ret = bottomSectionPointDown && middleSectionPointingDown
        
        return ret
    }
    
    /*
        Analysis of little finger for ASL letter J. Little finger must be facing to the side
     */
    private func isLittleFingerCorrectForAslJ(pointsSet: PointsSet) -> Bool {
        let dy = pointsSet.littlePip.y - pointsSet.littleMcp.y
        let pointingUpNotDown = dy < 0
        let dx = pointsSet.littlePip.x - pointsSet.littleMcp.x
        let pointingSideNotUp = abs(dy) < abs(dx)
        let ret = pointingUpNotDown && pointingSideNotUp
        
        return ret
    }
    
    private func isThumbWithinPalmXDirection(pointsSet: PointsSet) -> Bool {
        let thumbMpX = pointsSet.thumbMp.x
        let littleFingerX = pointsSet.littleMcp.x
        
        //Index can be either less or greater depending on left or right hand being used
        let lowerBoundX = thumbMpX < littleFingerX ? thumbMpX : littleFingerX
        let upperBoundX = thumbMpX > littleFingerX ? thumbMpX : littleFingerX
        let withinLowerBound = pointsSet.thumbTip.x >= lowerBoundX
        let withinUpperBound = pointsSet.thumbTip.x <= upperBoundX
        let thumbTipWithinPalm = withinLowerBound && withinUpperBound
        return thumbTipWithinPalm
    }
    
    /*
        Are the four fingers facing upwards
     */
    private func areFourFingersPointingUp(pointsSet: PointsSet) -> Bool {
        let ret =
                    isFingerPointingUp(finger: Finger.INDEX, pointsSet: pointsSet)
                            && isFingerPointingUp(finger: Finger.MIDDLE, pointsSet: pointsSet)
                            && isFingerPointingUp(finger: Finger.RING, pointsSet: pointsSet)
                            && isFingerPointingUp(finger: Finger.LITTLE, pointsSet: pointsSet)
        return ret
                
    }
    
    private func isThumbPointingUp(pointsSet: PointsSet) -> Bool {
        let ret =
            isThumbTopPortionPointingUp(pointsSet: pointsSet)
                            && isThumbBottomPortionPointingUp(pointsSet: pointsSet)
        return ret
    }
    
    
    private func isThumbTopPortionPointingUp(pointsSet: PointsSet) -> Bool {
        let tip = pointsSet.thumbTip
        let ip = pointsSet.thumbIp
        let dy = tip.y - ip.y
        let pointingUpNotDown = dy < 0
        let dx = tip.x - ip.x
        let pointingUpNotSide = abs(dy) > abs(dx)
        return pointingUpNotDown && pointingUpNotSide
    }
    
    private func isThumbTopPortionPointingSideways(pointsSet: PointsSet) -> Bool {
        let tip = pointsSet.thumbTip
        let ip = pointsSet.thumbIp
        let dy = tip.y - ip.y
        let dx = tip.x - ip.x
        let pointingSideNotUp = abs(dy) < abs(dx)
        return pointingSideNotUp
    }
    
    private func isThumbBottomPortionPointingUp(pointsSet: PointsSet) -> Bool {
        let ip = pointsSet.thumbIp
        let mp = pointsSet.thumbMp
        let dy = ip.y - mp.y
        let pointingUpNotDown = dy < 0
        let dx = ip.x - mp.x
        let pointingUpNotSide = abs(dy) > abs(dx)
        return pointingUpNotDown && pointingUpNotSide
    }
    
    private func isThumbBottomPortionPointingSideways(pointsSet: PointsSet) -> Bool {
        let ip = pointsSet.thumbIp
        let mp = pointsSet.thumbMp
        let dy = ip.y - mp.y
        let pointingUpNotDown = dy < 0
        let dx = ip.x - mp.x
        let pointingSideNotUp = abs(dx) > abs(dy)
        return pointingUpNotDown && pointingSideNotUp
    }
    
    /*
        Applies to the four fingers only
     */
    private func isFingerPointingUp(finger: Finger, pointsSet: PointsSet) -> Bool {
        let pip = finger == Finger.INDEX ? pointsSet.indexPip :
                    finger == Finger.MIDDLE ? pointsSet.middlePip :
                    finger == Finger.RING ? pointsSet.ringPip :
                                                pointsSet.littlePip
        let dip = finger == Finger.INDEX ? pointsSet.indexDip :
                    finger == Finger.MIDDLE ? pointsSet.middleDip :
                    finger == Finger.RING ? pointsSet.ringDip :
                                                pointsSet.littleDip
        let dy = dip.y - pip.y
        let pointingUpNotDown = dy < 0
        let dx = dip.x - pip.x
        let pointingUpNotSide = abs(dy) > abs(dx)
        return pointingUpNotDown && pointingUpNotSide
    }
    
    /*
        Four fingers are pointing down but not touching the palm
     */
    private func areFourFingersPointingDown(pointsSet: PointsSet) -> Bool {
        let ret =
                    isFingerPointingDown(finger: Finger.INDEX, pointsSet: pointsSet)
                            && isFingerPointingDown(finger: Finger.MIDDLE, pointsSet: pointsSet)
                            && isFingerPointingDown(finger: Finger.RING, pointsSet: pointsSet)
                            && isFingerPointingDown(finger: Finger.LITTLE, pointsSet: pointsSet)
        return ret
                
    }
    
    private func isFingerPointingDown(finger: Finger, pointsSet: PointsSet) -> Bool {
        let base =  finger == Finger.THUMB ? pointsSet.thumbCmc :
                    finger == Finger.INDEX ? pointsSet.indexMcp :
                    finger == Finger.MIDDLE ? pointsSet.middleMcp :
                    finger == Finger.RING ? pointsSet.ringMcp :
                                                pointsSet.littleMcp
        let third = finger == Finger.THUMB ? pointsSet.thumbMp :
                    finger == Finger.INDEX ? pointsSet.indexPip :
                    finger == Finger.MIDDLE ? pointsSet.middlePip :
                    finger == Finger.RING ? pointsSet.ringPip :
                                                pointsSet.littlePip
        let second =    finger == Finger.THUMB ? pointsSet.thumbIp :
                        finger == Finger.INDEX ? pointsSet.indexDip :
                        finger == Finger.MIDDLE ? pointsSet.middleDip :
                        finger == Finger.RING ? pointsSet.ringDip :
                                                    pointsSet.littleDip
        let tip =   finger == Finger.THUMB ? pointsSet.thumbTip :
                    finger == Finger.INDEX ? pointsSet.indexTip :
                    finger == Finger.MIDDLE ? pointsSet.middleTip :
                    finger == Finger.RING ? pointsSet.ringTip :
                                                pointsSet.littleTip
        let middlePortionPointingDown = (second.y - third.y) > 0
        let tipDipDY = tip.y - second.y
        let tipDipDX = tip.x - second.x
        let topPortionPointingDown = tipDipDY > 0 && tipDipDY >= tipDipDX
        
        return topPortionPointingDown //&& middlePortionPointingDown
    }
    
    private func isThumbAndIndexFingerCurlingTowardsEachOther(pointsSet: PointsSet) -> Bool {
        let indexFingerCurledForward = isFingerCurledForward(pointsSet: pointsSet, finger: Finger.INDEX)
        //let littleFingerCurledForward = isFingerCurledForward(pointsSet: pointsSet, finger: Finger.LITTLE)
        let thumbBottomPortionPointingSideways = isThumbBottomPortionPointingSideways(pointsSet: pointsSet)
        return indexFingerCurledForward && thumbBottomPortionPointingSideways
    }
    
    /*
        Only applies to the four fingers
     */
    private func isFingerCurledForward(pointsSet: PointsSet, finger: Finger) -> Bool {
        //is index finger curling forward in triangle shape
        let center = finger == Finger.INDEX ? pointsSet.indexPip :
                        finger == Finger.MIDDLE ? pointsSet.middlePip :
                        finger == Finger.RING ? pointsSet.ringPip :
                                                        pointsSet.littlePip
        let tip = finger == Finger.INDEX ? pointsSet.indexTip :
                    finger == Finger.MIDDLE ? pointsSet.middleTip :
                    finger == Finger.RING ? pointsSet.ringTip :
                                                    pointsSet.littleTip
        let dip = finger == Finger.INDEX ? pointsSet.indexDip :
                    finger == Finger.MIDDLE ? pointsSet.middleDip :
                    finger == Finger.RING ? pointsSet.ringDip :
                                                    pointsSet.littleDip
        let pip = finger == Finger.INDEX ? pointsSet.indexPip :
                    finger == Finger.MIDDLE ? pointsSet.middlePip :
                    finger == Finger.RING ? pointsSet.ringPip :
                                                    pointsSet.littlePip
        let mcp = finger == Finger.INDEX ? pointsSet.indexMcp :
                    finger == Finger.MIDDLE ? pointsSet.middleMcp :
                    finger == Finger.RING ? pointsSet.ringMcp :
                                                    pointsSet.littleMcp
        //let v1 = CGVector(dx: dip.x - center.x, dy: dip.y - center.y)
        //let v2 = CGVector(dx: mcp.x - center.x, dy: mcp.y - center.y)
        //let angle = atan2(v2.dy, v2.dx) - atan2(v1.dy, v1.dx) //radians
        //let degrees = abs ( angle * CGFloat(180.0 / Double.pi) ) //degrees
        //let isfingerArched = degrees > 140 && degrees < 180
     /*   let absDiffTipYMcpY = abs(tip.y - mcp.y)
        let distanceTipMcp = tip.distance(from: mcp)
        let distancePipMcp = pip.distance(from: mcp)
        let tipAndBaseSameLineY = absDiffTipYMcpY < 40
        let fingerTipAwayFromFingerBase =  distanceTipMcp >= (distancePipMcp*1.5)
        let isFingerArchedForward = tipAndBaseSameLineY && fingerTipAwayFromFingerBase
        return isFingerArchedForward    */
        let indexPointingDown = isFingerPointingDown(finger: Finger.INDEX, pointsSet: pointsSet)
        //Reference distance is index base to index PIP (3rd level)
        let distanceIndexPipMcp = pointsSet.indexPip.distance(from: pointsSet.indexMcp)
        let distanceIndexTipMcp = pointsSet.indexTip.distance(from: pointsSet.indexMcp)
        let tipFarFromMcp = distanceIndexTipMcp > distanceIndexPipMcp && distanceIndexTipMcp < (distanceIndexPipMcp*2.5)
        return indexPointingDown && tipFarFromMcp
    }
    
    /*
        Needs to be looked at again
     */
    private func areFourFingersTouchingPalm(pointsSet: PointsSet) -> Bool {
        //Distance from thumb CMC(base)
        let distanceThumbCmcIndexTip = pointsSet.thumbCmc.distance(from: pointsSet.indexTip)
        let distanceThumbCmcMiddleTip = pointsSet.thumbCmc.distance(from: pointsSet.middleTip)
        
        //If index and middle fingers are down, other fingers will also be down
        return distanceThumbCmcIndexTip < (pinchMaxDistance*2)  //Fingers should be touching the palm
                && distanceThumbCmcMiddleTip < (pinchMaxDistance*2)
    }

    /*
        Not in use as logic for 2 fingers hasnt been figured out.
     */
    private func areFourFingersTogether(pointsSet: PointsSet) -> Bool {
        let indexMiddleTouching = areTwoFingersTogether(pointsSet: pointsSet, finger1: Finger.INDEX, finger2: Finger.MIDDLE)
        let middleRingTouching = areTwoFingersTogether(pointsSet: pointsSet, finger1: Finger.MIDDLE, finger2: Finger.RING)
        let ringLittleTouching = areTwoFingersTogether(pointsSet: pointsSet, finger1: Finger.RING, finger2: Finger.LITTLE)
        let ret = indexMiddleTouching && middleRingTouching && ringLittleTouching
        
        return ret
    }
    
    /*
        Only applicable for the 4 main fingers
     
     */
    private func areTwoFingersTogether(pointsSet: PointsSet, finger1: Finger, finger2: Finger) -> Bool {
        if finger1 == finger2 { return true }
       /* let angle : CGFloat = angleBetweenTwoFingersInDegrees(pointsSet: pointsSet, finger1: finger1, finger2: finger2)
        let isTouching = angle < 10
        let ret = isTouching  */
        let finger1Tip = finger1 == Finger.INDEX ? pointsSet.indexTip :
                            finger1 == Finger.MIDDLE ? pointsSet.middleTip :
                            finger1 == Finger.RING ? pointsSet.ringTip :
                                                        pointsSet.littleTip
        let finger2Tip = finger2 == Finger.INDEX ? pointsSet.indexTip :
                            finger2 == Finger.MIDDLE ? pointsSet.middleTip :
                            finger2 == Finger.RING ? pointsSet.ringTip :
                                                        pointsSet.littleTip
        let absDiffXTips = abs(finger1Tip.x - finger2Tip.x)
        
        let finger1Mcp = finger1 == Finger.INDEX ? pointsSet.indexMcp :
                            finger1 == Finger.MIDDLE ? pointsSet.middleMcp :
                            finger1 == Finger.RING ? pointsSet.ringMcp :
                                                        pointsSet.littleMcp
        let finger2Mcp = finger2 == Finger.INDEX ? pointsSet.indexMcp :
                            finger2 == Finger.MIDDLE ? pointsSet.middleMcp :
                            finger2 == Finger.RING ? pointsSet.ringMcp :
                                                        pointsSet.littleMcp
        let absDiffXMcps = abs(finger1Mcp.x - finger2Mcp.x)
        let fingersTogether = absDiffXTips <= (absDiffXMcps*1.2)
        
        return fingersTogether
    }
    
    
    private func angleBetweenTwoFingersInDegrees(pointsSet: PointsSet, finger1: Finger, finger2: Finger) -> CGFloat {
        //Base of finger
      /*  let center = finger1 == Finger.THUMB ? pointsSet.thumbCmc :
                        finger1 == Finger.INDEX ? pointsSet.indexMcp :
                        finger1 == Finger.MIDDLE ? pointsSet.middleMcp :
                        finger1 == Finger.RING ? pointsSet.ringMcp :
                                                        pointsSet.littleMcp */
        let center = pointsSet.wrist
        let p1 = finger1 == Finger.THUMB ? pointsSet.thumbTip :
                    finger1 == Finger.INDEX ? pointsSet.indexTip :
                    finger1 == Finger.MIDDLE ? pointsSet.middleTip :
                    finger1 == Finger.RING ? pointsSet.ringTip :
                                                    pointsSet.littleTip
        let p2 = finger2 == Finger.THUMB ? pointsSet.thumbTip :
                    finger2 == Finger.INDEX ? pointsSet.indexTip :
                    finger2 == Finger.MIDDLE ? pointsSet.middleTip :
                    finger2 == Finger.RING ? pointsSet.ringTip :
                                                    pointsSet.littleTip
        let v1 = CGVector(dx: p1.x - center.x, dy: p1.y - center.y)
        let v2 = CGVector(dx: p2.x - center.x, dy: p2.y - center.y)
        let angle = atan2(v2.dy, v2.dx) - atan2(v1.dy, v1.dx) //radians
        let degrees = abs ( angle * CGFloat(180.0 / Double.pi) ) //degrees
        return degrees
    }
    
}



// MARK: - CGPoint helpers

extension CGPoint {

    static func midPoint(p1: CGPoint, p2: CGPoint) -> CGPoint {
        return CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
    }
    
    func distance(from point: CGPoint) -> CGFloat {
        return hypot(point.x - x, point.y - y)
    }
}

