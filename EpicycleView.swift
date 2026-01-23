import SwiftUI

struct EpicycleView: View {
    // The data computed by your FourierCalculator
    let epicycles: [Epicycle]
    
    // Control how fast the animation plays
    // 2.0 * .pi / 256 means one full loop takes the same "time" as the original sample count
    let speedFactor: Double = (2.0 * .pi) / 256
    
    var body: some View {
        // TimelineView gives us a clock that updates every frame (60-120Hz)
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate * speedFactor
            
            Canvas { context, size in
                // 1. Setup the center of the screen
                // We want (0,0) to be in the middle, not top-left
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                
                var currentPos = center
                
                // 2. Draw the Chain of Circles
                for circle in epicycles {
                    let radius = circle.amplitude
                    let angle = circle.phase + (Double(circle.frequency) * time)
                    
                    // Draw the faint grey circle path
                    // (Optional: Hide small circles for performance if needed)
                    if radius > 1.0 {
                        let circlePath = Path(ellipseIn: CGRect(
                            x: currentPos.x - radius,
                            y: currentPos.y - radius,
                            width: radius * 2,
                            height: radius * 2
                        ))
                        context.stroke(circlePath, with: .color(.gray.opacity(0.3)), lineWidth: 1)
                    }
                    
                    // Calculate the new tip position (Vector addition)
                    let nextX = currentPos.x + (radius * cos(angle))
                    let nextY = currentPos.y + (radius * sin(angle))
                    let nextPos = CGPoint(x: nextX, y: nextY)
                    
                    // Draw the "arm" (the vector line)
                    var linePath = Path()
                    linePath.move(to: currentPos)
                    linePath.addLine(to: nextPos)
                    context.stroke(linePath, with: .color(.white), lineWidth: 1.5)
                    
                    // Update current position for the next circle in the chain
                    currentPos = nextPos
                }
                
                // 3. Draw the "Pen" at the very end
                let penRect = CGRect(x: currentPos.x - 3, y: currentPos.y - 3, width: 6, height: 6)
                context.fill(Path(ellipseIn: penRect), with: .color(.yellow))
                
                // Note: To draw the *trace* (the yellow line following the pen),
                // we would normally store the `currentPos` in a @State array.
                // However, Canvas resets every frame.
                // For a simple visual check, just seeing the arm swing is usually enough!
                // If you need the trail, we need to lift the `path` state up (see below).
                
            }
        }
        .background(Color.black) // Dark mode looks cooler for math
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
