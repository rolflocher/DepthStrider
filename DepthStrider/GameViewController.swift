//
//  GameViewController.swift
//  DepthStrider
//
//  Created by Rolf Locher on 3/2/20.
//  Copyright © 2020 Rolf Locher. All rights reserved.
//

import UIKit
import QuartzCore
import SceneKit
import Firebase

class GameViewController: UIViewController {
    
    @IBOutlet var scnView: SCNView!
    
    @IBOutlet var pauseMenu: UIVisualEffectView!
    
    @IBOutlet var spectateLabel: UILabel!
    
    @IBOutlet var continueLabel: UILabel!
    
    @IBOutlet var pauseImage: UIImageView!
    
    var db: Firestore? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        
        db = Firestore.firestore()
        
        // create a new scene
        let scene = SCNScene(named: "art.scnassets/ship.scn")!
        
        // create and add a light to the scene
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light!.type = .omni
        lightNode.position = SCNVector3(x: 0, y: 10, z: 10)
        scene.rootNode.addChildNode(lightNode)
        
        // create and add an ambient light to the scene
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light!.type = .ambient
        ambientLightNode.light!.color = UIColor.darkGray
        scene.rootNode.addChildNode(ambientLightNode)
        
        // retrieve the ship node
        let ship = scene.rootNode.childNode(withName: "ship", recursively: true)!
        ship.opacity = 0
        // create and add a camera to the scene
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        ship.addChildNode(cameraNode)
        // place the camera
        cameraNode.position = SCNVector3(x: 0, y: 28, z: 15)
        cameraNode.camera!.zFar = 400
        // animate the 3d object
//        ship.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: 2, z: 0, duration: 1)))
        
        // retrieve the SCNView
//        let scnView = self.view as! SCNView
        
        // set the scene to the view
        scene.fogEndDistance = 400
        scene.fogStartDistance = 300
        scnView.scene = scene
        // allows the user to manipulate the camera
        scnView.allowsCameraControl = false
        
        // show statistics such as fps and timing information
        scnView.showsStatistics = false
        
        // configure the view
        scnView.backgroundColor = UIColor.black
        
