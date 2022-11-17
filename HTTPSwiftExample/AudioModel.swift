//
//  AudioModel.swift
//  HTTPSwiftExample
//
//  Created by Kevin Leong on 11/16/22.
//  Copyright © 2022 Eric Larson. All rights reserved.
//

import Foundation
import Accelerate

class AudioModel {
    
    // MARK: Properties
    private var BUFFER_SIZE:Int
    var timeData:[Float]
    var fftData:[Float]
    var isProcessing:Bool
//    private var maxVals:[Float]
//    private var maxFreqsi:[Int]
//    var maxFreqs:[Float]
//    var maxes:[(max: Float, index: Int)]
    
    // MARK: Public Methods
    init(buffer_size:Int) {
        BUFFER_SIZE = buffer_size
        // anything not lazily instatntiated should be allocated here
        timeData = Array.init(repeating: 0.0, count: BUFFER_SIZE)
        fftData = Array.init(repeating: 0.0, count: BUFFER_SIZE / 2)
//        maxVals = Array.init(repeating: 0.0, count: 2)
//        maxFreqsi = Array.init(repeating: 0, count: 2)
//        maxFreqs = Array.init(repeating: 0.0, count: 2)
//        maxes = Array.init(repeating: (0.0, 0), count: 2)
        isProcessing = false
        print(self.audioManager!.samplingRate)
    }
    
    // public function for starting processing of microphone data
    func startMicrophoneProcessing(withFps:Double){
        self.isProcessing = true
        self.audioManager?.inputBlock = self.handleMicrophone
//        print("start:")
//        print(fftData)
        // repeat this fps times per second using the timer class
        Timer.scheduledTimer(timeInterval: 3.0, target: self,
                            selector: #selector(self.runEveryInterval),
                            userInfo: nil,
                            repeats: true)
        
    }
    
    
    // public function for playing from a file reader file
    func startProcesingAudioFileForPlayback(){
        self.audioManager?.outputBlock = self.handleSpeakerQueryWithAudioFile
        self.fileReader?.play()
    }
    
    // Function for playing the sine wave with specific
    func startProcessingSinewaveForPlayback(withFreq:Float=330.0){
        sineFrequency = withFreq
        // Two examples are given that use either objective c or that use swift
        //   the swift code for loop is slightly slower thatn doing this in c,
        //   but the implementations are very similar
        //self.audioManager?.outputBlock = self.handleSpeakerQueryWithSinusoid // swift for loop
        self.audioManager?.setOutputBlockToPlaySineWave(sineFrequency) // c for loop
    }
    
    // You must call this when you want the audio to start being handled by our model
    func play(){
        isProcessing = true
        self.audioManager?.play()
    }
    
    func pause(){
        isProcessing = false
        self.audioManager?.pause()
    }
    
    //GETTER FOR BUFFER
    func getInputBuffer() -> (CircularBuffer){
        return inputBuffer!
    }
    
    // FOR MODULE B
    // This function gets the averages for the left and right of a specific index via an input of a Hz value
//    func getGesture(setHertz: Float) -> (Float, Float){
//        let index = (setHertz/Float(self.audioManager!.samplingRate)) * Float(BUFFER_SIZE) //Get the index of the FFT from the Hz
//
//        let range = 10 // Determines the range of values to determine the baseline averages
//
//        // Min and Max are the lowerst and largest values we compare in this range
//        let min = Int(index) - range < 0 ? 0 : Int(index) - range
//        let max = Int(index) + range >= BUFFER_SIZE ? BUFFER_SIZE-1 : Int(index) + range
//
//        // Store the new values in this new "buffer"
//        let zoomedBuffer = fftData[min...max]
//
//        // Creates a sum for the left hand side of the specific Hz
//        var leftAvg:Float = 0.0
//        for val in min..<Int(index){
//            leftAvg += zoomedBuffer[val]
//        }
//
//        // Creates a sum for the right hand side of the specific Hz
//        var rightAvg:Float = 0.0
//        for val in Int(index)+1..<max{
//            rightAvg += zoomedBuffer[val]
//        }
//
//        // Create the averages for the left and right side and returns those values
//        leftAvg = leftAvg/Float(range-min)
//        rightAvg = rightAvg/(Float(zoomedBuffer.count-range-min))
//        return (leftAvg, rightAvg)
//    }
    
