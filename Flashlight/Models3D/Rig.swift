import SceneKit
import UIKit

/// Where the light leaves the model, in view points. Computed from the real 3D pose.
struct StageGeometry: Equatable {
    var anchor = CGPoint.zero
    var angle: CGFloat = 0        // screen angle of the beam axis, radians, y down
    var unit: CGFloat = 20        // view points per model unit
    var secondary: [CGPoint] = [] // extra emitters (shade top/bottom, ring edge points)
}

/// A built model plus everything needed to light it, frame it and project its emitter.
final class Rig {
    enum Emission { case beam, glow, ring, shade }

    let scene = SCNScene()
    let cameraNode = SCNNode()
    let tiltNode = SCNNode()     // pose: rotation about Z
    let spinNode = SCNNode()     // pose: rotation about the model's own vertical axis
    let anchor = SCNNode()       // where the light leaves the model
    var beamAxis: SCNVector3?    // direction of the beam in anchor space (torches)
    var emission: Emission = .glow
    var lensRadius: CGFloat = 3  // model units, for the beam's starting width
    var glowCore: CGFloat = 0.65 // strength of the halo's bright centre (lower for see-through glass)
    var animated = false
    var secondaryNodes: [SCNNode] = []
    var flame: SCNNode?

    private var emitters: [SCNMaterial] = []
    private var sprites: [SCNMaterial] = []   // glow sprites, faded through transparency
    private var lights: [(light: SCNLight, base: CGFloat)] = []
    private let fovDegrees: CGFloat = 26

    init(tilt: CGFloat, spin: CGFloat) {
        scene.background.contents = UIColor.clear
        scene.lightingEnvironment.contents = StudioEnvironment.image
        scene.lightingEnvironment.intensity = 1.15

        scene.rootNode.addChildNode(tiltNode)
        tiltNode.addChildNode(spinNode)
        tiltNode.eulerAngles.z = Float(tilt)
        spinNode.eulerAngles.y = Float(spin)
        spinNode.addChildNode(anchor)

        let camera = SCNCamera()
        camera.fieldOfView = fovDegrees
        camera.zNear = 0.1
        camera.zFar = 400
        cameraNode.camera = camera
        scene.rootNode.addChildNode(cameraNode)

        func directional(_ intensity: CGFloat, _ color: UIColor, euler: SCNVector3) {
            let node = SCNNode()
            let light = SCNLight()
            light.type = .directional
            light.intensity = intensity
            light.color = color
            node.light = light
            node.eulerAngles = euler
            scene.rootNode.addChildNode(node)
        }
        directional(900, UIColor(red: 1, green: 0.96, blue: 0.9, alpha: 1), euler: SCNVector3(-0.65, -0.55, 0))
        directional(520, UIColor(red: 0.7, green: 0.82, blue: 1, alpha: 1), euler: SCNVector3(-0.3, 2.5, 0))
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 70
        scene.rootNode.addChildNode(ambient)
    }

    /// Adds a part of the model.
    func add(_ node: SCNNode) {
        spinNode.addChildNode(node)
    }

    /// Registers a material whose glow follows the lamp level.
    @discardableResult
    func addEmitter(_ material: SCNMaterial, glow: UIColor) -> SCNMaterial {
        material.emission.contents = glow
        material.emission.intensity = 0
        emitters.append(material)
        return material
    }

    /// Tracks a glow sprite whose opacity follows the lamp level.
    func trackSprite(_ material: SCNMaterial) {
        material.transparency = 0
        sprites.append(material)
    }

    /// Registers a light whose intensity follows the lamp level.
    func addLight(_ light: SCNLight, at position: SCNVector3, base: CGFloat) {
        let node = SCNNode()
        node.light = light
        node.position = position
        light.intensity = 0
        light.categoryBitMask = 1   // glass uses category 2, so interior lights skip it
        spinNode.addChildNode(node)
        lights.append((light, base))
    }

    func place(anchorAt position: SCNVector3, axis: SCNVector3? = nil) {
        anchor.position = position
        beamAxis = axis
    }

    /// Applies the lamp level (0...1) to every emissive surface, light and flame.
    func apply(level: Double) {
        let l = CGFloat(level)
        for m in emitters { m.emission.intensity = l * 1.25 }
        for m in sprites { m.transparency = l }
        for entry in lights { entry.light.intensity = entry.base * l }
        if let flame {
            flame.opacity = level > 0.001 ? 1 : 0
            flame.scale = SCNVector3(0.55 + 0.45 * l, 0.5 + 0.5 * l, 0.55 + 0.45 * l)
        }
    }

    /// Positions the camera so the whole model fits for a view of this aspect ratio.
    func fit(aspect: CGFloat) {
        let (center, radius) = tiltNode.boundingSphere
        let world = tiltNode.convertPosition(center, to: scene.rootNode)
        let halfV = tan(fovDegrees * .pi / 360)
        let halfH = halfV * max(aspect, 0.1)
        let limit = min(halfV, halfH)
        let distance = CGFloat(radius) * 1.08 / limit
        cameraNode.position = SCNVector3(world.x, world.y, world.z + Float(distance))
        cameraNode.look(at: world)
    }

    /// Projects the emitter into view coordinates. Done by hand from the camera parameters:
    /// `SCNView.projectPoint` uses the last rendered frame, which does not exist yet at first layout.
    func geometry(size: CGSize) -> StageGeometry {
        let halfV = tan(fovDegrees * .pi / 360)
        let aspect = size.width / size.height

        func project(_ node: SCNNode, _ local: SCNVector3 = SCNVector3Zero) -> CGPoint {
            let world = node.convertPosition(local, to: nil)
            let c = cameraNode.convertPosition(world, from: nil)  // camera space, looking down -Z
            let depth = CGFloat(-c.z)
            guard depth > 0.01 else { return .zero }
            let nx = CGFloat(c.x) / (depth * halfV * aspect)
            let ny = CGFloat(c.y) / (depth * halfV)
            return CGPoint(x: (nx * 0.5 + 0.5) * size.width, y: (1 - (ny * 0.5 + 0.5)) * size.height)
        }

        let origin = project(anchor)
        let unitPoint = project(anchor, SCNVector3(1, 0, 0))
        var g = StageGeometry(anchor: origin,
                              unit: max(1, hypot(unitPoint.x - origin.x, unitPoint.y - origin.y)))
        if let axis = beamAxis {
            let tip = project(anchor, axis)
            g.angle = atan2(tip.y - origin.y, tip.x - origin.x)
        }
        g.secondary = secondaryNodes.map { project($0) }
        return g
    }
}