        let pauseTap = UITapGestureRecognizer(target: self, action: #selector(pauseTapped))
        pauseImage.addGestureRecognizer(pauseTap)
        pauseImage.isUserInteractionEnabled = true
        
        let continueTap = UITapGestureRecognizer(target: self, action: #selector(continueTapped))
        continueLabel.addGestureRecognizer(continueTap)
        continueLabel.isUserInteractionEnabled = true
        
        let spectateTap = UITapGestureRecognizer(target: self, action: #selector(spectateTapped))
        spectateLabel.addGestureRecognizer(spectateTap)
        spectateLabel.isUserInteractionEnabled = true
        
        let flyTap = UIPanGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        scnView.addGestureRecognizer(flyTap)
        scnView.isUserInteractionEnabled = true
        
        //startFlying()
        startSpectating()
        watchFrames()
    }
    
    @objc func continueTapped() {
        UIView.animate(withDuration: 1, animations: {
            self.pauseMenu.alpha = 0
        }) { (_) in
            self.pauseMenu.isHidden = true
        }
        let ship = scnView.scene!.rootNode.childNode(withName: "ship", recursively: true)!
        fadeInNode(node: ship, finalOpacity: 1, duration: 2)
        startFlying()
    }
    
    @objc func spectateTapped() {
        UIView.animate(withDuration: 1, animations: {
            self.pauseMenu.alpha = 0
        }) { (_) in
            self.pauseMenu.isHidden = true
        }
        startSpectating()
    }
    
    @objc func pauseTapped() {
        UIView.animate(withDuration: 1) {
            self.pauseMenu.isHidden = false
            self.pauseMenu.alpha = 1
        }
    }
    
    func startFlying() {
        let ship = scnView.scene!.rootNode.childNode(withName: "ship", recursively: true)!
        //let action = SCNAction.move(to: <#T##SCNVector3#>, duration: <#T##TimeInterval#>)
        fadeInNode(node: ship, finalOpacity: 1, duration: 3)
        shouldStopFollowingFrames = true
    }
    
    func startSpectating() {
        let ship = scnView.scene!.rootNode.childNode(withName: "ship", recursively: true)!
        let action = SCNAction.fadeOut(duration: 3)
        ship.runAction(action)
        if shouldStopFollowingFrames {
            shouldStopFollowingFrames = false
            followFrames()
        }
    }
    
    var shouldStopFollowingFrames = true
    
    func followFrames() {
        if shouldStopFollowingFrames { return }
        
        if currentCenters.count > visibleFrames {
            let ship = scnView.scene!.rootNode.childNode(withName: "ship", recursively: true)!
            var ref = ship.position
            ref.x = currentCenters.first!
            let action = SCNAction.move(to: ref, duration: 1)
            ship.runAction(action)
        }
        DispatchQueue.main.asyncAfter(deadline: .now()+5) {
            self.followFrames()
        }
    }
    
    func loadFrames() {
        
    }
    
    var lastContour: [CGPoint]? = nil
    
    var currentCenters = [Float]()
    var visibleFrames = Int()
    
    func watchFrames() {
        lastContour = nil
        db?.collection("depth").order(by: "timestamp", descending: true).limit(to: 1).addSnapshotListener({ (snapshot, error) in
            guard let snap = snapshot,
                let doc = snap.documents.first
            else { return }
            
            let distance: Float = 400.0
            let duration = 64.0
            self.visibleFrames = Int(duration/5)
            
            if self.currentCenters.count > self.visibleFrames {
                
            }
            
            let newContour = self.buildContour(doc: doc.data())
            if let lastContour = self.lastContour {
                let node = self.buildBandNode(firstContour: newContour, secondContour: lastContour)
                node.position = SCNVector3Make(0, 0, -distance)
                self.moveFrame(node: node, distance: Double(distance+40), duration: duration)
                self.fadeInNode(node: node, finalOpacity: 0.7, duration: 3)
                self.removeFrameAfter(node: node, duration: duration)
                self.scnView.scene?.rootNode.addChildNode(node)
            }
            self.lastContour = newContour
        })
    }
    
    func removeFrameAfter(node: SCNNode, duration dur: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + dur) {
            node.removeFromParentNode()
        }
    }
    
    func fadeInNode(node: SCNNode, finalOpacity: Float, duration dur: Double) {
        node.opacity = 0
        let action1 = SCNAction.fadeOpacity(to: CGFloat(finalOpacity), duration: dur)
        action1.timingMode = .linear
        node.runAction(action1)
    }
    
    func moveFrame(node: SCNNode, distance: Double, duration dur: TimeInterval) {
        let action = SCNAction.move(by: SCNVector3(0, 0, distance), duration: dur)
        action.timingMode = .linear
        node.runAction(action)
    }
    
    func buildBandNode(firstContour first: [CGPoint], secondContour second: [CGPoint]) -> SCNNode {
        let isFirstMax = first.count > second.count
        let max = isFirstMax ? first.count : second.count
        
        var vertices = [SCNVector3]()
        var indices = [UInt16]()
        var elements = [SCNGeometryElement]()
        var sources = [SCNGeometrySource]()
        var count: UInt16 = 0
        for index in 0..<max {
            if index != 0 {
                vertices.append(contentsOf: [
                    SCNVector3(first[index].x, first[index].y, -40),
                    SCNVector3(second[index].x, second[index].y, 0),
                    SCNVector3(first[index-1].x, first[index-1].y, -40),
                    SCNVector3(second[index-1].x, second[index-1].y, 0),
                ])
                indices.append(contentsOf: [
                    count+0, count+1, count+3,
                    count+0, count+3, count+2
                ])
                count += 4
            }
            
        }
        
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let source = SCNGeometrySource(vertices: vertices)
        elements.append(element)
        sources.append(source)
        let geometry = SCNGeometry(sources: sources, elements: elements)
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor.cyan
        mat.isDoubleSided = true
        geometry.materials = [mat]
        let node = SCNNode(geometry: geometry)
        
        //let scnView = self.view as! SCNView

        //scnView.scene?.rootNode.addChildNode(node)
        
        print(node.boundingBox)
        return node
    }
    
    func buildContour(doc: [String:Any]) -> [CGPoint] {
        guard let asks = doc["asks"] as? [String:Any],
                    let bids = doc["bids"] as? [String:Any]
        else { return [CGPoint]() }
        
        let sortedAsks = asks.sorted(by: { $0.key < $1.key})
        let sortedBids = bids.sorted(by: { $0.key > $1.key})
        guard let baseBidPrice = Double(sortedBids.first!.key),
            let baseAskPrice = Double(sortedAsks.first!.key),
            let baseAmount = Double(sortedBids.first!.value as! String)
        else { return [CGPoint]() }
        
        var finalContour = [CGPoint]()
        
        if startPrice == nil { startPrice = baseBidPrice }
//                let path = UIBezierPath()
        var askPath = [CGPoint]()
        var bidPath = [CGPoint]()
        
        bidPath.append(CGPoint(x: baseBidPrice - startPrice!, y: 0))
//        path.move(to: CGPoint(x: baseBidPrice - startPrice!, y: 0))
        
        var totalBid = 0.0
        var lastPrice = 0.0
        var lastAmount = 0.0
        for (price, amount) in sortedBids {
            totalBid += Double(amount as! String)!
//            path.addLine(to: CGPoint(x: Double(price)! - startPrice!, y: totalBid))
            bidPath.append(CGPoint(x: Double(price)! - startPrice!, y: totalBid))
            lastPrice = Double(price)! - startPrice!
            lastAmount = totalBid
//            print("x \(Double(price)! - baseBidPrice) y: \(totalBid)")
        }
        bidPath.append(CGPoint(x: lastPrice-150, y: lastAmount))
        finalContour.append(contentsOf: bidPath.reversed())
//        path.addLine(to: CGPoint(x: lastPrice-150, y: lastAmount))
//        path.addLine(to: CGPoint(x: lastPrice-150, y: 0))
//        path.addLine(to: CGPoint(x: baseBidPrice - startPrice!, y: 0))
        
        askPath.append(CGPoint(x: baseAskPrice - startPrice!, y: 0))
//        path.move(to: CGPoint(x: baseAskPrice - startPrice!, y: 0))
        var totalAsk = 0.0
        for (price, amount) in sortedAsks {
            totalAsk += Double(amount as! String)!
            askPath.append(CGPoint(x: Double(price)! - startPrice!, y: totalAsk))
//            path.addLine(to: CGPoint(x: Double(price)! - startPrice!, y: totalAsk))
            lastPrice = Double(price)! - startPrice!
            lastAmount = totalAsk
        }
        askPath.append(CGPoint(x: lastPrice+150, y: lastAmount))
        finalContour.append(contentsOf: askPath)
        
        let center = (baseAskPrice + baseBidPrice)/2 - startPrice!
        currentCenters.append(Float(center))
        if currentCenters.count > visibleFrames+1 { currentCenters.removeFirst() }
        
        return finalContour
//        path.addLine(to: CGPoint(x: lastPrice+150, y: lastAmount))
//        path.addLine(to: CGPoint(x: lastPrice+150, y: 0))
//        path.addLine(to: CGPoint(x: baseAskPrice - startPrice!, y: 0))
    }
    
    var startPrice: Double? = nil
    
    func buildFrameNode(doc: [String:Any]) -> SCNNode {
        guard let asks = doc["asks"] as? [String:Any],
            let bids = doc["bids"] as? [String:Any]
        else { return SCNNode() }
        
        let sortedAsks = asks.sorted(by: { $0.key < $1.key})
        let sortedBids = bids.sorted(by: { $0.key > $1.key})
        guard let baseBidPrice = Double(sortedBids.first!.key),
            let baseAskPrice = Double(sortedAsks.first!.key),
            let baseAmount = Double(sortedBids.first!.value as! String)
        else { return SCNNode() }
        
        if startPrice == nil { startPrice = baseBidPrice }
        
        let path = UIBezierPath()
        path.move(to: CGPoint(x: baseBidPrice - startPrice!, y: 0))
        
        var totalBid = 0.0
        var lastPrice = 0.0
        var lastAmount = 0.0
        for (price, amount) in sortedBids {
            totalBid += Double(amount as! String)!
            path.addLine(to: CGPoint(x: Double(price)! - startPrice!, y: totalBid))
            lastPrice = Double(price)! - startPrice!
            lastAmount = totalBid
//            print("x \(Double(price)! - baseBidPrice) y: \(totalBid)")
        }
        path.addLine(to: CGPoint(x: lastPrice-150, y: lastAmount))
        path.addLine(to: CGPoint(x: lastPrice-150, y: 0))
        path.addLine(to: CGPoint(x: baseBidPrice - startPrice!, y: 0))
        
        path.move(to: CGPoint(x: baseAskPrice - startPrice!, y: 0))
        var totalAsk = 0.0
        for (price, amount) in sortedAsks {
            totalAsk += Double(amount as! String)!
            path.addLine(to: CGPoint(x: Double(price)! - startPrice!, y: totalAsk))
            lastPrice = Double(price)! - startPrice!
            lastAmount = totalAsk
        }
        path.addLine(to: CGPoint(x: lastPrice+150, y: lastAmount))
        path.addLine(to: CGPoint(x: lastPrice+150, y: 0))
        path.addLine(to: CGPoint(x: baseAskPrice - startPrice!, y: 0))
        
        
        let shape = SCNShape()
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor.cyan
        mat.isDoubleSided = true
        shape.materials = [mat]
        shape.path = path
        let node = SCNNode(geometry: shape)
        
        let formattedPrice = String(format: "$%.02f", (baseAskPrice + baseBidPrice)/2)
        let textGeo = SCNText(string: formattedPrice, extrusionDepth: 0)
        textGeo.font = UIFont.systemFont(ofSize: 10)
        textGeo.materials = [mat]
        let textNode = SCNNode(geometry: textGeo)
        textNode.scale = SCNVector3(0.5, 0.5, 0.5)
        
        let center = (baseAskPrice + baseBidPrice)/2 - startPrice!
        currentCenters.append(Float(center))
        if currentCenters.count > visibleFrames+1 { currentCenters.removeFirst() }
        let textX = center - 11
        textNode.position = SCNVector3(textX, -8, 0)
        node.addChildNode(textNode)
        return node
    }
    
//    func moveShipWithDelay0(action: SCNAction) {
//        if touchesChanged || touchesEnded { return }
//        let ship = scnView.scene!.rootNode.childNode(withName: "ship", recursively: true)!
//        ship.runAction(self.action)
//        DispatchQueue.main.asyncAfter(deadline: .now()+0.1) {
//            self.moveShipWithDelay0(action: self.action)
//        }
//    }
//
//    var isMoving = false
//
//    func moveShipWithDelay1(action: SCNAction) {
//        isMoving = true
//        if touchesEnded { return }
//        let ship = scnView.scene!.rootNode.childNode(withName: "ship", recursively: true)!
//        ship.runAction(self.action)
//        DispatchQueue.main.asyncAfter(deadline: .now()+0.1) {
//            self.moveShipWithDelay1(action: self.action)
//        }
//    }

//    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
//        touchesEnded = true
//        touchesChanged = true
//    }
//
//    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
//        touchesChanged = true
//        touchesEnded = true
//    }
//
//    var touchesChanged = true
//    var touchesEnded = true
//
//    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
//        super.touchesBegan(touches, with: event)
//        touchesChanged = false
//        touchesEnded = false
//        isMoving = false
//
//        guard let touch = touches.first else { return }
//
//        //let scnView = self.view as! SCNView
//        let p = touch.location(in: scnView)
//
//        let dur = 0.5
//        let x = p.x - 210
//        let y = 618 - p.y
//
//        action = SCNAction.move(by: SCNVector3(x/180, y/180, 0), duration: dur)
//        action.timingMode = .easeInEaseOut
//
//        moveShipWithDelay0(action: action)
//    }
//
//    var lastTap = Date()
//    var action = SCNAction()
//
//    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
//        if Date().timeIntervalSince(lastTap) < 0.1 { return }
//        lastTap = Date()
//
//        guard let touch = touches.first else { return }
//        touchesChanged = true
//
//        //let scnView = self.view as! SCNView
//        let p = touch.location(in: scnView)
//
//
//        let dur = 0.5
//        let x = p.x - 210
//        let y = 618 - p.y
//
//        action = SCNAction.move(by: SCNVector3(x/180, y/180, 0), duration: dur)
//        action.timingMode = .easeInEaseOut
//        if !isMoving {
//            moveShipWithDelay1(action: action)
//        }
//
//    }
    
    @objc
    func handleTap(_ gestureRecognize: UIPanGestureRecognizer) {
        // retrieve the SCNView
        //let scnView = self.view as! SCNView
        
        // check what nodes are tapped
//        let p = gestureRecognize.location(in: scnView)
        let translation = gestureRecognize.translation(in: scnView)
        let x = translation.x
        let y = -translation.y
        
        let ship = scnView.scene!.rootNode.childNode(withName: "ship", recursively: true)!
        
        let dur = 0.5
//        let x = p.x - 210
//        let y = 618 - p.y
        
        let action = SCNAction.move(by: SCNVector3(x/120, y/120, 0), duration: dur)
        action.timingMode = .easeInEaseOut
        ship.runAction(action)
        
//        if p.y < 618 {
//            if p.x < 210 { // top left
//                action = SCNAction.move(by: SCNVector3(-mag, mag, 0), duration: dur)
//            }
//            else { // top right
//                action = SCNAction.move(by: SCNVector3(mag, mag, 0), duration: dur)
//            }
//        }
//        else {
//            if p.x < 210 { // bottom left
//                action = SCNAction.move(by: SCNVector3(-mag, -mag, 0), duration: dur)
//            }
//            else { // bottom right
//                action = SCNAction.move(by: SCNVector3(mag, -mag, 0), duration: dur)
//            }
//        }
        
//        let hitResults = scnView.hitTest(p, options: [:])
//        // check that we clicked on at least one object
//        if hitResults.count > 0 {
//            // retrieved the first clicked object
//            let result = hitResults[0]
//
//            // get its material
//            let material = result.node.geometry!.firstMaterial!
//
//            // highlight it
//            SCNTransaction.begin()
//            SCNTransaction.animationDuration = 0.5
//
//            // on completion - unhighlight
//            SCNTransaction.completionBlock = {
//                SCNTransaction.begin()
//                SCNTransaction.animationDuration = 0.5
//
//                material.emission.contents = UIColor.black
//
//                SCNTransaction.commit()
//            }
//
//            material.emission.contents = UIColor.red
//
//            SCNTransaction.commit()
//        }
    }
    
    override var shouldAutorotate: Bool {
        return false
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .portrait
        } else {
            return .portrait
        }
    }

}

