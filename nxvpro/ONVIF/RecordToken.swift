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
    //MARK: Onboard
    var localRtspFilePath = ""
    //var startOffsetMillis = 0
    var startOffsetPc = Float(0)
    
    //MARK: RemoteStorage
    var fileDate: Date?
    var remoteHost = ""
    var creds: URLCredential?
    var localFilePath = ""
    var cameraName = ""
    
    //MARK: Local
    var card: CardData?
    
    func checkIsComplete() -> Bool{
        return Time.isEmpty == false && Token.isEmpty == false
    }
    func hasReplayUri() -> Bool{
        return localFilePath.isEmpty == false || localRtspFilePath.isEmpty == false || Token == "FTP"
    }
    func getListItemName() -> String{
        if Token == "LOCAL"{
            if let crd = card{
                let label = getTimeString() + " " + crd.name
                return label
            }
        }
        return getTimeString()
    }
    func getFilenameTimeString() -> String{
        let date = getTime()
        var frmt = DateFormatter()
        frmt.dateFormat="ddMMyyyyHHmmsss"
        return frmt.string(from: date!)
    }
    
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
        if Token == "FTP" || Token == "LOCAL"{
            return fileDate
        }
        var frmt = DateFormatter()
        frmt.dateFormat="yyyy-MM-dd'T'HH:mm:ssZ"
        return frmt.date(from: Time)
    }
    func getTimeString() -> String{
        let date = getTime()
        var frmt = DateFormatter()
        frmt.dateFormat="HH:mm:ss"
        return frmt.string(from: date!)
    }
    func getTimeOfDayString() -> String{
        let date = getTime()
        var frmt = DateFormatter()
        frmt.dateFormat="HH:mm:ss"
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
class ReplayToken : Hashable{
    var id: Int
    var token: RecordToken
    var time: String
    init(id: Int,token: RecordToken){
        self.id = id
        self.token = token
        self.time = token.getTimeOfDayString()
        
    }
    
    static func == (lhs: ReplayToken, rhs: ReplayToken) -> Bool {
        return lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
class RecordingCollection: Identifiable {
    let id = UUID()
    var label = ""
    var results: [RecordToken]
    var replayResults: [ReplayToken]
    var orderId = 0
    var isCollasped = true
    
    
    init(orderId: Int,label: String){
        self.orderId = orderId
        self.label = label
        self.results = [RecordToken]()
        self.replayResults = [ReplayToken]()
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
    
    //local storage
    var firstDate: Date?
    var lastDate: Date?
    
    func setLocalRange(_ fd: Date,_ ld: Date){
        firstDate = fd
        lastDate = ld
        
        earliestRecording = getDateTimeString(fd)
        latestRecording = getDateTimeString(ld)
    }
    private func getDateTimeString(_ dt: Date) -> String{
        let frmt = DateFormatter()
        frmt.dateFormat="yyyy-MM-dd HH:mm:ss"
        return frmt.string(from: dt)
    }
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
