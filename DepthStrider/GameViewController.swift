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

class GameViewController: UIViewController, SCNPhysicsContactDelegate {
    
    @IBOutlet var scnView: SCNView!
    
    @IBOutlet var pauseMenu: UIVisualEffectView!
    
    @IBOutlet var spectateLabel: UILabel!
    
    @IBOutlet var continueLabel: UILabel!
    
    @IBOutlet var pauseImage: UIImageView!
    
    @IBOutlet var scoreLabel: UILabel!
    
    @IBOutlet var pauseScoreLabel: UILabel!
    
    @IBOutlet var pauseScoreView: UIView!
    
    var db: Firestore? = nil
    
    var mask = 1

    override func viewDidLoad() {
        super.viewDidLoad()
        
        db = Firestore.firestore()
        
        UIApplication.shared.isIdleTimerDisabled = true
        
        let scene = SCNScene(named: "art.scnassets/ship.scn")!
        
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light!.type = .ambient
        ambientLightNode.light!.color = UIColor.darkGray
        scene.rootNode.addChildNode(ambientLightNode)
        
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 5, z: 20)//28, z: 15)
        cameraNode.camera!.zFar = 400
        
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light!.type = .omni
        lightNode.position = SCNVector3(x: 0, y: 10, z: 10)
        cameraNode.addChildNode(lightNode)
        
        let ship = scene.rootNode.childNode(withName: "ship", recursively: true)!
        ship.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(node: ship, options: nil))
        mask = ship.physicsBody!.collisionBitMask
        ship.physicsBody!.contactTestBitMask = mask
        ship.physicsBody!.categoryBitMask = mask
        ship.opacity = 0
        ship.addChildNode(cameraNode)
//        ship.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: 2, z: 0, duration: 1)))
        
        
        let partScene = SCNScene(named: "art.scnassets/collection.scn")!
        let booster = partScene.rootNode.childNodes[0].particleSystems!.first!
        booster.emittingDirection = SCNVector3(0, 0, 1)
        ship.addParticleSystem(booster)
        ship.position = SCNVector3(0, 21, -11)
        
        scene.fogEndDistance = 400
        scene.fogStartDistance = 300
        scnView.scene = scene
        scnView.scene!.physicsWorld.contactDelegate = self
        
        scnView.allowsCameraControl = false
        scnView.showsStatistics = false
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
                
        startSpectating()
        watchFrames()
    }
    
    var isAlive = false
    var score = 0
    
    @objc func continueTapped() {
        isAlive = true
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
        isAlive = false
        if score != 0 {
            pauseScoreView.isHidden = false
            pauseScoreLabel.text = String(score)
        }
        else {
            pauseScoreView.isHidden = true
        }
        UIView.animate(withDuration: 1) {
            self.pauseMenu.isHidden = false
            self.pauseMenu.alpha = 1
        }
        startSpectating()
    }
    
    func incrementTimerUntilCrash() {
        if !isAlive { return }
        score += 1
        DispatchQueue.main.asyncAfter(deadline: .now()+0.333) {
            self.scoreLabel.text = "Score: \(self.score)"
            self.incrementTimerUntilCrash()
        }
    }
    
    func startFlying() {
        let ship = scnView.scene!.rootNode.childNode(withName: "ship", recursively: true)!
        //let action = SCNAction.move(to: <#T##SCNVector3#>, duration: <#T##TimeInterval#>)
        fadeInNode(node: ship, finalOpacity: 1, duration: 3)
        shouldStopFollowingFrames = true
        incrementTimerUntilCrash()
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
            if currentCenters.count > 2 {
                let ship = scnView.scene!.rootNode.childNode(withName: "ship", recursively: true)!
                var ref = ship.position
                ref.x = currentCenters[2]
                ref.y = 20
                let action = SCNAction.move(to: ref, duration: 5)
                ship.runAction(action)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now()+5) {
            self.followFrames()
        }
    }
    
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        guard let bodyA = contact.nodeA.physicsBody, let bodyB = contact.nodeB.physicsBody
        else { return }
