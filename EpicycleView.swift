import SwiftUI

struct EpicycleView: View {
    let epicycles: [Epicycle]
    let tracePoints: [CGPoint] // The full path pre-calculated
    
    let speedFactor: Double = (2.0 * .pi) / 5.0 // Loop every 5 seconds
    
    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate * speedFactor
            // Map time to 0...1 cycle progress
            // We use truncatingRemainder so 'progress' is always between 0.0 and 1.0
            let cycleProgress = (time.truncatingRemainder(dividingBy: 2.0 * .pi)) / (2.0 * .pi)
            
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                
                // 1. Draw the Trace (Yellow Line)
                // We draw the path from index 0 up to current index
                if !tracePoints.isEmpty {
                    var tracePath = Path()
                    let startPt = CGPoint(x: tracePoints[0].x + center.x, y: tracePoints[0].y + center.y)
                    tracePath.move(to: startPt)
                    
                    let maxIndex = Int(Double(tracePoints.count) * cycleProgress)
                    
                    if maxIndex > 0 {
                        var lastPoint = startPt
                        
                        // THRESHOLD: If a segment is longer than this, it's a jump.
                        // 50 points is usually a safe bet for a standard iPad screen size.
                        let jumpThreshold: CGFloat = 20.0
                        
                        for i in 1..<min(maxIndex, tracePoints.count) {
                            let rawPt = tracePoints[i]
                            let currentPoint = CGPoint(x: rawPt.x + center.x, y: rawPt.y + center.y)
                            
                            // Check distance from last point
                            let dist = sqrt(pow(currentPoint.x - lastPoint.x, 2) + pow(currentPoint.y - lastPoint.y, 2))
                            
                            if dist > jumpThreshold {
                                // It's a jump! Lift pen and move.
                                tracePath.move(to: currentPoint)
                            } else {
                                // It's a draw stroke
                                tracePath.addLine(to: currentPoint)
                            }
                            lastPoint = currentPoint
                        }
                    }
                    context.stroke(tracePath, with: .color(.yellow), lineWidth: 2)
                }
                
                // 2. Draw the Epicycles (Circles & Arms)
                var currentPos = center
                
                // We calculate the exact time-based position for the arms
                // Note: We use the raw 'time' variable here for continuous rotation
                let t = time.truncatingRemainder(dividingBy: 2.0 * .pi)
                
                for circle in epicycles {
                    let radius = circle.amplitude
                    let angle = circle.phase + (Double(circle.frequency) * t)
                    
                    // Draw Circle (only if visible)
                    if radius > 1.5 {
                        let circlePath = Path(ellipseIn: CGRect(
                            x: currentPos.x - radius, y: currentPos.y - radius,
                            width: radius * 2, height: radius * 2
                        ))
                        context.stroke(circlePath, with: .color(.gray.opacity(0.3)), lineWidth: 1)
                    }
                    
                    // Calculate Next Joint
                    let nextX = currentPos.x + (radius * cos(angle))
                    let nextY = currentPos.y + (radius * sin(angle))
                    let nextPos = CGPoint(x: nextX, y: nextY)
                    
                    // Draw Arm
                    var linePath = Path()
                    linePath.move(to: currentPos)
                    linePath.addLine(to: nextPos)
                    context.stroke(linePath, with: .color(.white.opacity(0.8)), lineWidth: 1)
                    
                    currentPos = nextPos
                }
                
                // 3. Draw Pen Tip
                let penRect = CGRect(x: currentPos.x - 3, y: currentPos.y - 3, width: 6, height: 6)
                context.fill(Path(ellipseIn: penRect), with: .color(.yellow))
            }
        }
        // Match Background Color
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
