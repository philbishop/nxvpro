//
//  RecordToken.swift
//  NX-V
//
//  Created by Philip Bishop on 06/01/2022.
//

import Foundation

class RecordToken: Identifiable {
    let id = UUID()
    var Token = ""
    var TrackToken = ""
    var Time  = ""
    var ProfileToken = ""
    var ReplayUri  = ""
    var isComplete = false
    var day: Date?
    var storageType = StorageType.onboard
    //MARK: Transient SD Card
    var startOffsetMillis = 0
    
    //MARK: RemoteStorage
    var fileDate: Date?
    var remoteHost = ""
    var creds: URLCredential?
    var localFilePath = ""
    
    func isSupportedVideoType() -> Bool{
        if ReplayUri.hasSuffix(".mp4"){
            return true
        }
        if ReplayUri.hasSuffix(".avi"){
            return true
        }
        //Uncomment to enable playback of stream
        return ReplayUri.starts(with: "rtsp://")
    }
    
    func getTime() -> Date?{
        if Token == "FTP"{
            return fileDate
        }
        var frmt = DateFormatter()
        frmt.dateFormat="yyyy-MM-dd'T'HH:mm:ssZ"
        return frmt.date(from: Time)
    }
    func getTimeString() -> String{
        let date = getTime()
        var frmt = DateFormatter()
        frmt.dateFormat="dd MMM yyyy HH:mm:ss"
        return frmt.string(from: date!)
    }
    func fromFtpCsv(line: String){
        let vals = line.components(separatedBy: ",")
        storageType = .ftp
        Time = vals[0]
        ReplayUri = vals[1]
        remoteHost = vals[2]
        creds = URLCredential(user: vals[3],password: vals[4],persistence: .forSession)
        Token = "FTP"
        //28 Jan 2022 04:22:00
        var frmt = DateFormatter()
        frmt.dateFormat="dd MM yyyy HH:mm:ss"
        
        fileDate = frmt.date(from: Time)
        
    }
    func toFtpCsv() -> String{
        var user = ""
        var pwd = ""
        if let credential = creds{
            user = credential.user!
            pwd = credential.password!
        }
        if Time.isEmpty{
            var frmt = DateFormatter()
            frmt.dateFormat="dd MM yyyy HH:mm:ss"
            Time = frmt.string(from: fileDate!)
        }
        return String(format: "%@,%@,%@,%@,%@",Time,ReplayUri,remoteHost,user,pwd)
    }
    
    func toCsv() -> String{
        return String(format: "%@,%@,%@,%@,%@",Time,Token,TrackToken,ProfileToken,ReplayUri)
    }
    func fromCsv(line: String){
        let vals = line.components(separatedBy: ",")
        Time = vals[0]
        Token = vals[1]
        TrackToken = vals[2]
        ProfileToken = vals[3]
        ReplayUri = vals[4]
    }
}
class RecordingCollection: Identifiable {
    let id = UUID()
    var label = ""
    var results: [RecordToken]
    var orderId = 0
    init(orderId: Int,label: String){
        self.orderId = orderId
        self.label = label
        self.results = [RecordToken]()
    }
    var countLabel:String{
        return String(results.count)
    }
}

class RecordingResults: Identifiable {
    let id = UUID()
    var date: Date
    var camera: Camera
    var results: [RecordToken]
    
    init(date: Date,camera: Camera){
        self.date = date
        self.camera = camera
        results = [RecordToken]()
    }
    
    func addResults(newItems: [RecordToken]){
        for rt in newItems{
            results.append(rt)
        }
    }
}
class RecordProfileToken : Identifiable {
    let id = UUID()
    var recordingToken = ""
    var earliestRecording = ""
    var latestRecording = ""
    var recordingImages = 0
    
    func isComplete() -> Bool{
        return !earliestRecording.isEmpty && !latestRecording.isEmpty
    }
    func isValid() -> Bool{
        if let ed = getEarliestDate(){
            if let ld = getLatestDate(){
                if ed.timeIntervalSince1970 > ld.timeIntervalSince1970{
                    return false
                }
            }
        }
        
        return isComplete() && earliestRecording != latestRecording
    }
    func getEarliestDate() -> Date?{
       return getDate(dateString: earliestRecording)
    }
    func getLatestDate() -> Date?{
       return getDate(dateString: latestRecording)
    }
    func getDate(dateString: String) -> Date?{
        let frmt = DateFormatter()
        frmt.dateFormat="yyyy-MM-dd'T'HH:mm:ssZ"
        return frmt.date(from: dateString)
    }
}