//        print("a: category: \(bodyA.categoryBitMask), contact: \(bodyA.contactTestBitMask), collision: \(bodyA.collisionBitMask)")
//        print("B: category: \(bodyB.categoryBitMask), contact: \(bodyB.contactTestBitMask), collision: \(bodyB.collisionBitMask)")
        
        if self.isAlive {
            self.isAlive = false
            DispatchQueue.main.async {
                self.gameOver()
            }
        }
        
    }
    
    func gameOver() {
        if score != 0 {
            pauseScoreView.isHidden = false
            pauseScoreLabel.text = String(score)
        }
        else {
            pauseScoreView.isHidden = true
        }
        UIView.animate(withDuration: 1) {
            self.pauseMenu.isHidden = false
            self.pauseMenu.alpha = 1
        }
        startSpectating()
        score = 0
    }
    
    func loadFrames() {
        
    }
    
    var lastContour: [CGPoint]? = nil
    
    var currentCenters = [Float]()
    var visibleFrames = Int()
    
    
    
    var frameBuffer = [SCNNode]()
    var shouldReleaseFrames = false
    let bufferInterval: TimeInterval = 6.0
    
    func openFrameBuffer() {
        shouldReleaseFrames = true
        releaseFrames()
    }
    
    func closeFrameBuffer() {
        shouldReleaseFrames = false
    }
    
    func releaseFrames() {
        if !shouldReleaseFrames { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now()+6) {
            self.releaseFrames()
        }
    }
    
    var speedMultiplier: Float = 1.0
    var lastSpeedMultiplier: Float = 1.0
    var lastNode: SCNNode? = nil
    let distanceConstant: Float = 400.0
    let duration = 30.5
    
    func watchFrames() {
        
        let firstContour = [CGPoint].init(repeating: CGPoint(x: 0, y: 0), count: 204)
        let secondContour = savedContour.map { (pair) -> CGPoint in
            let point = CGPoint(x: pair[0], y: pair[1])
            return point
        }
        bandWidth = 200
        let firstBand = buildBandNode(firstContour: secondContour, secondContour: firstContour)
        let pos = SCNVector3Make(0, 0, -60)
        firstBand.position = pos
        moveFrame(node: firstBand, distance: Double(self.distanceConstant * self.speedMultiplier+50), duration: duration)
        fadeInNode(node: firstBand, finalOpacity: 1, duration: 3)
        removeFrameAfter(node: firstBand, duration: duration)
        firstBand.name = "band"
        scnView.scene?.rootNode.addChildNode(firstBand)
        lastNode = firstBand
        
        lastContour = secondContour//[CGPoint].init(repeating: CGPoint(x: 0, y: 0), count: 204)
        db?.collection("depth5").order(by: "timestamp", descending: true).limit(to: 1).addSnapshotListener({ (snapshot, error) in
            guard let snap = snapshot,
                let doc = snap.documents.first
            else { return }
            
            
            self.speedMultiplier = Float(self.score)/300 + 1
            
            
//            self.visibleFrames = Int(self.duration/5) - 2
            let frames = self.scnView.scene!.rootNode.childNodes.filter { (node) -> Bool in
                return (node.name ?? "not") == "band"
            }
            self.visibleFrames = frames.count
            
            
            let distance = self.distanceConstant * self.speedMultiplier
            let targetDistance: Float = distance + 40.0
            
            // distance since last doc = travelDistance * (timeDiff)/duration
            
            let newContour = self.buildContour(doc: doc.data())
            if let lastContour = self.lastContour {
                var position = SCNVector3()
                if let lastNode = self.lastNode {
                    let oldBandWidth = CGFloat(lastNode.presentation.boundingBox.max.z - lastNode.presentation.boundingBox.min.z)
                    let oldDistance = CGFloat(targetDistance+lastNode.presentation.position.z)
                    let newBW = oldDistance - oldBandWidth
                    self.bandWidth = newBW
                    let newZ = -lastNode.presentation.position.z + Float(oldBandWidth) - 0.5
                    position = SCNVector3Make(0, 0, -newZ)
                }
                else {
                    self.bandWidth = CGFloat(100)//targetDistance - distance)
                    position = SCNVector3Make(0, 0, -60)
                }
                
                let node = self.buildBandNode(firstContour: newContour, secondContour: lastContour)
                node.position = position
                
                self.moveFrame(node: node, distance: Double(targetDistance+10), duration: self.duration)
                self.fadeInNode(node: node, finalOpacity: 1, duration: 3)
                self.removeFrameAfter(node: node, duration: self.duration)
                node.name = "band"
                self.scnView.scene?.rootNode.addChildNode(node)
                self.lastNode = node
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
    
    var bandWidth: CGFloat = 40.0
    
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
                    SCNVector3(first[index].x, first[index].y, -bandWidth),
                    SCNVector3(second[index].x, second[index].y, 0),
                    SCNVector3(first[index-1].x, first[index-1].y, -bandWidth),
                    SCNVector3(second[index-1].x, second[index-1].y, 0),
                ])
                indices.append(contentsOf: [
                    count+3, count+1, count+0,
                    count+2, count+3, count+0
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
        
        mat.diffuse.contents = #colorLiteral(red: 0.2679305971, green: 0.579035759, blue: 0.5971980691, alpha: 1) //UIColor.cyan
        mat.isDoubleSided = true
        geometry.materials = [mat]
        let node = SCNNode(geometry: geometry)
        node.physicsBody = SCNPhysicsBody(type: SCNPhysicsBodyType.static, shape: SCNPhysicsShape(geometry: geometry, options: [SCNPhysicsShape.Option.type: SCNPhysicsShape.ShapeType.concavePolyhedron]))
        node.physicsBody!.collisionBitMask = self.mask
        node.physicsBody!.contactTestBitMask = self.mask
        node.physicsBody!.categoryBitMask = self.mask
        return node
    }
    
    func buildContour(doc: [String:Any]) -> [CGPoint] {
        guard let asks = doc["asks"] as? [String:Any],
                    let bids = doc["bids"] as? [String:Any]
        else { return [CGPoint]() }
        
        let sortedAsks = asks.sorted(by: { $0.key < $1.key})
        let sortedBids = bids.sorted(by: { $0.key > $1.key})
        guard let baseBidPrice = Double(sortedBids.first!.key),
            let baseAskPrice = Double(sortedAsks.first!.key)
        else { return [CGPoint]() }
        
        var finalContour = [CGPoint]()
        
        if startPrice == nil { startPrice = baseBidPrice }
        var askPath = [CGPoint]()
        var bidPath = [CGPoint]()
        
        bidPath.append(CGPoint(x: baseBidPrice - startPrice!, y: 0))
        
        var totalBid = 0.0
        var lastPrice = 0.0
        var lastAmount = 0.0
        for (price, amount) in sortedBids {
            totalBid += Double(amount as! String)!
            bidPath.append(CGPoint(x: Double(price)! - startPrice!, y: totalBid))
            lastPrice = Double(price)! - startPrice!
            lastAmount = totalBid
        }
        bidPath.append(CGPoint(x: lastPrice-150, y: lastAmount))
        finalContour.append(contentsOf: bidPath.reversed())
        
        askPath.append(CGPoint(x: baseAskPrice - startPrice!, y: 0))
        var totalAsk = 0.0
        for (price, amount) in sortedAsks {
            totalAsk += Double(amount as! String)!
            askPath.append(CGPoint(x: Double(price)! - startPrice!, y: totalAsk))
            lastPrice = Double(price)! - startPrice!
            lastAmount = totalAsk
        }
        askPath.append(CGPoint(x: lastPrice+150, y: lastAmount))
        finalContour.append(contentsOf: askPath)
        
        let center = (baseAskPrice + baseBidPrice)/2 - startPrice!
        if currentCenters.count != 0 && priceNodes.count != 0 {
            let curPrice = Double(currentCenters.first!) + startPrice!

            let price = curPrice
            let price2 = 25*Int(price/25)
            let price1 = price2 - 25
            let price0 = price1 - 25
            let price3 = price2 + 25
            let price4 = price3 + 25
            let price5 = price4 + 25
            
            let p0x = Double(price0) - startPrice!
            let p1x = Double(price1) - startPrice!
            let p2x = Double(price2) - startPrice!
            let p3x = Double(price3) - startPrice!
            let p4x = Double(price4) - startPrice!
            let p5x = Double(price5) - startPrice!
            
            //let nodes = [priceNode0, priceNode1, priceNode2, priceNode3, priceNode4, priceNode5]
            let prices = [price0, price1, price2, price3, price4, price5]
            let xs = [p0x, p1x, p2x, p3x, p4x, p5x]
            
            var newNodes = [SCNNode]()
            var newLineNodes = [SCNNode]()
            for i in 0..<prices.count {
                let textGeo = SCNText(string: "\(prices[i])", extrusionDepth: 0)
                let mat = SCNMaterial()
                mat.diffuse.contents = UIColor.cyan
                mat.isDoubleSided = true
                textGeo.materials = [mat]
                textGeo.alignmentMode = "center"
                let node = priceNodes[i]
                node.removeFromParentNode()
                let lineNode = priceLineNodes[i]
                lineNode.removeFromParentNode()
                
                let textNode = SCNNode(geometry: textGeo)
                textNode.scale = SCNVector3(0.5, 0.5, 0.5)
                textNode.position = SCNVector3(xs[i] - Double(textNode.boundingBox.max.x/2), 80, -200)
                textNode.opacity = 0.7
                newNodes.append(textNode)
                
                // building line node
                let linePlane = SCNPlane(width: 1, height: 100)
                linePlane.materials = [mat]
                let newLineNode = SCNNode(geometry: linePlane)
                newLineNode.opacity = 0.7
                newLineNode.position = SCNVector3(Double(textNode.boundingBox.max.x/2), -80, 0)
                textNode.addChildNode(newLineNode)
                newLineNodes.append(newLineNode)
                
                self.scnView.scene?.rootNode.addChildNode(textNode)
            }
            priceNodes = newNodes
            priceLineNodes = newLineNodes
        }
        else {
            let price = startPrice!
            let price2 = 25*Int(price/25)
            let price1 = price2 - 25
            let price0 = price1 - 25
            let price3 = price2 + 25
            let price4 = price3 + 25
            let price5 = price4 + 25
            
            let p0x = Double(price0) - startPrice!
            let p1x = Double(price1) - startPrice!
            let p2x = Double(price2) - startPrice!
            let p3x = Double(price3) - startPrice!
            let p4x = Double(price4) - startPrice!
            let p5x = Double(price5) - startPrice!
            
            let prices = [price0, price1, price2, price3, price4, price5]
            let xs = [p0x, p1x, p2x, p3x, p4x, p5x]
            
            var newLineNodes = [SCNNode]()
            for i in 0..<prices.count {
                let textGeo = SCNText(string: "\(prices[i])", extrusionDepth: 0)
                let mat = SCNMaterial()
                mat.diffuse.contents = UIColor.cyan
                mat.isDoubleSided = true
                textGeo.materials = [mat]
                let textNode = SCNNode(geometry: textGeo)
                textNode.scale = SCNVector3(0.5, 0.5, 0.5)
                textNode.opacity = 0.7
                textNode.position = SCNVector3(xs[i] - Double(textNode.boundingBox.max.x/2), 80, -200)
                priceNodes.append(textNode)
                
                // building line node
                let linePlane = SCNPlane(width: 1, height: 100)
                linePlane.materials = [mat]
                let newLineNode = SCNNode(geometry: linePlane)
                newLineNode.opacity = 0.4
                newLineNode.position = SCNVector3(Double(textNode.boundingBox.max.x/2), -80, 0)
                textNode.addChildNode(newLineNode)
                newLineNodes.append(newLineNode)
                
                self.scnView.scene?.rootNode.addChildNode(textNode)
            }
            priceLineNodes = newLineNodes
            
            //textGeo.font = UIFont.systemFont(ofSize: 10)
            //textGeo.materials = [mat]
            
        }
        currentCenters.append(Float(center))
        if currentCenters.count > visibleFrames+1 { currentCenters.removeFirst() }
        let currentPrice = (baseAskPrice + baseBidPrice)/2
        
        return finalContour
    }
    
    var priceLineNodes = [SCNNode]()
    var priceNodes = [SCNNode]()
        
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
        if !isAlive {
            return
        }
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

let savedContour = [[-172.3700000000008, 98.76506899999997], [-22.3700000000008, 98.76506899999997], [-22.150000000001455, 98.76253899999998], [-21.030000000000655, 98.41803799999998], [-20.400000000001455, 90.59501699999998], [-20.170000000000073, 90.35851699999998], [-19.270000000000437, 90.35143199999997], [-19.090000000000146, 90.06907899999997], [-19.079999999999927, 90.06757899999998], [-18.360000000000582, 89.96754699999998], [-17.980000000001382, 79.56754699999998], [-17.850000000000364, 79.36754699999997], [-17.790000000000873, 78.73244699999998], [-17.63000000000102, 78.70414999999998], [-17.6200000000008, 78.70289999999999], [-17.2400000000016, 64.17120099999998], [-17.1200000000008, 64.14120099999998], [-16.6200000000008, 64.13933599999999], [-16.320000000001528, 62.139335999999986], [-15.450000000000728, 62.098134999999985], [-14.840000000000146, 62.09613499999998], [-13.960000000000946, 61.78333499999998], [-13.130000000001019, 61.78140199999998], [-12.970000000001164, 61.49907599999998], [-12.650000000001455, 61.47077899999998], [-12.6200000000008, 57.87277899999998], [-12.420000000000073, 47.86689599999998], [-12.25, 47.75023299999998], [-11.980000000001382, 47.57390799999998], [-11.960000000000946, 47.45635499999998], [-11.6200000000008, 47.17580399999998], [-11.31000000000131, 47.163857999999976], [-11.130000000001019, 46.69448799999998], [-11.040000000000873, 46.27448799999998], [-10.980000000001382, 46.18951799999998], [-10.920000000000073, 46.12091799999998], [-10.840000000000146, 46.116917999999984], [-10.760000000000218, 46.078029999999984], [-10.579999999999927, 45.84802999999999], [-10.340000000000146, 45.58358999999999], [-10.320000000001528, 45.49861699999999], [-9.850000000000364, 45.47917299999999], [-9.610000000000582, 45.34387599999999], [-9.360000000000582, 45.06165499999999], [-9.340000000000146, 44.62184899999999], [-9.2400000000016, 44.15267599999999], [-9.180000000000291, 43.91267599999999], [-9.070000000001528, 43.61343199999999], [-9.050000000001091, 43.54203199999999], [-9.010000000000218, 40.413031999999994], [-8.81000000000131, 40.379166999999995], [-8.720000000001164, 40.163174], [-8.660000000001673, 39.995166999999995], [-8.6200000000008, 39.875167], [-8.590000000000146, 39.803165], [-8.3700000000008, 39.779162], [-8.150000000001455, 34.579162], [-8.020000000000437, 34.550864999999995], [-7.6200000000008, 34.485865], [-7.610000000000582, 24.461085999999998], [-7.600000000000364, 24.45133], [-7.579999999999927, 24.225596999999997], [-7.570000000001528, 24.017863999999996], [-7.540000000000873, 23.993375999999994], [-7.0, 23.937048999999995], [-6.610000000000582, 23.867748999999996], [-6.25, 23.529186999999997], [-6.240000000001601, 23.474186999999997], [-6.230000000001382, 23.143970999999997], [-6.220000000001164, 22.974855999999996], [-6.210000000000946, 19.786854999999996], [-6.150000000001455, 19.756033999999996], [-6.010000000000218, 19.725433999999996], [-5.600000000000364, 19.681934999999996], [-5.1600000000016735, 19.181934999999996], [-4.8700000000008, 19.022787999999995], [-4.630000000001019, 18.797245999999994], [-4.6200000000008, 17.782058999999993], [-4.579999999999927, 17.717212999999994], [-4.56000000000131, 17.317212999999995], [-3.640000000001237, 16.859910999999997], [-3.600000000000364, 16.850232], [-3.5900000000001455, 16.450232], [-3.5799999999999272, 16.251002], [-2.640000000001237, 15.851002000000001], [-2.6200000000008004, 15.841002000000001], [-2.600000000000364, 15.839533000000001], [-2.4500000000007276, 15.829533000000001], [-2.0200000000004366, 15.154533], [-1.4900000000016007, 15.020031000000001], [-1.1600000000016735, 11.620031], [-1.1300000000010186, 11.534133], [-0.7700000000004366, 8.134133], [-0.75, 8.132949], [-0.6300000000010186, 8.033639], [-0.4000000000014552, 7.533639000000001], [-0.38000000000101863, 5.1336390000000005], [-0.18000000000029104, 4.6336390000000005], [-0.13000000000101863, 2.633639], [-0.07000000000152795, 2.133639], [0.0, 0.131385], [0.0, 0.0], [2.2299999999995634, 0.0], [2.2299999999995634, 0.014253], [2.2699999999986176, 0.206253], [2.3799999999991996, 0.22736699999999999], [2.529999999998836, 0.240783], [2.7599999999983993, 0.243114], [3.109999999998763, 0.581305], [3.399999999999636, 0.591305], [3.7599999999983993, 0.735305], [3.789999999999054, 1.091694], [3.889999999999418, 1.345194], [4.369999999998981, 1.455194], [4.3799999999992, 1.510194], [4.599999999998545, 2.0101940000000003], [4.609999999998763, 2.5101940000000003], [4.979999999999563, 2.577818], [4.989999999999782, 2.6116300000000003], [5.219999999999345, 3.1116300000000003], [5.359999999998763, 3.2266800000000004], [5.369999999998981, 3.2830050000000006], [5.3799999999992, 3.2842050000000005], [5.479999999999563, 3.7842050000000005], [5.489999999999782, 4.1849750000000006], [5.5, 4.20577], [5.809999999999491, 4.70577], [5.819999999999709, 9.90577], [6.149999999999636, 9.97077], [6.289999999999054, 10.270546], [6.309999999999491, 10.298843], [6.769999999998618, 10.524334999999999], [6.779999999998836, 10.685417999999999], [6.809999999999491, 14.493224999999999], [6.819999999999709, 15.169419999999999], [7.359999999998763, 15.179419999999999], [7.3799999999992, 16.566699999999997], [7.569999999999709, 16.638099999999998], [7.709999999999127, 16.666722999999998], [7.93999999999869, 16.892059999999997], [7.949999999998909, 17.173743999999996], [8.3799999999992, 17.646691999999994], [8.389999999999418, 18.192255999999993], [8.5, 18.866255999999993], [8.55999999999949, 18.983758999999992], [8.639999999999418, 22.06075899999999], [8.779999999998836, 22.26075899999999], [8.839999999998327, 22.39607899999999], [9.3799999999992, 22.68335599999999], [9.709999999999127, 23.03500599999999], [9.719999999999345, 23.211262999999988], [9.899999999999636, 23.212864999999987], [11.109999999998763, 23.740035999999986], [11.1299999999992, 24.197418999999986], [11.3799999999992, 24.199052999999985], [11.469999999999345, 24.480702999999984], [12.089999999998327, 24.550002999999982], [12.139999999999418, 24.650002999999984], [12.209999999999127, 25.150002999999984], [12.369999999998981, 31.060169999999985], [12.3799999999992, 32.871949999999984], [12.569999999999709, 33.02194999999998], [12.719999999999345, 36.72394999999998], [13.0, 36.95394999999998], [13.019999999998618, 37.34725599999998], [13.089999999998327, 37.76725599999998], [13.219999999999345, 38.04890599999998], [13.429999999998472, 38.072907999999984], [13.449999999998909, 40.14490799999999], [13.5, 40.267729999999986], [13.55999999999949, 40.435732999999985], [13.639999999999418, 40.65175499999999], [13.68999999999869, 51.051754999999986], [13.989999999999782, 51.08446799999999], [14.18999999999869, 51.08947999999999], [14.25, 51.10280299999999], [14.299999999999272, 51.12531999999999], [14.349999999998545, 51.12701999999999], [14.3799999999992, 51.22701999999999], [14.829999999999927, 51.77991999999999], [15.3799999999992, 52.06969699999999], [15.459999999999127, 52.11089799999999], [15.489999999999782, 52.347297999999995], [15.719999999999345, 52.348566999999996], [15.929999999998472, 53.169267], [15.949999999998909, 53.197564], [16.299999999999272, 57.290564], [16.3799999999992, 57.372086], [16.529999999998836, 57.373256000000005], [16.779999999998836, 57.63713800000001], [16.8799999999992, 57.663458000000006], [16.93999999999869, 57.667638000000004], [16.98999999999978, 57.75918300000001], [17.25, 57.79246700000001], [17.2599999999984, 58.79246700000001], [17.3799999999992, 62.84452600000001], [17.409999999999854, 62.86452600000001], [17.479999999999563, 62.92080400000001], [17.5, 63.03358500000001], [17.679999999998472, 63.07737000000001], [17.69999999999891, 63.95151700000001], [17.829999999999927, 63.95400000000001], [18.039999999999054, 64.01940800000001], [168.03999999999905, 64.01940800000001]]