    // Here is an example function for getting the maximum frequency
//    func getMaxFrequencyMagnitude(toIgnore: Int) -> (Int, Float){
//        // this is the slow way of getting the maximum...
//        // you might look into the Accelerate framework to make things more efficient
//        var max:Float = -1000.0
//        var maxi:Int = 0
//        if inputBuffer != nil {
//            for i in 0..<Int(fftData.count){
//                if(i != toIgnore) {
//                    if(fftData[i]>max){
//                        max = fftData[i]
//                        maxi = i
//                    }
//                }
//            }
//        }
//        let frequency = Float(maxi) / Float(BUFFER_SIZE) * Float(self.audioManager!.samplingRate)
//        return (maxi, frequency)
//    }
//    func getMaxInWindow(){
//
////        let size = fftData.count - 50 + 1
//        var output = [Float](repeating: 0.0, count: fftData.count)
//        let windowLength = vDSP_Length(16)
//        let outputCount = vDSP_Length(fftData.count) - windowLength + 1
//        let stride = vDSP_Stride(1)
//        vDSP_vswmax(fftData, stride,
//                    &output, stride,
//                    outputCount,
//                    windowLength)
//
//        var localMaxs:[(max: Float, index: Int)] = []
//        var i = 0, j = 15
//        while(j < outputCount) {
//            if(output[i] == output[j]) {
//                if(output[i] == output[i + 7]) {
//                    localMaxs.append((max: output[i + 7], index: i + 7))
//                }
//            }
//            i += 1
//            j += 1
//        }
//
//        localMaxs.sort(by: {$0.max > $1.max})
//        if localMaxs.count > 0 {
//            maxes[0] = localMaxs[0]
//            for i in 1..<Int(localMaxs.count) {
//                if(localMaxs[i].max != maxes[0].max) {
//                    maxes[1] = localMaxs[i]
//                    break
//                }
//            }
//        }
//
////        let x = output[0 ..< Int(outputCount)]
////        print(output)
////        print(x.max(count: 2))
////        var i = 0
////        var j = 49
////        for _ in 1 ... size{
////            let arr = fftData[i...j]
////            var max = vDSP.indexOfMaximum(arr)
////            if max.0 == 24{
////                max.0 += UInt(i)
////                for i in maxes.indices{
////                        if max.1 > maxes[i].1{
////                            maxes[i] = max
////                        }
////
////                    print(max)
////                }
////            }
////            i += 1
////            j += 1
//
//
//
//
////        }
////        print(maxes)
////        print("----------------------")
//
//    }
    // for sliding max windows, you might be interested in the following: vDSP_vswmax
    
    //==========================================
    // MARK: Private Properties
    private lazy var audioManager:Novocaine? = {
        return Novocaine.audioManager()
    }()
    
    private lazy var fftHelper:FFTHelper? = {
        return FFTHelper.init(fftSize: Int32(BUFFER_SIZE))
    }()
    
    private lazy var outputBuffer:CircularBuffer? = {
        return CircularBuffer.init(numChannels: Int64(self.audioManager!.numOutputChannels),
                                   andBufferSize: Int64(BUFFER_SIZE))
    }()
    
    private lazy var inputBuffer:CircularBuffer? = {
        return CircularBuffer.init(numChannels: Int64(self.audioManager!.numInputChannels),
                                   andBufferSize: Int64(BUFFER_SIZE))
    }()
    
    
    //==========================================
    // MARK: Private Methods
    private lazy var fileReader:AudioFileReader? = {
        
        if let url = Bundle.main.url(forResource: "satisfaction", withExtension: "mp3"){
            var tmpFileReader:AudioFileReader? = AudioFileReader.init(audioFileURL: url,
                                                   samplingRate: Float(audioManager!.samplingRate),
                                                   numChannels: audioManager!.numOutputChannels)
            
            tmpFileReader!.currentTime = 0.0
            print("Audio file succesfully loaded for \(url)")
            return tmpFileReader
        }else{
            print("Could not initialize audio input file")
            return nil
        }
    }()
    
    //==========================================
    // MARK: Model Callback Methods
    @objc
    private func runEveryInterval(){
        if inputBuffer != nil {
            self.inputBuffer!.fetchFreshData(&timeData, withNumSamples: Int64(BUFFER_SIZE))
            
            fftHelper!.performForwardFFT(withData: &timeData, andCopydBMagnitudeToBuffer: &fftData)
        }
//        print(fftData)
    }
    
   
    
    //==========================================
    // MARK: Audiocard Callbacks
    // in obj-C it was (^InputBlock)(float *data, UInt32 numFrames, UInt32 numChannels)
    // and in swift this translates to:
    private func handleMicrophone (data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32) {
//        var max:Float = 0.0
//        if let arrayData = data{
//            for i in 0..<Int(numFrames){
//                if(abs(arrayData[i])>max){
//                    max = abs(arrayData[i])
//                }
//            }
//        }
//        // can this max operation be made faster??
//        print(max)
        
        // copy samples from the microphone into circular buffer
        self.inputBuffer?.addNewFloatData(data, withNumSamples: Int64(numFrames))
    }
    
    private func handleSpeakerQueryWithAudioFile(data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32){
        if let file = self.fileReader{
            
            // read from file, loaidng into data (a float pointer)
            file.retrieveFreshAudio(data,
                                    numFrames: numFrames,
                                    numChannels: numChannels)
            
            // set samples to output speaker buffer
            self.outputBuffer?.addNewFloatData(data,
                                         withNumSamples: Int64(numFrames))
        }
    }
    
    //    _     _     _     _     _     _     _     _     _     _
    //   / \   / \   / \   / \   / \   / \   / \   / \   / \   /
    //  /   \_/   \_/   \_/   \_/   \_/   \_/   \_/   \_/   \_/
    var sineFrequency:Float = 0.0 { // frequency in Hz (changeable by user)
        didSet{
            // if using swift for generating the sine wave: when changed, we need to update our increment
            //phaseIncrement = Float(2*Double.pi*sineFrequency/audioManager!.samplingRate)
            
            // if using objective c: this changes the frequency in the novocain block
            self.audioManager?.sineFrequency = sineFrequency
        }
    }
    private var phase:Float = 0.0
    private var phaseIncrement:Float = 0.0
    private var sineWaveRepeatMax:Float = Float(2*Double.pi)
    
    private func handleSpeakerQueryWithSinusoid(data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32){
        // while pretty fast, this loop is still not quite as fast as
        // writing the code in c, so I placed a function in Novocaine to do it for you
        // use setOutputBlockToPlaySineWave() in Novocaine
        if let arrayData = data{
            var i = 0
            while i<numFrames{
                arrayData[i] = sin(phase)
                phase += phaseIncrement
                if (phase >= sineWaveRepeatMax) { phase -= sineWaveRepeatMax }
                i+=1
            }
        }
    }
}
