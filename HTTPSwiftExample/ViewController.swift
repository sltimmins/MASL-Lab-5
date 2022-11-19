//
//  ViewController.swift
//  HTTPSwiftExample
//
//  Created by Eric Larson on 3/30/15.
//  Copyright (c) 2015 Eric Larson. All rights reserved.
//

// This exampe is meant to be run with the python example:
//              tornado_turiexamples.py 
//              from the course GitHub repository: tornado_bare, branch sklearn_example


// if you do not know your local sharing server name try:
//    ifconfig |grep "inet "
// to see what your public facing IP address is, the ip address can be used here

// CHANGE THIS TO THE URL FOR YOUR LAPTOP
let SERVER_URL = "http://192.168.1.252:8000" // change this for your server name!!!


/*
 TODO: Show Accuracy after Update Models
 */

import UIKit
import CoreMotion

let AUDIO_BUFFER_SIZE = 1024 * 4 * 15;

class ViewController: UIViewController, URLSessionDelegate {
    
    // Create an audio model
    let audio = AudioModel(buffer_size: AUDIO_BUFFER_SIZE)
    
    // MARK: Class Properties
    lazy var session: URLSession = {
        let sessionConfig = URLSessionConfiguration.ephemeral
        
        sessionConfig.timeoutIntervalForRequest = 20.0
        sessionConfig.timeoutIntervalForResource = 20.0
        sessionConfig.httpMaximumConnectionsPerHost = 1
        
        return URLSession(configuration: sessionConfig,
            delegate: self,
            delegateQueue:self.operationQueue)
    }()
    
    let operationQueue = OperationQueue()
    let motionOperationQueue = OperationQueue()
    let calibrationOperationQueue = OperationQueue()
    
    var ringBuffer = RingBuffer()
    let animation = CATransition()
    let motion = CMMotionManager()
    
    var magValue = 0.1
    var isCalibrating = false
    
    var isWaitingForMotionData = false
//
    // Outlets
    @IBOutlet weak var soundLabel: UILabel!
    @IBOutlet weak var startButton: UIButton!
    
    @IBOutlet weak var randomForestAccLabel: UILabel!
    @IBOutlet weak var boostedTreeAccLabel: UILabel!
    
    // Timer for Audio
    private var timer:Timer = Timer()
    
    
    // MARK: Class Properties with Observers
    enum CalibrationStage {
        case notCalibrating
        case whisper
        case talk
        case ambient
        case yell
    }
    
    var calibrationStage:CalibrationStage = .notCalibrating
    
    var dsid = 1
    
