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
let SERVER_URL = "http://192.168.1.252:8000/" // change this for your server name!!!


/*
 TODO: Show Accuracy after Update Models
 TODO: Predict Tab - Switch between Boosted and Random Forest
 TODO: Predict - Get 3 seconds and send it
 */

import UIKit
import CoreMotion

let AUDIO_BUFFER_SIZE = 1024 * 4 * 15;

class ViewController: UIViewController, URLSessionDelegate {
    
    let audio = AudioModel(buffer_size: AUDIO_BUFFER_SIZE)
    
    // MARK: Class Properties
    lazy var session: URLSession = {
        let sessionConfig = URLSessionConfiguration.ephemeral
        
        sessionConfig.timeoutIntervalForRequest = 5.0
        sessionConfig.timeoutIntervalForResource = 8.0
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
    @IBOutlet weak var dsidLabel: UILabel!
    @IBOutlet weak var largeMotionMagnitude: UIProgressView!
    @IBOutlet weak var soundLabel: UILabel!
    @IBOutlet weak var startButton: UIButton!
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
    
    var dsid:Int = 0 {
        didSet{
            DispatchQueue.main.async{
                // update label when set
                self.dsidLabel.layer.add(self.animation, forKey: nil)
                self.dsidLabel.text = "Current DSID: \(self.dsid)"
            }
        }
    }
    
    @IBAction func magnitudeChanged(_ sender: UISlider) {
        self.magValue = Double(sender.value)
    }

    @objc
    func getAudio(text:String){
        var sounds = self.audio.fftData
        for _ in 0...50{
            sounds += self.audio.fftData
        }
        
        sendFeatures(sounds, withLabel: self.calibrationStage)
    }
    
    func setDelayedWaitingToTrue(_ time:Double){
        self.startButton.isEnabled = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + time, execute: {
            print(self.audio.fftData)
            self.sendFeatures(self.audio.fftData, withLabel: self.calibrationStage)
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
        // setup core motion handlers
        
        dsid = 1 // set this and it will update UI
    }

    //MARK: Get New Dataset ID
    @IBAction func getDataSetId(_ sender: AnyObject) {
        // create a GET request for a new DSID from server
        let baseURL = "\(SERVER_URL)/GetNewDatasetId"
        
        let getUrl = URL(string: baseURL)
        let request: URLRequest = URLRequest(url: getUrl!)
        let dataTask : URLSessionDataTask = self.session.dataTask(with: request,
            completionHandler:{(data, response, error) in
                if(error != nil){
                    print("Response:\n%@",response!)
                }
                else{
                    let jsonDictionary = self.convertDataToDictionary(with: data)
                    
                    // This better be an integer
                    if let dsid = jsonDictionary["dsid"]{
                        self.dsid = dsid as! Int
                    }
                }
                
        })
        
        dataTask.resume() // start the task
        
    }
    
    //MARK: Calibration
    @IBAction func startCalibration(_ sender: AnyObject) {
//        self.isWaitingForMotionData = false // dont do anything yet
//        nextCalibrationStage()
        if(calibrationStage == .notCalibrating){
            calibrationStage = .ambient
            soundLabel.text = "Be Quiet"
//            audio.play()
            setDelayedWaitingToTrue(3.0)
            self.startButton.setTitle("Begin Whispering", for: .normal)
        }
        else if(calibrationStage == .ambient){
            calibrationStage = .whisper
            soundLabel.text = "Whisper"
//            audio.play()
            setDelayedWaitingToTrue(3.0)
            self.startButton.setTitle("Begin Talking", for: .normal)
        }
        else if(calibrationStage == .whisper){
            calibrationStage = .talk
            soundLabel.text = "Talk"
//            audio.play()
            setDelayedWaitingToTrue(3.0)
            self.startButton.setTitle("Begin Yelling", for: .normal)
        }
        else if(calibrationStage == .talk){
            calibrationStage = .yell
            soundLabel.text = "Yell"
//            audio.play()
            setDelayedWaitingToTrue(3.0)
            self.startButton.setTitle("Begin Ambient", for: .normal)
        }
        else if(calibrationStage == .yell){
            calibrationStage = .notCalibrating
            soundLabel.text = "Listening"
            
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
                    
//                    print(jsonDictionary["feature"]!)
//                    print(jsonDictionary["label"]!)
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
//            blinkLabel(upArrow)
            break
        case "['down']":
//            blinkLabel(downArrow)
            break
        case "['left']":
//            blinkLabel(leftArrow)
            break
        case "['right']":
//            blinkLabel(rightArrow)
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
                    
                    if let resubAcc = jsonDictionary["resubAccuracy"]{
                        print("Resubstitution Accuracy is", resubAcc)
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





