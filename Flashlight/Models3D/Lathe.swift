import SceneKit
import UIKit

/// A 2D profile (radius, height) that is revolved around the Y axis.
/// Order points from the bottom, around the outside, to the top. Reverse the order to flip
/// the surface (for example a reflector dish whose inside must face the lens).
struct Profile {
    private(set) var points: [CGPoint]

    init(_ x: CGFloat, _ y: CGFloat) {
        points = [CGPoint(x: x, y: y)]
    }

    func to(_ x: CGFloat, _ y: CGFloat) -> Profile {
        var p = self
        p.points.append(CGPoint(x: x, y: y))
        return p
    }

    /// Cubic Bézier from the current point.
    func curve(_ ex: CGFloat, _ ey: CGFloat,
               c1x: CGFloat, c1y: CGFloat, c2x: CGFloat, c2y: CGFloat, steps: Int = 14) -> Profile {
        guard let s = points.last else { return self }
        var p = self
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let u = 1 - t
            let x = u * u * u * s.x + 3 * u * u * t * c1x + 3 * u * t * t * c2x + t * t * t * ex
            let y = u * u * u * s.y + 3 * u * u * t * c1y + 3 * u * t * t * c2y + t * t * t * ey
            p.points.append(CGPoint(x: x, y: y))
        }
        return p
    }

    /// Circular arc around (cx, cy). Angles in degrees, 0 = +x (outwards), 90 = +y (up).
    func arc(cx: CGFloat, cy: CGFloat, r: CGFloat, from: CGFloat, to: CGFloat, steps: Int = 10) -> Profile {
        var p = self
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let a = (from + (to - from) * t) * .pi / 180
            p.points.append(CGPoint(x: cx + r * cos(a), y: cy + r * sin(a)))
        }
        return p
    }

    /// Sawtooth between two radii, used for knurling and screw threads.
    func teeth(from y0: CGFloat, to y1: CGFloat, count: Int, rLow: CGFloat, rHigh: CGFloat) -> Profile {
        var p = self
        let step = (y1 - y0) / CGFloat(count)
        for i in 0..<count {
            let y = y0 + step * CGFloat(i)
            p.points.append(CGPoint(x: rLow, y: y))
            p.points.append(CGPoint(x: rHigh, y: y + step * 0.18))
            p.points.append(CGPoint(x: rHigh, y: y + step * 0.55))
            p.points.append(CGPoint(x: rLow, y: y + step * 0.72))
        }
        p.points.append(CGPoint(x: rLow, y: y1))
        return p
    }
}

enum Lathe {
    /// Builds a smooth-shaded surface of revolution. Corners sharper than `crease` stay crisp.
    static func geometry(_ profile: Profile, segments: Int = 96, crease: CGFloat = 38 * .pi / 180) -> SCNGeometry {
        let pts = profile.points
        precondition(pts.count >= 2, "A profile needs at least two points")

        // Outward normal of each profile segment (dy, -dr).
        var segmentNormals: [SIMD2<Float>] = []
        var cumulative: [Float] = [0]
        for i in 0..<(pts.count - 1) {
            let dr = Float(pts[i + 1].x - pts[i].x)
            let dy = Float(pts[i + 1].y - pts[i].y)
            let length = max(1e-6, hypot(dr, dy))
            segmentNormals.append(SIMD2(dy / length, -dr / length))
            cumulative.append(cumulative[i] + length)
        }
        let total = max(1e-6, cumulative.last ?? 1)

        func normal(segment s: Int, atEnd end: Bool) -> SIMD2<Float> {
            let own = segmentNormals[s]
            let neighbour = end ? s + 1 : s - 1
            guard neighbour >= 0, neighbour < segmentNormals.count else { return own }
            let other = segmentNormals[neighbour]
            let angle = acos(max(-1, min(1, simd_dot(own, other))))
            if CGFloat(angle) > crease { return own }
            let sum = own + other
            let len = simd_length(sum)
            return len < 1e-5 ? own : sum / len
        }

        var positions: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var uvs: [CGPoint] = []
        var indices: [UInt32] = []
        let ring = segments + 1

        for s in 0..<segmentNormals.count {
            let base = UInt32(positions.count)
            for end in 0..<2 {
                let p = pts[s + end]
                let n = normal(segment: s, atEnd: end == 1)
                let v = CGFloat(cumulative[s + end] / total)
                for j in 0...segments {
                    let t = Float(j) / Float(segments)
                    let a = t * 2 * .pi
                    let c = cos(a), sn = sin(a)
                    positions.append(SCNVector3(Float(p.x) * c, Float(p.y), Float(p.x) * sn))
                    normals.append(SCNVector3(n.x * c, n.y, n.x * sn))
                    uvs.append(CGPoint(x: CGFloat(t), y: v))
                }
            }
            for j in 0..<segments {
                let a = base + UInt32(j)
                let b = base + UInt32(ring + j)
                indices += [a, b, a + 1, b, b + 1, a + 1]
            }
        }

        let geometry = SCNGeometry(
            sources: [
                SCNGeometrySource(vertices: positions),
                SCNGeometrySource(normals: normals),
                SCNGeometrySource(textureCoordinates: uvs),
            ],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)])
        return geometry
    }
}
