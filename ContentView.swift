// ContentView.swift
import SwiftUI
import Charts
import FoundationModels
import Vision
import PhotosUI
import CoreImage.CIFilterBuiltins

@available(iOS 26.0, *)
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
    
    // Band-Pass Bounds
    @State private var minFreqRatio: Double = 0.0
    @State private var maxFreqRatio: Double = 1.0
    
    // Foundation models text input
    @State private var textInput: String = ""
    @State private var isGenerating: Bool = false
    @State private var showTextInput: Bool = false
    
    // Keyboard
    @FocusState private var isInputFocused: Bool
    
    // Photo picker
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isProcessingImage: Bool = false
    @State private var showCameraSheet = false

    // Canvas size
    @State private var canvasSize: CGSize = CGSize(width: 300, height: 300)
    @State private var baseCanvasSize: CGSize = .zero
    
    var drawingScale: CGFloat {
        guard baseCanvasSize.width > 0, canvasSize.width > 0 else { return 1.0 }
        return canvasSize.width / baseCanvasSize.width
    }

    // MARK: - MAIN BODY
    var body: some View {
        ZStack(alignment: .top) {
            mainWorkspace
            topNavigation
            floatingBottomControls
        }
        .alert("How it Works", isPresented: $showInfo) {
            Button("Got it!", role: .cancel) { }
        } message: {
            Text("Draw any shape on the left. The app breaks your drawing down into a chain of spinning circles, which work together to redraw your shape on the right.")
        }
        .onChange(of: minFreqRatio) { _ in applyFilter() }
        .onChange(of: maxFreqRatio) { _ in applyFilter() }
    }
    
    // MARK: - UI COMPONENTS
    
    private var mainWorkspace: some View {
        HStack(spacing: 0) {
            // MAIN CANVAS AREA
            HStack(spacing: 20) {
                leftInputPanel
                rightOutputPanel
            }
            .padding(.top, 40)
            .padding()
            
            // THE SLIDE-OUT DRAWER
            if showDrawer {
                AnalysisDrawerView(
                    epicycles: computedEpicycles,
                    showDrawer: $showDrawer,
                    minFreqRatio: $minFreqRatio,
                    maxFreqRatio: $maxFreqRatio
                )
                .frame(width: 350)
                .transition(.move(edge: .trailing))
            }
        }
    }
    
    private var leftInputPanel: some View {
        VStack {
            Text("Input: Draw & Lift Finger")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Color.clear
                .aspectRatio(1.0, contentMode: .fit)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .shadow(radius: 5)
                )
                .overlay(
                    GeometryReader { geo in
                        ZStack {
                            ForEach(0..<finishedStrokes.count, id: \.self) { index in
                                DrawStroke(points: finishedStrokes[index], scale: drawingScale)
                                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                            }
                            
                            DrawStroke(points: currentStroke, scale: drawingScale)
                                .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                            
                            Color.clear
                                .contentShape(Rectangle())
                                .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let unscaledX = max(0, min(value.location.x, geo.size.width)) / drawingScale
                                        let unscaledY = max(0, min(value.location.y, geo.size.height)) / drawingScale
                                        currentStroke.append(CGPoint(x: unscaledX, y: unscaledY))
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
                        .onAppear { 
                            if baseCanvasSize == .zero { baseCanvasSize = geo.size }
                            canvasSize = geo.size 
                        }
                        .onChange(of: geo.size) { newSize in canvasSize = newSize }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            
            Button(action: {
                finishedStrokes = []
                currentStroke = []
                computedEpicycles = []
                activeEpicycles = []
                activeTrace = []
            }) {
                Label("Clear Canvas", systemImage: "trash").foregroundColor(.red)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var rightOutputPanel: some View {
        VStack {
            Text("Output: Fourier Series")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Color.clear
                .aspectRatio(1.0, contentMode: .fit)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .shadow(radius: 5)
                )
                .overlay(
                    Group {
                        if activeEpicycles.isEmpty {
                            Text("Draw something on the left!").foregroundColor(.gray)
                        } else {
                            EpicycleView(epicycles: activeEpicycles, tracePoints: activeTrace, scale: drawingScale)
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .frame(maxWidth: .infinity)
    }
    
    private var topNavigation: some View {
        HStack {
            Button(action: { showInfo = true }) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.blue)
            }
            Spacer()
            Button(action: {
                withAnimation(.spring()) {
                    showDrawer.toggle()
                }
            }) {
                Image(systemName: showDrawer ? "chart.bar.fill" : "chart.bar.xaxis")
                    .font(.system(size: 28))
                    .foregroundColor(.blue)
            }
        }
        .padding()
    }
    
    private var floatingBottomControls: some View {
        VStack {
            Spacer() // Pushes everything to the bottom
            
            HStack(alignment: .bottom, spacing: 16) {
                // 1. Text Input Toggle (Magic Wand)
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        showTextInput.toggle()
                        if !showTextInput { textInput = "" } // Clear on close
                    }
                }) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .padding(16)
                        .background(Color.purple)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 3)
                }
                
                // The Floating Text Input Bar
                if showTextInput {
                    HStack {
                        TextField("Type a shape (e.g., 'heart', 'cube')", text: $textInput)
                            .textFieldStyle(.plain)
                            .focused($isInputFocused)
                            .padding(.vertical, 8)
                            .onSubmit {
                                isInputFocused = false
                                Task { await generateShapeFromText(query: textInput) }
                            }
                        
                        Button(action: {
                            isInputFocused = false
                            Task { await generateShapeFromText(query: textInput) }
                        }) {
                            if isGenerating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(textInput.isEmpty ? .gray : .purple)
                            }
                        }
                        .disabled(textInput.isEmpty || isGenerating)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                    .frame(width: 320)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }
                
                Spacer() // Pushes the controls to the left
                
                // 2. Camera Button
                Button(action: { showCameraSheet = true }) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .padding(16)
                        .background(Color.green)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 3)
                }
                
                // 3. Photo Library Button
                PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .padding(16)
                        .background(Color.blue)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 3)
                }
                .onChange(of: selectedPhotoItem) { newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            try? await processImageWithVision(image: uiImage)
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showCameraSheet) {
                CameraPicker(selectedImage: Binding(
                    get: { nil },
                    set: { newImage in
                        Task {
                            if let newImage = newImage {
                                try? await processImageWithVision(image: newImage)
                            }
                        }
                    }
                ))
                .ignoresSafeArea()
            }
            .padding(24)
            .opacity(showDrawer ? 0.0 : 1.0)
            .animation(.easeInOut, value: showDrawer)
        }
    }
    
    // MARK: - MATH & LOGIC
    
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
    
    func applyFilter() {
        guard !computedEpicycles.isEmpty else {
            activeEpicycles = []
            activeTrace = []
            return
        }
        
        let highestFreq = computedEpicycles.map { abs($0.frequency) }.max() ?? 1
        
        let safeMin = min(minFreqRatio, maxFreqRatio)
        let safeMax = max(minFreqRatio, maxFreqRatio)
        
        let minCutoff = Int(Double(highestFreq) * safeMin)
        let maxCutoff = Int(Double(highestFreq) * safeMax)
        
        activeEpicycles = computedEpicycles.filter {
            let f = abs($0.frequency)
            return f >= minCutoff && f <= maxCutoff
        }
        
        activeTrace = FourierCalculator.reconstructPath(from: activeEpicycles, sampleCount: 512)
    }
    
    @Generable
    struct Output {
        // my output
    }
    
    // MARK: - Foundation Model Integration
    func generateShapeFromText(query: String) async {
        isGenerating = true
        
        let session = LanguageModelSession()
        do {
            let response = try await session.respond(to: "Extract the shape intent from: \(query)")
        } catch {
            print("LLM response has an error.")
        }
        
        let detectedIntent = query.lowercased() 
        var newStroke: [CGPoint] = []
        let center = CGPoint(x: 150, y: 150)
        let sampleCount = 100
        
        switch detectedIntent {
        case "heart":
            for i in 0..<sampleCount {
                let t = (Double(i) / Double(sampleCount)) * 2.0 * .pi
                let x = 16 * pow(sin(t), 3)
                let y = -(13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t))
                newStroke.append(CGPoint(x: (x * 5) + center.x, y: (y * 5) + center.y))
            }
        case "sine":
            for i in 0..<sampleCount {
                let t = (Double(i) / Double(sampleCount)) * 4.0 * .pi
                let x = Double(i) * 2.5
                let y = sin(t) * 50
                newStroke.append(CGPoint(x: x + 50, y: y + center.y))
            }
        default:
            print("Model generated unrecognized shape")
        }
        
        await MainActor.run {
            if !newStroke.isEmpty {
                self.finishedStrokes = [newStroke] 
                self.processSignal()
            }
            self.isGenerating = false
            self.textInput = ""
        }
    }

    func normalizeGroup(strokes: [[CGPoint]], toFit canvasSize: CGSize) -> [[CGPoint]] {
        let allPoints = strokes.flatMap { $0 }
        guard !allPoints.isEmpty else { return [] }
        
        let minX = allPoints.map { $0.x }.min() ?? 0
        let maxX = allPoints.map { $0.x }.max() ?? 0
        let minY = allPoints.map { $0.y }.min() ?? 0
        let maxY = allPoints.map { $0.y }.max() ?? 0
        
        let shapeWidth = maxX - minX
        let shapeHeight = maxY - minY
        guard shapeWidth > 0 && shapeHeight > 0 else { return strokes }
        
        let scaleX = (canvasSize.width * 0.8) / shapeWidth
        let scaleY = (canvasSize.height * 0.8) / shapeHeight
        let scale = min(scaleX, scaleY)
        
        let offsetX = (canvasSize.width - (shapeWidth * scale)) / 2.0 - (minX * scale)
        let offsetY = (canvasSize.height - (shapeHeight * scale)) / 2.0 - (minY * scale)
        
        return strokes.map { stroke in
            stroke.map { CGPoint(x: ($0.x * scale) + offsetX, y: ($0.y * scale) + offsetY) }
        }
    }
    
    func processImageWithVision(image: UIImage) {
        guard let resizedImage = image.resized(to: 1024),
            let cgImage = resizedImage.cgImage else { return }
        
        isProcessingImage = true
        let orientation = CGImagePropertyOrientation(resizedImage.imageOrientation)
        
        DispatchQueue.global(qos: .userInitiated).async {
            defer { DispatchQueue.main.async { isProcessingImage = false } }
            
            do {
                let subjectRequest = VNGenerateForegroundInstanceMaskRequest()
                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
                try handler.perform([subjectRequest])
                
                guard let subjectObservation = subjectRequest.results?.first else { return }
                
                let maskBuffer = try subjectObservation.generateScaledMaskForImage(forInstances: subjectObservation.allInstances, from: handler)
                let ciMask = CIImage(cvPixelBuffer: maskBuffer)
                let context = CIContext()
                guard let maskCGImage = context.createCGImage(ciMask, from: ciMask.extent) else { return }
                
                let contourRequest = VNDetectContoursRequest()
                contourRequest.detectsDarkOnLight = false 
                
                let finalHandler = VNImageRequestHandler(cgImage: maskCGImage, options: [:])
                try finalHandler.perform([contourRequest])
                
                guard let results = contourRequest.results as? [VNContoursObservation],
                    let observation = results.first else { return }
                
                var allExtractedStrokes: [[CGPoint]] = []

                for i in 0..<observation.contourCount {
                    guard let contour = try? observation.contour(at: i) else { continue }
                    
                    var extractedPoints: [CGPoint] = []
                    for point in contour.normalizedPoints {
                        let flippedY = 1.0 - Double(point.y)
                        extractedPoints.append(CGPoint(x: Double(point.x) * 1000.0, y: flippedY * 1000.0))
                    }
                    
                    if extractedPoints.count > 1 {
                        allExtractedStrokes.append(extractedPoints)
                    }
                }
                
                DispatchQueue.main.async {
                    let fittedStrokes = self.normalizeGroup(strokes: allExtractedStrokes, toFit: self.canvasSize)
                    if !fittedStrokes.isEmpty {
                        self.finishedStrokes = fittedStrokes
                        self.processSignal()
                    }
                }
                
            } catch {
                print("Vision pipeline failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - EXTENSIONS & HELPERS

extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

extension UIImage {
    func resized(to maxDimension: CGFloat) -> UIImage? {
        let aspectRatio = self.size.width / self.size.height
        var newSize: CGSize
        
        if self.size.width > self.size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0 
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

struct DrawStroke: Shape {
    var points: [CGPoint]
    var scale: CGFloat = 1.0
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let firstPoint = points.first else { return path }
        
        path.move(to: firstPoint)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path.applying(CGAffineTransform(scaleX: scale, y: scale))
    }
}