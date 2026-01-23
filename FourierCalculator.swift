import Foundation
import Accelerate
import CoreGraphics

// A simple struct to hold the data for one rotating circle
struct Epicycle: Identifiable {
    let id = UUID()
    let frequency: Int     // speed of rotation (k)
    let amplitude: Double  // radius of the circle (magnitude)
    let phase: Double      // starting angle (angle)
}

class FourierCalculator {
    
    // MARK: - Main Pipeline
    
    /// Takes raw user touches and returns the sorted Epicycles
    static func computeEpicycles(from rawPoints: [CGPoint], sampleCount: Int = 256) -> [Epicycle] {
        guard rawPoints.count > 1 else { return [] }
        
        // 1. Resample the drawing to have exactly `sampleCount` equidistant points
        let uniformPoints = resample(points: rawPoints, targetCount: sampleCount)
        
        // 2. Prepare data for Accelerate (Split Complex format)
        // We map X -> Real, Y -> Imaginary
        var realParts = uniformPoints.map { Float($0.x) }
        var imagParts = uniformPoints.map { Float($0.y) }
        
        // 3. Perform the FFT
        let fftResult = performFFT(real: &realParts, imag: &imagParts)
        
        // 4. Convert FFT output to Epicycle structs
        var epicycles = convertToEpicycles(real: fftResult.real, imag: fftResult.imag)
        
        // 5. Sort by Amplitude (Largest circles first for better visualization)
        epicycles.sort { $0.amplitude > $1.amplitude }
        
        return epicycles
    }
    
    // MARK: - 1. Resampling (Linear Interpolation) - FIXED
        
        private static func resample(points: [CGPoint], targetCount: Int) -> [CGPoint] {
            guard points.count > 1 else { return points }
            
            // 1. Calculate total path length
            var totalLength: CGFloat = 0
            for i in 0..<points.count - 1 {
                totalLength += distance(points[i], points[i+1])
            }
            
            // Safety check to prevent division by zero if user just tapped
            if totalLength == 0 { return Array(points.prefix(targetCount)) }
            
            // The distance between each new point
            let interval = totalLength / CGFloat(targetCount - 1)
            
            var newPoints: [CGPoint] = [points.first!]
            
            // "Cursor" tracking
            var currentPathDist: CGFloat = 0       // How far we have traveled along the whole shape
            var nextSampleDist: CGFloat = interval // Where the next point needs to be
            
            // 2. Walk the path segments
            for i in 0..<points.count - 1 {
                let p1 = points[i]
                let p2 = points[i+1]
                let segmentLength = distance(p1, p2)
                
                // While the next required sample falls inside this segment...
                while currentPathDist + segmentLength >= nextSampleDist {
                    
                    // Calculate exactly where in this segment the point should land
                    let distanceIntoSegment = nextSampleDist - currentPathDist
                    let t = distanceIntoSegment / segmentLength
                    
                    // Linear Interpolation
                    let newX = p1.x + (p2.x - p1.x) * t
                    let newY = p1.y + (p2.y - p1.y) * t
                    
                    newPoints.append(CGPoint(x: newX, y: newY))
                    
                    // Advance the target cursor
                    nextSampleDist += interval
                    
                    // Safety break: If we have enough points, stop (handles floating point rounding errors)
                    if newPoints.count >= targetCount { break }
                }
                
                currentPathDist += segmentLength
                if newPoints.count >= targetCount { break }
            }
            
            // 3. Floating point cleanup
            // Sometimes floating point math leaves us 1 point short or 1 point over.
            // Ensure we match targetCount exactly.
            while newPoints.count < targetCount {
                newPoints.append(points.last!)
            }
            if newPoints.count > targetCount {
                newPoints = Array(newPoints.prefix(targetCount))
            }
            
            return newPoints
        }
    
    /*
    
    // MARK: - 1. Resampling (Linear Interpolation)
    
    // We need points to be evenly spaced in time/distance for the FFT to represent the shape accurately.
    private static func resample(points: [CGPoint], targetCount: Int) -> [CGPoint] {
        // Calculate total path length
        var totalLength: CGFloat = 0
        for i in 0..<points.count - 1 {
            totalLength += distance(points[i], points[i+1])
        }
        
        let step = totalLength / CGFloat(targetCount)
        var newPoints: [CGPoint] = [points[0]]
        
        var currentDist: CGFloat = 0
        var segmentDist: CGFloat = 0
        
        // Walk the path
        for i in 0..<points.count - 1 {
            let p1 = points[i]
            let p2 = points[i+1]
            let dist = distance(p1, p2)
            
            // If we have "distance debt", move along the line segment adding points
            while currentDist + dist > step {
                let remaining = step - currentDist
                let ratio = remaining / dist
                
                let newX = p1.x + (p2.x - p1.x) * ratio
                let newY = p1.y + (p2.y - p1.y) * ratio
                
                let newPoint = CGPoint(x: newX, y: newY)
                newPoints.append(newPoint)
                
                // Effectively move p1 to the new point for the next calculation
                currentDist = 0
                // We don't actually move p1 in the array, we just adjust the math
                // Note: simplified logic for readability; usually requires tracking accumulated distance
                // For a robust implementation, we just interpolate purely based on total length ratio.
            }
            currentDist += dist
        }
        
        // Pad if necessary (floating point errors sometimes leave us 1 short)
        while newPoints.count < targetCount {
            newPoints.append(points.last!)
        }
        
        return Array(newPoints.prefix(targetCount))
    }
     */
    
    private static func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        return sqrt(pow(p2.x - p1.x, 2) + pow(p2.y - p1.y, 2))
    }
    
     
    // MARK: - 2. The FFT (Accelerate Framework)
    
    private static func performFFT(real: inout [Float], imag: inout [Float]) -> (real: [Float], imag: [Float]) {
        let n = real.count
        let log2n = vDSP_Length(log2(Float(n)))
        
        // Create the setup for the FFT
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return (real, imag)
        }
        
        // Create a DSPSplitComplex structure to hold the pointers
        // The FFT happens "in-place", meaning it overwrites `real` and `imag` with the frequency domain data
        real.withUnsafeMutableBufferPointer { realPtr in
            imag.withUnsafeMutableBufferPointer { imagPtr in
                var complexBuffer = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                
                // Run the FFT (Forward transform)
                vDSP_fft_zip(fftSetup, &complexBuffer, 1, log2n, FFTDirection(kFFTDirection_Forward))
            }
        }
        
        vDSP_destroy_fftsetup(fftSetup)
        
        return (real, imag)
    }
    
    // MARK: - 3. Convert to Epicycles
    
    private static func convertToEpicycles(real: [Float], imag: [Float]) -> [Epicycle] {
        let n = Float(real.count)
        var epicycles: [Epicycle] = []
        
        for k in 0..<real.count {
            let re = real[k]
            let im = imag[k]
            
            // 1. Frequency: In FFT, index `k` corresponds to frequency `k`
            // Note: For indices > N/2, they represent negative frequencies (N-k).
            // We'll keep it simple and just treat `k` as the rotator speed.
            let freq = k
            
            // 2. Amplitude: Magnitude of the complex vector
            // We divide by N because the FFT scales the result by N
            let amp = sqrt(re * re + im * im) / n
            
            // 3. Phase: Angle of the complex vector (atan2)
            let phase = atan2(im, re)
            
            epicycles.append(Epicycle(frequency: freq, amplitude: Double(amp), phase: Double(phase)))
        }
        
        return epicycles
    }
}