    func setDelayedWaitingToTrue(_ time:Double){
        self.startButton.isEnabled = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + time, execute: {
            // Removes an -inf
            self.audio.fftData.removeLast()
            
            self.sendFeatures(self.audio.fftData, withLabel: self.calibrationStage)
            
            //add data to end of buffer
            self.audio.fftData.append(0.0)
            
            self.startButton.isEnabled = true
            if(self.calibrationStage == .yell){
                self.soundLabel.text = "Listening"
            }
        })
    }
    
    func setAsCalibrating(_ label: UILabel){
        label.layer.add(animation, forKey:nil)
        label.backgroundColor = UIColor.red
    }
    
    func setAsNormal(_ label: UILabel){
        label.layer.add(animation, forKey:nil)
        label.backgroundColor = UIColor.white
    }
    func changeLabel(_ text:String){
        soundLabel.text = text
    }
    
    // MARK: View Controller Life Cycle
    override func viewDidLoad() {
        self.title = "Calibrate";
        self.startButton.setTitle("Begin Ambient", for: .normal)
        super.viewDidLoad()
        
        audio.startMicrophoneProcessing(withFps: 10)
        audio.play()
        soundLabel.text = ""
        // create reusable animation
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        animation.type = CATransitionType.fade
        animation.duration = 0.5
        calibrationStage = .notCalibrating
        
        dsid = 1 // set this and it will update UI
    }
    
    //MARK: Calibration
    @IBAction func startCalibration(_ sender: AnyObject) {

        if(calibrationStage == .notCalibrating){
            calibrationStage = .ambient
            soundLabel.text = "Be Quiet"

            setDelayedWaitingToTrue(3.0)
            self.startButton.setTitle("Begin Whispering", for: .normal)
        }
        else if(calibrationStage == .ambient){
            calibrationStage = .whisper
            soundLabel.text = "Whisper"

            setDelayedWaitingToTrue(3.0)
            self.startButton.setTitle("Begin Talking", for: .normal)
        }
        else if(calibrationStage == .whisper){
            calibrationStage = .talk
            soundLabel.text = "Talk"

            setDelayedWaitingToTrue(3.0)
            self.startButton.setTitle("Begin Yelling", for: .normal)
        }
        else if(calibrationStage == .talk){
            calibrationStage = .yell
            soundLabel.text = "Yell"

            setDelayedWaitingToTrue(3.0)
            self.startButton.setTitle("Begin Ambient!", for: .normal)
        }
        else if(calibrationStage == .yell){
            calibrationStage = .notCalibrating
            soundLabel.text = "Calibrate!"
            
        }
        
    }
    
    //MARK: Comm with Server
    func sendFeatures(_ array:[Float], withLabel label:CalibrationStage){
        let baseURL = "\(SERVER_URL)/AddDataPoint"
        let postUrl = URL(string: "\(baseURL)")
        
        // create a custom HTTP POST request
        var request = URLRequest(url: postUrl!)
        
        // data to send in body of post request (send arguments as json)
        let jsonUpload:NSDictionary = ["feature":array,
                                       "label":"\(label)",
                                       "dsid":self.dsid]
        
        print(array.count)
        let requestBody:Data? = self.convertDictionaryToData(with:jsonUpload)
        
        request.httpMethod = "POST"
        request.httpBody = requestBody
        
        let postTask : URLSessionDataTask = self.session.dataTask(with: request,
            completionHandler:{(data, response, error) in
                if(error != nil){
                    if let res = response{
                        print("Response:\n",res)
                    }
                }
                else{
                    let jsonDictionary = self.convertDataToDictionary(with: data)
                    
                }

        })
        
        postTask.resume() // start the task
    }
    
    
    func getPrediction(_ array:[Double]){
        let baseURL = "\(SERVER_URL)/PredictOne"
        let postUrl = URL(string: "\(baseURL)")
        
        // create a custom HTTP POST request
        var request = URLRequest(url: postUrl!)
        
        // data to send in body of post request (send arguments as json)
                                                                        //ADD WHICH MODEL RIHGT FUCKING HERE
        let jsonUpload:NSDictionary = ["feature":array, "dsid":self.dsid]
        
        
        let requestBody:Data? = self.convertDictionaryToData(with:jsonUpload)
        
        request.httpMethod = "POST"
        request.httpBody = requestBody
        
        let postTask : URLSessionDataTask = self.session.dataTask(with: request,
                                                                  completionHandler:{
                        (data, response, error) in
                        if(error != nil){
                            if let res = response{
                                print("Response:\n",res)
                            }
                        }
                        else{ // no error we are aware of
                            let jsonDictionary = self.convertDataToDictionary(with: data)
                            
                            let labelResponse = jsonDictionary["prediction"]!
                            print(labelResponse)
                            self.displayLabelResponse(labelResponse as! String)

                        }
                                                                    
        })
        
        postTask.resume() // start the task
    }
    
    func displayLabelResponse(_ response:String){
        switch response {
        case "['up']":
            break
        case "['down']":
            break
        case "['left']":
            break
        case "['right']":
            break
        default:
            print("Unknown")
            break
        }
    }
    
    func blinkLabel(_ label:UILabel){
        DispatchQueue.main.async {
            self.setAsCalibrating(label)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
                self.setAsNormal(label)
            })
        }
        
    }
    
    @IBAction func makeModel(_ sender: AnyObject) {
                // create a GET request for server to update the ML model with current data
        let baseURL = "\(SERVER_URL)/UpdateModel"
        let query = "?dsid=\(self.dsid)"
        
        let getUrl = URL(string: baseURL+query)
        let request: URLRequest = URLRequest(url: getUrl!)
        let dataTask : URLSessionDataTask = self.session.dataTask(with: request,
              completionHandler:{(data, response, error) in
                // handle error!
                if (error != nil) {
                    if let res = response{
                        print("Response:\n",res)
                    }
                }
                else{
                    let jsonDictionary = self.convertDataToDictionary(with: data)

                    if let resubAcc = jsonDictionary["boosted_resubAccuracy"] as? NSNumber{
                        let boostAcc = String(describing: resubAcc)
                        DispatchQueue.main.async {
                            self.boostedTreeAccLabel.text = "Boosted Tree Accuracy: " + boostAcc
                        }
                        print("Boosted tree resubstitution Accuracy is", resubAcc)
                    }
                    if let resubAcc = jsonDictionary["randomForest_resubAccuracy"] as? NSNumber{
                        let forestAcc = String(describing: resubAcc)
                        DispatchQueue.main.async {
                            self.randomForestAccLabel.text = "Random Forest Accuracy: " + forestAcc
                        }
                        print("Random forest resubstitution Accuracy is", resubAcc)
                    }

                }
                                                                    
        })
        
        dataTask.resume() // start the task
        
    }
    
    //MARK: JSON Conversion Functions
    func convertDictionaryToData(with jsonUpload:NSDictionary) -> Data?{
        do { // try to make JSON and deal with errors using do/catch block
            let requestBody = try JSONSerialization.data(withJSONObject: jsonUpload, options:JSONSerialization.WritingOptions.prettyPrinted)
            return requestBody
        } catch {
            print("json error: \(error.localizedDescription)")
            return nil
        }
    }
    
    func convertDataToDictionary(with data:Data?)->NSDictionary{
        do { // try to parse JSON and deal with errors using do/catch block
            let jsonDictionary: NSDictionary =
                try JSONSerialization.jsonObject(with: data!,
                                              options: JSONSerialization.ReadingOptions.mutableContainers) as! NSDictionary
            
            return jsonDictionary
            
        } catch {
            
            if let strData = String(data:data!, encoding:String.Encoding(rawValue: String.Encoding.utf8.rawValue)){
                            print("printing JSON received as string: "+strData)
            }else{
                print("json error: \(error.localizedDescription)")
            }
            return NSDictionary() // just return empty
        }
    }

}





