// ContentView.swift
import SwiftUI

struct FourierSketchpadView: View {
    @State private var finishedStrokes: [[CGPoint]] = []
    @State private var currentStroke: [CGPoint] = []
    
    @State private var computedEpicycles: [Epicycle] = []
    @State private var computedTrace: [CGPoint] = []
    
    // NEW: State for the Info Alert
    @State private var showInfo = false
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            
            // MAIN CONTENT
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
                        
                        ForEach(0..<finishedStrokes.count, id: \.self) { index in
                            DrawStroke(points: finishedStrokes[index])
                                .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        }
                        
                        DrawStroke(points: currentStroke)
                            .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        
                        // NEW: GeometryReader limits drawing strictly to the box frame
                        GeometryReader { geo in
                            Color.clear
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            // BOUNDARY CHECK
                                            if geo.frame(in: .local).contains(value.location) {
                                                currentStroke.append(value.location)
                                            } else {
                                                // NEW: If finger goes out of bounds, finish the stroke
                                                if !currentStroke.isEmpty {
                                                    finishedStrokes.append(currentStroke)
                                                    currentStroke = []
                                                }
                                            }
                                        }
                                        .onEnded { _ in
                                            if !currentStroke.isEmpty {
                                                finishedStrokes.append(currentStroke)
                                                currentStroke = []
                                            }
                                            processSignal()
                                        }
                                )
                        }
                        .clipped()
                    }
                    .aspectRatio(1.0, contentMode: .fit)
                    .padding()
                    
                    Button(action: {
                        finishedStrokes = []
                        currentStroke = []
                        computedEpicycles = []
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
            .padding(.top, 40) // Make breathing room for the info button
            .padding()
            
            // NEW: Info Button pinned to top left
            Button(action: {
                showInfo = true
            }) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.blue)
            }
            .padding()
        }
        // NEW: Info Alert
        .alert("How it Works", isPresented: $showInfo) {
            Button("Got it!", role: .cancel) { }
        } message: {
            Text("Draw a shape in the left panel. The app calculates the Discrete Fourier Transform of your path and uses rotating epicycles to redraw it on the right.")
        }
    }
    
    func processSignal() {
        let allPoints = finishedStrokes.flatMap { $0 }
        guard allPoints.count > 1 else { return }
        
        let centerX = allPoints.map { $0.x }.reduce(0, +) / CGFloat(allPoints.count)
        let centerY = allPoints.map { $0.y }.reduce(0, +) / CGFloat(allPoints.count)
        
        let centeredStrokes = finishedStrokes.map { stroke in
            stroke.map { CGPoint(x: $0.x - centerX, y: $0.y - centerY) }
        }
        
        // SMOOTHING FIX: Increased sampleCount to 512 for higher FFT accuracy
        let rawEpicycles = FourierCalculator.computeEpicycles(from: centeredStrokes, sampleCount: 512)
        
        // SMOOTHING FIX: Increased sampleCount to 2000 for a much smoother reconstructed line
        let trace = FourierCalculator.reconstructPath(from: rawEpicycles, sampleCount: 512)
        
        self.computedEpicycles = rawEpicycles
        self.computedTrace = trace
    }
}

struct DrawStroke: Shape {
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
