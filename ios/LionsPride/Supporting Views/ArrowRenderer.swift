//
//  ArrowPolylineRenderer.swift
//  LionsPride
//
//  Created by Kevin Grainer on 5/13/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import Foundation
import CoreLocation
import MapKit

let pointerLineLength = CGFloat(70.0)
let arrowAngle = CGFloat(0.785398)
let lineWidth = 6.0
let arrowTailLength = Float(30.0)
let arrowInterval = Float(300.0)

func lineDistance(_ p1: CGPoint, _ p2: CGPoint) -> Float {
    return hypotf(Float(p1.x) - Float(p2.x), Float(p1.y) - Float(p2.y))
}

func arrowTailPoint(_ start: CGPoint, _ end: CGPoint) -> CGPoint {
    let d0 = lineDistance(start, end)
    let d1 = arrowTailLength
    let x0 = Float(end.x)
    let y0 = Float(end.y)
    let x1 = Float(start.x)
    let y1 = Float(start.y)
    let x2 = x0 - ((d1 * (x0 - x1)) / d0)
    let y2 = y0 - ((d1 * (y0 - y1)) / d0)
    
    return CGPoint(x: CGFloat(x2), y: CGFloat(y2))
}

func drawArrow(start: CGPoint, end: CGPoint, context: CGContext) {
    context.beginPath()
    let startEndAngle = atan((end.y - start.y) / (end.x - start.x)) + ((end.x - start.x) < 0 ? CGFloat(Double.pi) : 0)
    let arrowPoint1 = CGPoint(x: end.x + pointerLineLength * cos(CGFloat(Double.pi) - startEndAngle + arrowAngle), y: end.y - pointerLineLength * sin(CGFloat(Double.pi) - startEndAngle + arrowAngle))
    let arrowPoint2 = CGPoint(x: end.x + pointerLineLength * cos(CGFloat(Double.pi) - startEndAngle - arrowAngle), y: end.y - pointerLineLength * sin(CGFloat(Double.pi) - startEndAngle - arrowAngle))
    let tailPoint = arrowTailPoint(start, end)
    context.move(to: end)
    context.addLine(to: arrowPoint1)
    context.addLine(to: tailPoint)
    context.addLine(to: arrowPoint2)
    context.addLine(to: end)
    context.move(to: end)
    context.closePath()
    context.drawPath(using: CGPathDrawingMode.fillStroke)
}

func setUpCGContext(_ context: CGContext) {
    context.saveGState()
    context.setFillColor(TRAIL_SELECTED.cgColor)
    context.setStrokeColor(TRAIL_SELECTED.cgColor)
    context.setLineDash(phase: 0, lengths: [])
    context.setLineWidth(CGFloat(lineWidth))
}

func pointOnLineAtDistance(_ start: CGPoint, _ end: CGPoint, _ d: Float, _ lineDistance: Float) -> CGPoint {
    let d0 = lineDistance
    let d1 = d
    let x0 = Float(start.x)
    let y0 = Float(start.y)
    let x1 = Float(end.x)
    let y1 = Float(end.y)
    let x2 = x0 - ((d1 * (x0 - x1)) / d0)
    let y2 = y0 - ((d1 * (y0 - y1)) / d0)
    return CGPoint(x: CGFloat(x2), y: CGFloat(y2))
}

func drawArrowsByOffset(_ cgPointArray: [CGPoint], _ arrowInterval: Float, isLine: Bool, context: CGContext) {
    
    if cgPointArray.count > 0 {
        var lDistance = Float(0.0)
        var prevCgPoint = cgPointArray[0]
        var cgPoint = cgPointArray[1]
        var offset = arrowInterval
        for i in 1..<cgPointArray.count {
            cgPoint = cgPointArray[i]
            lDistance = lineDistance(prevCgPoint, cgPoint)
            
            if lDistance >= offset {
                while lDistance >= offset {
                    let internalPoint = pointOnLineAtDistance(prevCgPoint, cgPoint, offset, lDistance)
                    drawArrow(start: prevCgPoint, end: internalPoint, context: context)
                    offset = offset + arrowInterval
                }
                offset = offset - lDistance
            } else {
                offset = offset - lDistance
            }
            prevCgPoint = cgPoint
        }

        if !isLine {
            cgPoint = cgPointArray[0]
            lDistance = lineDistance(prevCgPoint, cgPoint)
            while lDistance >= offset {
                // get the next point and recalulate the distance
                let internalPoint = pointOnLineAtDistance(prevCgPoint, cgPoint, offset, lDistance)
                drawArrow(start: prevCgPoint, end: internalPoint, context: context)
                offset = offset + arrowInterval
            }
        }
    }
}

class ArrowPolylineRenderer: MKPolylineRenderer {
    
    var direction: Direction
    
    init(overlay: MKOverlay, direction: Direction) {
        self.direction = direction
        super.init(overlay: overlay)
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {

        super.draw(mapRect, zoomScale: zoomScale, in: context)
        drawArrowsOnPolyline(polyline: self.polyline, context: context)
    }
    
    func drawArrowsOnPolyline(polyline: MKPolyline, context: CGContext) {
        

        if self.polyline.pointCount > 0 {
            setUpCGContext(context)
            let points = polyline.points()
            var cgPointArray = [CGPoint]()
            
            if self.direction == .Clockwise {
                for i in 0..<self.polyline.pointCount {
                    cgPointArray.append(self.point(for: points[i]))
                }
            } else {
                for i in (0..<self.polyline.pointCount).reversed() {
                    cgPointArray.append(self.point(for: points[i]))
                }
            }

            drawArrowsByOffset(cgPointArray, arrowInterval, isLine: true, context: context)
            context.restoreGState()
        }
        
    }
}

class ArrowPolygonRenderer: MKPolygonRenderer {
    
    var direction: Direction
    
    init(overlay: MKOverlay, direction: Direction) {
        self.direction = direction
        super.init(overlay: overlay)
    }
    
    
    
    func drawArrowsOnPolygon(polygon: MKPolygon, context: CGContext) {
        

        if self.polygon.pointCount > 0 {
            setUpCGContext(context)
            let points = polygon.points()
            var cgPointArray = [CGPoint]()
            
            
            if self.direction == .Clockwise {
                for i in 0..<self.polygon.pointCount {
                    cgPointArray.append(self.point(for: points[i]))
                }
            } else {
                for i in (0..<self.polygon.pointCount).reversed() {
                    cgPointArray.append(self.point(for: points[i]))
                }
            }
            drawArrowsByOffset(cgPointArray, arrowInterval, isLine: false, context: context)
            context.restoreGState()
        }
        
    }
    
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {

        super.draw(mapRect, zoomScale: zoomScale, in: context)
        drawArrowsOnPolygon(polygon: polygon, context: context)
    }
}
