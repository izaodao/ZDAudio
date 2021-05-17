//
//  ViewController.swift
//  ZDAudio
//
//  Created by lyuhaoxuan on 05/12/2021.
//  Copyright (c) 2021 lyuhaoxuan. All rights reserved.
//

import Cocoa
import ZDAudio

class ViewController: NSViewController {
    
    @IBOutlet weak var playButton: NSButton!
    @IBOutlet weak var recordButton: NSButton!
    
    @IBOutlet weak var playURL: NSTextField!
    @IBOutlet weak var recordURL: NSTextField!
    
    @IBOutlet weak var progressSlider: NSSlider!
    @IBOutlet weak var timeLabe: NSTextField!
    
    var auManager: AUManager!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        auManager = AUManager.shared()
    }
    
    func play() {
        var playPath: String = playURL.stringValue
        if playPath.isEmpty {
            playPath = playURL.placeholderString!
        }
        
        playPath = playPath.urlDecoded()
        playPath = playPath.urlEncoded()
        
        let url: URL = URL.init(string: playPath)!
        auManager.play(url) { totalTime, currentTime in
            
            if self.progressSlider.maxValue != totalTime {
                self.progressSlider.maxValue = totalTime
            }
            
            self.progressSlider.doubleValue = currentTime
            
            let totalTimeString = self.AudioTimeToString(time: totalTime)
            let currentTimeString = self.AudioTimeToString(time: currentTime)
            print("音频 总时  -->> \(totalTimeString)")
            print("音频 当前  -->> \(currentTimeString)")
            let timeStr = "\(currentTimeString) / \(totalTimeString)"
            self.timeLabe.stringValue = timeStr
        }
    }
    
    func stopPaly() {
        auManager.pausePaly()
    }
    
    func record() {
        var recordPath: String = recordURL.stringValue
        if recordPath.isEmpty {
            recordPath = recordURL.placeholderString!
        }
        
        auManager.record(withSavePath: recordPath) { level, error in
            print("录制音量：\(level)")
        }
    }
    
    func stopRecord() {
        auManager.stopRecord()
    }
    
    @IBAction func playOrEnd(_ sender: NSButton) {
        if sender.state.rawValue == 1 {
            sender.title = "暂停"
            play()
        } else {
            sender.title = "播放"
            stopPaly()
        }
        
    }
    
    @IBAction func recordOrEnd(_ sender: NSButton) {
        if sender.state.rawValue == 1 {
            sender.title = "停止"
            record()
        } else {
            sender.title = "录制"
            stopRecord()
        }
    }
    
    @IBAction func seekToTime(_ sender: NSSlider) {
        auManager.seek(toTime: sender.doubleValue)
    }
    
    func AudioTimeToString(time: Float64) -> String {
        let seconds = Int(time.truncatingRemainder(dividingBy: 60))
        let minutes = Int((time / 60).truncatingRemainder(dividingBy: 60))
        let hours = Int(time / 3600)
        let string: String = "\(hours):\(minutes):\(seconds)"
        return string
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    
}

extension String {
     
    //将原始的url编码为合法的url
    func urlEncoded() -> String {
        let encodeUrlString = self.addingPercentEncoding(withAllowedCharacters:
            .urlQueryAllowed)
        return encodeUrlString ?? ""
    }
     
    //将编码后的url转换回原始的url
    func urlDecoded() -> String {
        return self.removingPercentEncoding ?? ""
    }
}
