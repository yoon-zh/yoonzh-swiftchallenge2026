// ContentView.swift
import SwiftUI
import Charts

struct FourierSketchpadView: View {
    @State private var finishedStrokes: [[CGPoint]] = []
    @State private var currentStroke: [CGPoint] = []

    // The raw math output
    @State private var computedEpicycles: [Epicycle] = []
    
    // The filtered output passed to the UI
    @State private var activeEpicycles: [Epicycle] = []
    @State private var activeTrace: [CGPoint] = []
    
    @State private var showInfo = false
    
    // Drawer State
    @State private var showDrawer = false
    @State private var smoothness: Double = 1.0 // 1.0 = Keep all circles
    
    var body: some View {
        ZStack(alignment: .top) {
            
            HStack(spacing: 0) {
                // MAIN CANVAS AREA
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
                            
                            // GeometryReader limits drawing strictly to the box frame
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
                                                    // If finger goes out of bounds, finish the stroke
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
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .aspectRatio(1.0, contentMode: .fit)
                        .padding()
                        
                        Button(action: {
                            // FIXED: Clears the correct active arrays
                            finishedStrokes = []
                            currentStroke = []
                            computedEpicycles = []
                            activeEpicycles = []
                            activeTrace = []
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
                            
                            if activeEpicycles.isEmpty {
                                Text("Draw something on the left!")
                                    .foregroundColor(.gray)
                            } else {
                                EpicycleView(epicycles: activeEpicycles, tracePoints: activeTrace)
                            }
                        }
                        .aspectRatio(1.0, contentMode: .fit)
                        .padding()
                    }
                }
                .padding(.top, 40)
                .padding()

                // THE SLIDE-OUT DRAWER
                if showDrawer {
                    AnalysisDrawerView(epicycles: computedEpicycles, smoothness: $smoothness)
                        .frame(width: 320)
                        .transition(.move(edge: .trailing))
                }
                
            } // FIXED: Added missing bracket to close the HStack(spacing: 0)
            
            // TOP BUTTONS
            HStack {
                Button(action: { showInfo = true }) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.blue)
                }
                Spacer()
                // Drawer Toggle Button
                Button(action: {
                    withAnimation(.spring()) {
                        showDrawer.toggle()
                    }
                }) {
                    Image(systemName: showDrawer ? "chart.bar.xaxis.chevron.down" : "chart.bar.xaxis")
                        .font(.system(size: 28))
                        .foregroundColor(.blue)
                }
            }
            .padding()
            
        } // FIXED: Added missing bracket to close the ZStack
        .alert("How it Works", isPresented: $showInfo) {
            Button("Got it!", role: .cancel) { }
        } message: {
            Text("Draw any shape on the left. The app breaks your drawing down into a chain of spinning circles, which work together to perfectly redraw your shape on the right.")
        }
        // Recalculate the line when the slider moves
        .onChange(of: smoothness) { _ in
            applyFilter()
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
        
        self.computedEpicycles = FourierCalculator.computeEpicycles(from: centeredStrokes, sampleCount: 512)
        applyFilter()
    }

    // NEW: True Low-Pass Filter logic
    func applyFilter() {
        guard !computedEpicycles.isEmpty else {
            activeEpicycles = []
            activeTrace = []
            return
        }
        
        // 1. Find the highest absolute frequency in the math
        let highestFreq = computedEpicycles.map { abs($0.frequency) }.max() ?? 1
        
        // 2. Set a cutoff based on the slider (1.0 = keep all, 0.1 = keep only slow circles)
        let cutoff = Int(Double(highestFreq) * smoothness)
        
        // 3. Keep only the circles that spin slower than or equal to the cutoff
        activeEpicycles = computedEpicycles.filter { abs($0.frequency) <= cutoff }
        
        // 4. Reconstruct the filtered path
        activeTrace = FourierCalculator.reconstructPath(from: activeEpicycles, sampleCount: 512)
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