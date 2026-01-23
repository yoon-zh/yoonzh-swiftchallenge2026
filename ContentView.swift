import SwiftUI

struct FourierSketchpadView: View {
    // STATE UPDATE: We now hold an array of strokes (Visual)
    // Each "Stroke" is an array of CGPoints
    @State private var finishedStrokes: [[CGPoint]] = []
    @State private var currentStroke: [CGPoint] = [] // The stroke currently being drawn
    
    // OUTPUT STATE
    @State private var computedEpicycles: [Epicycle] = []
    @State private var computedTrace: [CGPoint] = []
    
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
                    
                    // LAYER 1: Finished Strokes (Previous lines)
                    ForEach(0..<finishedStrokes.count, id: \.self) { index in
                        DrawStroke(points: finishedStrokes[index])
                            .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    }
                    
                    // LAYER 2: Current Stroke (Live drawing)
                    DrawStroke(points: currentStroke)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    
                    // GESTURE LAYER
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    // Append points to the CURRENT stroke only
                                    currentStroke.append(value.location)
                                }
                                .onEnded { _ in
                                    // 1. Move current stroke to finished storage
                                    if !currentStroke.isEmpty {
                                        finishedStrokes.append(currentStroke)
                                        currentStroke = []
                                    }
                                    
                                    // 2. Trigger Math
                                    // We need to pass ALL points combined for the math
                                    processSignal()
                                }
                        )
                        .clipped() // Keeps the gesture inside the box
                }
                .aspectRatio(1.0, contentMode: .fit)
                .padding()
                
                Button(action: {
                    // Clear everything
                    finishedStrokes = []
                    currentStroke = []
                    computedEpicycles = []
                    computedTrace = []
                }) {
                    Label("Clear Canvas", systemImage: "trash")
                        .foregroundColor(.red)
                }
            }
            
            // RIGHT PANEL: Output (No changes here)
            VStack {
                Text("Output: Fourier Series")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .shadow(radius: 5)
                    
                    if computedEpicycles.isEmpty {
                        Text("Draw something on the left!")
                            .foregroundColor(.gray)
                    } else {
                        EpicycleView(epicycles: computedEpicycles, tracePoints: computedTrace)
                    }
                }
                .aspectRatio(1.0, contentMode: .fit)
                .padding()
            }
        }
        .padding()
    }
    
    func processSignal() {
        // 1. Flatten the strokes
        // The Math Engine still needs one long list of points.
        // It will interpret the "jump" between strokes as a fast travel line.
        let allPoints = finishedStrokes.flatMap { $0 }
        
        guard allPoints.count > 1 else { return }
        
        // 2. Center the drawing
        let centerX = allPoints.map { $0.x }.reduce(0, +) / CGFloat(allPoints.count)
        let centerY = allPoints.map { $0.y }.reduce(0, +) / CGFloat(allPoints.count)
        
        let centeredPoints = allPoints.map {
            CGPoint(x: $0.x - centerX, y: $0.y - centerY)
        }
        
        // 3. Run Math
        let rawEpicycles = FourierCalculator.computeEpicycles(from: centeredPoints, sampleCount: 256)
        
        // 4. Pre-calculate Trace
        let trace = FourierCalculator.reconstructPath(from: rawEpicycles, sampleCount: 500)
        
        self.computedEpicycles = rawEpicycles
        self.computedTrace = trace
    }
}

// UPDATE: Renamed to 'DrawStroke' and simplified
struct DrawStroke: Shape {
    var points: [CGPoint]
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let firstPoint = points.first else { return path }
        
        // Start a new subpath for this stroke
        path.move(to: firstPoint)
        
        // Connect the dots
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

