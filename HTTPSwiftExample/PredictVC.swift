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
    var currModel = "Random Forest";
    var dsid = 1;
    let operationQueue = OperationQueue()
    
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
    }
    
    @IBAction func selectModel(_ sender: Any) {
        switch chooseModelCtrl.selectedSegmentIndex
            {
            case 0:
                self.currModel = "Random Forest"
            case 1:
                self.currModel = "Boosted Tree"
            default:
                break
            }
        print(currModel)
    }
    
    func setDelayedWaitingToTrue(_ time:Double){
        self.predictionButton.isEnabled = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + time, execute: {
            self.audio.fftData.removeLast()
            
            self.sendFeatures(self.audio.fftData, withLabel: self.currModel)
            self.predictionButton.isEnabled = true
        })
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
