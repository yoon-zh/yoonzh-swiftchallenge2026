import SwiftUI

struct FourierSketchpadView: View {
    @State private var drawingPoints: [CGPoint] = []
    @State private var isDrawing: Bool = false
    
    @State private var computedEpicycles: [Epicycle] = []
    @State private var computedTrace: [CGPoint] = [] // New: The "Perfect" trace path
    
    var body: some View {
        HStack(spacing: 20) {
            
            // LEFT PANEL: Input
            VStack {
                Text("Input: Draw & Lift Finger")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .shadow(radius: 5)
                    
                    DrawShape(points: drawingPoints)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    // FIX: Do NOT clear array here. Just append.
                                    if !isDrawing { isDrawing = true }
                                    
                                    // Check frame bounds to stop drawing outside box
                                    // (Simple valid coordinate check)
                                    // value.location is relative to the view
                                    drawingPoints.append(value.location)
                                }
                                .onEnded { _ in
                                    isDrawing = false
                                    processSignal(points: drawingPoints)
                                }
                        )
                        .clipped() // FIX: Keeps gestures/drawing inside bounds
                }
                .aspectRatio(1.0, contentMode: .fit)
                .padding()
                
                Button(action: {
                    drawingPoints = []
                    computedEpicycles = [] // Clear output too
                    computedTrace = []
                }) {
                    Label("Clear Canvas", systemImage: "trash")
                        .foregroundColor(.red)
                }
            }
            
            // RIGHT PANEL: Output
            VStack {
                Text("Output: Fourier Series")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                ZStack {
                    // Background Match
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .shadow(radius: 5)
                    
                    if computedEpicycles.isEmpty {
                        Text("Draw something on the left!")
                            .foregroundColor(.gray)
                    } else {
                        // Pass both epicycles AND the trace
                        EpicycleView(epicycles: computedEpicycles, tracePoints: computedTrace)
                    }
                }
                .aspectRatio(1.0, contentMode: .fit)
                .padding()
            }
        }
        .padding()
    }
    
    func processSignal(points: [CGPoint]) {
        // 1. Center the drawing
        let centerX = points.map { $0.x }.reduce(0, +) / CGFloat(points.count)
        let centerY = points.map { $0.y }.reduce(0, +) / CGFloat(points.count)
        
        let centeredPoints = points.map {
            CGPoint(x: $0.x - centerX, y: $0.y - centerY)
        }
        
        // 2. Run Math
        let rawEpicycles = FourierCalculator.computeEpicycles(from: centeredPoints, sampleCount: 256)
        
        // 3. Pre-calculate the Trace Path (so View is fast)
        let trace = FourierCalculator.reconstructPath(from: rawEpicycles, sampleCount: 500) // 500 points for smoothness
        
        self.computedEpicycles = rawEpicycles
        self.computedTrace = trace
    }
}

// A simple Shape wrapper to render points as a line
struct DrawShape: Shape {
    var points: [CGPoint]
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let firstPoint = points.first else { return path }
        
        path.move(to: firstPoint)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }
}

/*
struct ContentView: View {
    @State var text: String = "default"
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text(text)
            
            Button("Hello") {
                text = "todo"
            }
            
        }
    }
}
*/

