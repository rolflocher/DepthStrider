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
        
        // create and add a camera to the scene
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        ship.addChildNode(cameraNode)
        // place the camera
        cameraNode.position = SCNVector3(x: 0, y: 28, z: 15)
        
        // animate the 3d object
//        ship.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: 2, z: 0, duration: 1)))
        
        // retrieve the SCNView
//        let scnView = self.view as! SCNView
        
        // set the scene to the view
        scnView.scene = scene
        
        // allows the user to manipulate the camera
        scnView.allowsCameraControl = false
        
        // show statistics such as fps and timing information
        scnView.showsStatistics = false
        
        // configure the view
        scnView.backgroundColor = UIColor.black
        
        // add a tap gesture recognizer
//        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
//        scnView.addGestureRecognizer(tapGesture)
        
//        let tapGesture0 = UILongPressGestureRecognizer(target: self, action: #selector(handleTap(_:)))
//        tapGesture0.minimumPressDuration = .zero
//        tapGesture0.allowableMovement = .greatestFiniteMagnitude
//        scnView.addGestureRecognizer(tapGesture0)
        
        watchFrames()
    }
    
    func watchFrames() {
        db?.collection("depth").order(by: "timestamp", descending: true).limit(to: 1).addSnapshotListener({ (snapshot, error) in
            guard let snap = snapshot,
                let doc = snap.documents.first
            else { return }
            let node = self.buildFrameNode(doc: doc.data())
            
//            let scnView = self.view as! SCNView
            self.scnView.scene?.rootNode.addChildNode(node)
            
        })
    }
    
    var startPrice: Double? = nil
    
    func buildFrameNode(doc: [String:Any]) -> SCNNode {
        guard let asks = doc["asks"] as? [String:Any],
            let bids = doc["bids"] as? [String:Any]
        else { return SCNNode() }
        
        let sortedAsks = asks.sorted(by: { $0.key < $1.key})
        let sortedBids = bids.sorted(by: { $0.key > $1.key})
        guard let basePrice = Double(sortedBids.first!.key),
            let baseAmount = Double(sortedBids.first!.value as! String)
        else { return SCNNode() }
        
        if startPrice == nil { startPrice = basePrice }
        
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        
        var totalBid = 0.0
        var lastPrice = 0.0
        for (price, amount) in sortedBids {
            totalBid += Double(amount as! String)!
            path.addLine(to: CGPoint(x: Double(price)! - basePrice, y: totalBid))
            lastPrice = Double(price)! - basePrice
//            print("x \(Double(price)! - basePrice) y: \(totalBid)")
        }
        path.addLine(to: CGPoint(x: lastPrice, y: 0))
        path.addLine(to: CGPoint(x: 0, y: 0))
        
        
        path.move(to: CGPoint(x: 0, y: 0))
        var totalAsk = 0.0
        for (price, amount) in sortedAsks {
            totalAsk += Double(amount as! String)!
            path.addLine(to: CGPoint(x: Double(price)! - basePrice, y: totalAsk))
            lastPrice = Double(price)! - basePrice
//            print("x \(Double(price)! - basePrice) y: \(totalBid)")
        }
        path.addLine(to: CGPoint(x: lastPrice, y: 0))
        path.addLine(to: CGPoint(x: 0, y: 0))
        
        
        let shape = SCNShape()
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor.cyan
        mat.isDoubleSided = true
        shape.materials = [mat]
        shape.path = path
        let node = SCNNode(geometry: shape)
        node.position = SCNVector3Make(0, 0, -300)
        
        let action = SCNAction.move(by: SCNVector3(0, 0, 300), duration: 30)
        action.timingMode = .linear
        node.runAction(action)
        
        node.opacity = 0
        let action1 = SCNAction.fadeOpacity(to: 0.7, duration: 1)
        action1.timingMode = .linear
        node.runAction(action1)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            node.removeFromParentNode()
        }
        
        return node
    }
    
    func moveShipWithDelay0(action: SCNAction) {
        if touchesChanged || touchesEnded { return }
        let ship = scnView.scene!.rootNode.childNode(withName: "ship", recursively: true)!
        ship.runAction(self.action)
        DispatchQueue.main.asyncAfter(deadline: .now()+0.1) {
            self.moveShipWithDelay0(action: self.action)
        }
    }
    
    var isMoving = false

    func moveShipWithDelay1(action: SCNAction) {
        isMoving = true
        if touchesEnded { return }
        let ship = scnView.scene!.rootNode.childNode(withName: "ship", recursively: true)!
        ship.runAction(self.action)
        DispatchQueue.main.asyncAfter(deadline: .now()+0.1) {
            self.moveShipWithDelay1(action: self.action)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded = true
        touchesChanged = true
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesChanged = true
        touchesEnded = true
    }

    var touchesChanged = true
    var touchesEnded = true

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        touchesChanged = false
        touchesEnded = false
        isMoving = false

        guard let touch = touches.first else { return }

        //let scnView = self.view as! SCNView
        let p = touch.location(in: scnView)

        let dur = 0.5
        let x = p.x - 210
        let y = 618 - p.y

        action = SCNAction.move(by: SCNVector3(x/180, y/180, 0), duration: dur)
        action.timingMode = .easeInEaseOut

        moveShipWithDelay0(action: action)
    }
    
    var lastTap = Date()
    var action = SCNAction()

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if Date().timeIntervalSince(lastTap) < 0.1 { return }
        lastTap = Date()
        
        guard let touch = touches.first else { return }
        touchesChanged = true

        //let scnView = self.view as! SCNView
        let p = touch.location(in: scnView)


        let dur = 0.5
        let x = p.x - 210
        let y = 618 - p.y

        action = SCNAction.move(by: SCNVector3(x/180, y/180, 0), duration: dur)
        action.timingMode = .easeInEaseOut
        if !isMoving {
            moveShipWithDelay1(action: action)
        }
        
    }
    
    @objc
    func handleTap(_ gestureRecognize: UIGestureRecognizer) {
        // retrieve the SCNView
        //let scnView = self.view as! SCNView
        
        // check what nodes are tapped
        let p = gestureRecognize.location(in: scnView)
        
        let ship = scnView.scene!.rootNode.childNode(withName: "ship", recursively: true)!
        
        let dur = 0.5
        let x = p.x - 210
        let y = 618 - p.y
        
        let action = SCNAction.move(by: SCNVector3(x/30, y/30, 0), duration: dur)
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
        return true
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }

}

