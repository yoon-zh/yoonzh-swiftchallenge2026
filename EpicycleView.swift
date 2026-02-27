// EpicycleView.swift
import SwiftUI

struct EpicycleView: View {
    let epicycles: [Epicycle]
    let tracePoints: [CGPoint]
    var scale: CGFloat = 1.0
    
    // Playback State
    @State private var progress: Double = 0.0
    @State private var isPlaying: Bool = true
    @State private var lastUpdate: Date = Date()
    
    // 60 FPS Timer & Loop Speed (5 seconds per loop)
    let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()
    let speedFactor: Double = 1.0 / 5.0 
    
    var body: some View {
        VStack(spacing: 0) {
            Canvas { context, size in
                let baseSize = CGSize(width: size.width / scale, height: size.height / scale)
                let center = CGPoint(x: baseSize.width / 2, y: baseSize.height / 2)
                context.scaleBy(x: scale, y: scale)
                
                // 1. Draw the Trace (Yellow Line)
                if !tracePoints.isEmpty {
                    var tracePath = Path()
                    let startPt = CGPoint(x: tracePoints[0].x + center.x, y: tracePoints[0].y + center.y)
                    tracePath.move(to: startPt)
                    
                    let maxIndex = Int(Double(tracePoints.count) * progress)
                    
                    if maxIndex > 0 {
                        var lastPoint = startPt
                        let jumpThreshold: CGFloat = 8.0
                        
                        for i in 1..<min(maxIndex, tracePoints.count) {
                            let rawPt = tracePoints[i]
                            let currentPoint = CGPoint(x: rawPt.x + center.x, y: rawPt.y + center.y)
                            
                            let dist = sqrt(pow(currentPoint.x - lastPoint.x, 2) + pow(currentPoint.y - lastPoint.y, 2))
                            
                            if dist > jumpThreshold {
                                tracePath.move(to: currentPoint)
                            } else {
                                tracePath.addLine(to: currentPoint)
                            }
                            lastPoint = currentPoint
                        }
                    }
                    context.stroke(tracePath, with: .color(.yellow), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
                
                // 2. Draw the Epicycles (Circles & Arms)
                var currentPos = center
                let t = progress * 2.0 * .pi
                
                for circle in epicycles {
                    let radius = circle.amplitude
                    let angle = circle.phase + (Double(circle.frequency) * t)
                    
                    if radius > 1.5 {
                        let circlePath = Path(ellipseIn: CGRect(
                            x: currentPos.x - radius, y: currentPos.y - radius,
                            width: radius * 2, height: radius * 2
                        ))
                        context.stroke(circlePath, with: .color(.gray.opacity(0.3)), lineWidth: 1)
                    }
                    
                    let nextX = currentPos.x + (radius * cos(angle))
                    let nextY = currentPos.y + (radius * sin(angle))
                    let nextPos = CGPoint(x: nextX, y: nextY)
                    
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
            .background(Color(UIColor.secondarySystemBackground))
            .onReceive(timer) { currentTime in
                let delta = currentTime.timeIntervalSince(lastUpdate)
                lastUpdate = currentTime
                
                if isPlaying {
                    progress = (progress + delta * speedFactor).truncatingRemainder(dividingBy: 1.0)
                }
            }
            .onAppear { lastUpdate = Date() }
            
            // 4. Replay Bar
            HStack(spacing: 12) {
                Button(action: { isPlaying.toggle() }) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                        .frame(width: 30)
                }
                
                Slider(value: $progress, in: 0...1) { editing in
                    if editing {
                        isPlaying = false // Auto-pause when grabbing the slider
                    }
                }
                .tint(.yellow)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground).brightness(-0.05))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}