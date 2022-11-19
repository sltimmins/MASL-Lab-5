//
//  CalibrateVC.swift
//  HTTPSwiftExample
//
//  Created by Kevin Leong on 11/17/22.
//  Copyright © 2022 Eric Larson. All rights reserved.
//

import Foundation
import UIKit

let PREDICT_AUDIO_BUFFER_SIZE = 1024 * 4 * 15;

class PredictVC: UIViewController, URLSessionDelegate {
    // MAKE SESSION
    lazy var session: URLSession = {
        let sessionConfig = URLSessionConfiguration.ephemeral
        
        sessionConfig.timeoutIntervalForRequest = 5.0
        sessionConfig.timeoutIntervalForResource = 8.0
        sessionConfig.httpMaximumConnectionsPerHost = 1
        
        return URLSession(configuration: sessionConfig,
            delegate: self,
            delegateQueue:self.operationQueue)
    }()
    
    // Data Members
    let audio = AudioModel(buffer_size: PREDICT_AUDIO_BUFFER_SIZE)
    var currModel = "randomForest";
    var dsid = 1;
    let operationQueue = OperationQueue()
    var labelVal = "Let's Predict!"
    
    // OUTLETS
    @IBOutlet weak var chooseModelCtrl: UISegmentedControl!
    @IBOutlet weak var modelLabel: UILabel!
    @IBOutlet weak var predictionButton: UIButton!
    @IBOutlet weak var predictionLabel: UILabel!
    
    override func viewDidLoad() {
        self.title = "Predict"
    }
    
    // FOR PREDICTION
    @IBAction func startPredicting(_ sender: Any) {
        setDelayedWaitingToTrue(3.0)
        self.predictionButton.setTitle("Listening...", for: .normal)
        self.predictionLabel.text = self.labelVal
    }
    
    @IBAction func selectModel(_ sender: Any) {
        switch chooseModelCtrl.selectedSegmentIndex
            {
            case 0:
                self.currModel = "randomForest"
            case 1:
                self.currModel = "boosted"
            default:
                break
            }
        print(currModel)
    }
    
    func setDelayedWaitingToTrue(_ time:Double){
        self.predictionButton.isEnabled = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + time, execute: {
            self.audio.fftData.removeLast()
            
            self.getPrediction(self.audio.fftData)
            self.audio.fftData.append(0.0)
            self.predictionButton.isEnabled = true
        })
        
    }
    
    func getPrediction(_ array:[Float]){
        let baseURL = "\(SERVER_URL)/PredictOne"
        let postUrl = URL(string: "\(baseURL)")
        
        // create a custom HTTP POST request
        var request = URLRequest(url: postUrl!)
        
        // data to send in body of post request (send arguments as json)
                                                                        
        let jsonUpload:NSDictionary = ["feature":array, "dsid":self.dsid, "model":self.currModel]
        
        
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
                            self.labelVal = self.displayLabelResponse(labelResponse as! String)
                            DispatchQueue.main.async {
                                self.predictionLabel.text = self.labelVal
                            }
                        }
        })
        postTask.resume() // start the task
        self.predictionButton.setTitle("PREDICT!", for: .normal)
    }
    
    func displayLabelResponse(_ response:String) -> String{
        switch response {
        case "['whisper']":
            print("whispering")
            return "Whispering"
        case "['talk']":
            print("talking")
            return "Talking"
        case "['yell']":
            print("yelling")
            return "Yelling"
        case "['ambient']":
            print("ambient")
            return "Ambient"
        default:
            print("Unknown")
            break
        }
        return "WHAT"
    }
    
    //MARK: Comm with Server
    func sendFeatures(_ array:[Float], withLabel label:String){
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
                    
                }
        })
        postTask.resume() // start the task
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
