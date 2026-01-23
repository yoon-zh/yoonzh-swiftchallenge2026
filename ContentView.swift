import SwiftUI
import Charts // Optional, if you want to show coordinate stats later

struct FourierSketchpadView: View {
    // 1. State to hold the user's drawing (Raw Signal)
    // We store 'CGPoint' because we need X (Time/Real) and Y (Amplitude/Imaginary)
    @State private var drawingPoints: [CGPoint] = []
    
    // State to track if the user is currently drawing
    @State private var isDrawing: Bool = false
    
    // HOLDING THE RESULT
    @State private var computedEpicycles: [Epicycle] = []
    
    var body: some View {
        HStack(spacing: 20) {
            
            // LEFT PANEL: The Input (Time Domain / Spatial Domain)
            VStack {
                Text("Input: Draw Anything")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                ZStack {
                    // Background grid
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .shadow(radius: 5)
                    
                    // The Drawing Layer
                    DrawShape(points: drawingPoints)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Gesture Recognizer
                    Color.clear // Transparent overlay to catch touches
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    // Start a new drawing if we just began
                                    if !isDrawing {
                                        drawingPoints = []
                                        isDrawing = true
                                    }
                                    // Append points to our signal array
                                    // LIMIT: We normalize to the frame size later,
                                    // for now we just capture raw touch locations.
                                    let newPoint = value.location
                                    drawingPoints.append(newPoint)
                                }
                                .onEnded { _ in
                                    isDrawing = false
                                    // TRIGGER: This is where you will call your Math function
                                    processSignal(points: drawingPoints)
                                }
                        )
                }
                .aspectRatio(1.0, contentMode: .fit) // Keep it square
                .padding()
                
                // Controls
                Button(action: {
                    drawingPoints = []
                }) {
                    Label("Clear Canvas", systemImage: "trash")
                        .foregroundColor(.red)
                }
            }
            
            // RIGHT PANEL: The Output (Frequency Domain / Epicycles)
            VStack {
                Text("Output: Fourier Series")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black)
                        .shadow(radius: 5)
                    
                    if computedEpicycles.isEmpty {
                        Text("Draw something on the left!")
                            .foregroundColor(.gray)
                    } else {
                        // THE NEW ANIMATION VIEW
                        EpicycleView(epicycles: computedEpicycles)
                    }
                }
                .aspectRatio(1.0, contentMode: .fit)
                .padding()
            }
        }
        .padding()
    }
    
    func processSignal(points: [CGPoint]) {
        // 1. Center the drawing (Important!)
        // If we don't do this, the "DC Offset" (Freq 0) will be huge
        // and the circles will orbit a point far off-screen.
        let centerX = points.map { $0.x }.reduce(0, +) / CGFloat(points.count)
        let centerY = points.map { $0.y }.reduce(0, +) / CGFloat(points.count)
        
        let centeredPoints = points.map {
            CGPoint(x: $0.x - centerX, y: $0.y - centerY)
        }
        
        // 2. Run the math
        let rawEpicycles = FourierCalculator.computeEpicycles(from: centeredPoints, sampleCount: 256)
        
        // 3. Update UI
        self.computedEpicycles = rawEpicycles
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

