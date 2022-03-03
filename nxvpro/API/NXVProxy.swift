//
//  NXVProxy.swift
//  NX-V
//
//  Created by Philip Bishop on 04/06/2021.
//

import SwiftUI
import Foundation
import ZIPFoundation

protocol NXVProxyListener {
    func onReady(proxy: NXVProxy,ready: Bool)
    func onSessionStart(started: Bool)
}

struct CameraFrame{
    var camId: Int
    var frame: Data
    
    init(camId: Int,frame: Data){
        self.camId = camId
        self.frame = frame
    }
}

class NXVProxy{
    
    static var baseUri = "https://xtreme-iot.online/CloudGlu";
    var key: String = ""
    var pin: String = ""
    
    func getCloudUrl() -> String{
        
        return NXVProxy.baseUri + "?glu=" + key
    }
    
    var listener: NXVProxyListener?
    
    var metadata: String = ""
    
    static var instance: NXVProxy?
    static var isRunning: Bool = false
    
    static func addFrame(imagePath: URL,camera: Camera){
        if instance != nil {
            var cams = [Camera]()
            cams.append(camera)
            instance?.setMetaData(cams: cams)
            instance?.newFrame(newFrame: imagePath,cameraID: camera.id)
        }
    }
    
    static func getInstance(listener: NXVProxyListener) -> NXVProxy{
        
        if instance != nil {
            //keep the original listerner
            return instance!
        }
        
        let proxy = NXVProxy()
        proxy.listener = listener
        proxy.loadCredentials()
        
        if proxy.key.isEmpty {
            proxy.createKeyPin()
        }else{
            proxy.listener?.onReady(proxy: proxy,ready: true)
        }
        
        instance = proxy
        return proxy
        
    }
    func hasCredentails() -> Bool {
        return key.isEmpty == false
    }
    static func hasStoredCredentials() -> Bool{
        let sf = NXVProxy.getStorageFile()
        if FileManager.default.fileExists(atPath: sf.path) {
            return true
        }
        return false
    }
    static func getStorageFile() -> URL{
        let storageRoot = FileHelper.getStorageRoot()
        return storageRoot.appendingPathComponent("cglu.dat")
    }
    func loadCredentials(){
        let sf = NXVProxy.getStorageFile()
        if FileManager.default.fileExists(atPath: sf.path) {
            if let creds = try? String(contentsOf: sf, encoding: String.Encoding.utf8) {
                let keyPin = creds.components(separatedBy: "\n")
                if keyPin.count >= 2 {
                    key = keyPin[0]
                    pin = keyPin[1]
                }
            }
        }
    }
    func saveCredentials(){
        let sf = NXVProxy.getStorageFile()
        let data = key+"\n"+pin
        
        do {
            try data.write(to: sf, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
            AppLog.write("NXVProxy:saveCredentials",sf.path,"\(error)")
        }
    }
    func createKeyPin(){
        
        pin = ""
        for _ in 0...5 {
            let randomInt = Int.random(in: 0..<10)
            pin = pin + String(randomInt)
        }
        
        let regUri = NXVProxy.baseUri + "/DeviceProxyHandler.ashx?xop=xgkey";
        let apiUri = URL(string: regUri)!
        
        var request = URLRequest(url: apiUri)
        request.httpMethod = "GET"
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                AppLog.write(error?.localizedDescription ?? "No data")
                self.listener?.onReady(proxy: self,ready: false)
                return
            }else{
            
                //assume already authenticated so skip fault checking
                let resp = String(data: data!, encoding: .utf8)
                AppLog.write("NXVProxy:createKeyPin",resp!)
                
                let parts = resp!.components(separatedBy: "|")
                if (parts[0] == "200"){
                    self.key = parts[2]
                    self.saveCredentials()
                    self.listener?.onReady(proxy: self,ready: true)
                }else{
                    self.listener?.onReady(proxy: self,ready: false)
                }
            }
        }
        task.resume()
    }
    
    func setMetaData(cams: [Camera]){
        metadata = ""
        for i in 0...cams.count-1 {
            let cam = cams[i]
            let rotation = "0"
            let item = "" + String(cam.id) + "|" + cam.name + "|" + (cam.hasPtz() ? "1" : "0") + "|" + rotation + ","
            metadata += item
        }
        
    }
    
    func startStopSession(){
         if NXVProxy.isRunning {
            NXVProxy.isRunning = false
            AppLog.write("NXVProxy:stopSession OK")
            listener?.onSessionStart(started: false)
            return
        }
        let dlogin = NXVProxy.baseUri + "/DeviceProxyHandler.ashx?xop=xdlogin&xkey=" + key + "&xpwd=" + pin;
        let resp = getHttpResp(apiUrl: dlogin)
        if resp.1 {
            AppLog.write("NXVProxy:startSession OK")
        }
        NXVProxy.isRunning = resp.1
        listener?.onSessionStart(started: resp.1)
        
        startBackgroundTask()
    }
    
    func startBackgroundTask(){
        var nextMetaUpload = Date()
        var firstTime = true
        var hasListener = false
        let q = DispatchQueue(label: "nvxproxy_task")
        q.async {
            
            while(NXVProxy.isRunning){
                
                let et = Date().timeIntervalSince(nextMetaUpload)
                if firstTime || et > 3000 {
                    
                    firstTime = false
                    nextMetaUpload = Date()
                    self.uploadMetaData()
                    
                    hasListener = self.hasListeners()
                }
                if hasListener {
                    if self.nextFrame != nil {
                        self.uploadNetFrame()
                    }
                }
                sleep(1)
            }
        }
    }
    func uploadNetFrame(){
        let uploadUrl = NXVProxy.baseUri + "/DeviceProxyHandler.ashx?xop=xnf&xcid=" + String(nextFrame!.camId) + "&xkey=" + key
        let apiUrl = URL(string: uploadUrl)!
        
        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        request.setValue("image/jpg", forHTTPHeaderField: "Content-Type")
        request.httpBody = nextFrame!.frame
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            //do this on completion
            self.busyWithLastFrame = false
            
            if error != nil {
                AppLog.write(error?.localizedDescription ?? "No data")
                return
            }
        }
        task.resume()
        
    }
    func hasListeners() -> Bool{
        let checkUri = NXVProxy.baseUri + "/DeviceProxyHandler.ashx?xop=xhlf&xkey=" + key
        let resp = getHttpResp(apiUrl: checkUri)
        
        return resp.0 == "1"
    }
    func uploadMetaData(){
        let params = "xop=xsmd&xkey=" + key + "&xmd=" + metadata + "&xpin=" + pin
        let metaUri = NXVProxy.baseUri + "/DeviceProxyHandler.ashx?" + params.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        
        let resp = getHttpResp(apiUrl: metaUri)
        AppLog.write("NXVProxy:uploadMetaData",resp.0)
    }
    var busyWithLastFrame = false
    var nextFrame: CameraFrame?
    func newFrame(newFrame: URL,cameraID: Int){
        if busyWithLastFrame {
            return
        }
        
        busyWithLastFrame = true
        
        do{
            
            let frame = try Data(contentsOf: newFrame)
            nextFrame = CameraFrame(camId: cameraID,frame: frame)
            
        }catch{
            
        }
        
        
    }
   
    private func getHttpResp(apiUrl: String) -> (String,Bool) {
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration)
        
        let reply = session.synchronousDataTask(with: URL(string: apiUrl)!)
        if reply.0 != nil{
            
            //let jsonData =   String(data: reply.0!, encoding: .utf8)
            let resp = String(decoding: reply.0!, as: UTF8.self)
            let parts = resp.components(separatedBy: "|")
            
            if (parts[0] == "200"){
                return (parts[2],true)
            }
            return (parts[2],false)
        
        }
        return ("",false)
    }
    
    //MARK: Collect info about possible Nvr devices
    static func logNvrMetaData(camera: Camera){
        /*
        let rtask = DispatchQueue(label: "log_nvr")
        rtask.async {
            logNvrMetaDataImpl(camera: camera)
        }
         */
    }
    private static func logNvrMetaDataImpl(camera: Camera){
       
        do{
            var zipName = camera.getDisplayName()
            zipName = zipName.replacingOccurrences( of:"[^a-zA-Z0-9]", with: "", options: .regularExpression) + ".zip"
            
            let exportDir = FileHelper.getStorageRoot()
            var archiveURL = URL(fileURLWithPath: exportDir.path)
            archiveURL.appendPathComponent(zipName)
            
            if FileManager.default.fileExists(atPath: archiveURL.path) {
                return // already done
            }
            let xmlFiles = FileHelper.getOnvifFilesFor(camera: camera)
            
            if xmlFiles.count == 0{
                return
            }
            
            guard let archive = Archive(url: archiveURL, accessMode: .create) else  {
                return
            }
            
            for file in xmlFiles {
                AppLog.write("logNvrMetaData add file",file.path)
                try archive.addEntry(with: file.lastPathComponent, relativeTo: file.deletingLastPathComponent())
            }
            
            let endpoint = "https://xtreme-iot.online/CloudGlu/DeviceProxyHandler.ashx?xop=nxvnvr&fn=" + zipName
            let apiUrl = URL(string: endpoint)!
            
            let contentType = "application/zip"
            var request = URLRequest(url: apiUrl)
            request.httpMethod = "POST"
            request.setValue("Connection", forHTTPHeaderField: "Close")
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
            
            try request.httpBody = Data(contentsOf: archiveURL)
           
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if error != nil {
                    AppLog.write("NvrMetaData send failed")
                    AppLog.write(error?.localizedDescription ?? "No data")
                    
                }else{
                    AppLog.write("NvrMetaData sent OK")
                }
            }
            task.resume()
        }catch {
            AppLog.write("LogNvrMetaDataImpl failed with error:\(error)")
        }
    }
    //MARK: Send feedback
    static func sendFeedback(comments: String,email: String,incLogs: Bool,callback: @escaping (Bool) -> Void ){
        var appVer = "n/a"
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            appVer = version
        }
        
        //flush the log file
        fflush(stdout)
        
        let exportDir = FileHelper.getStorageRoot()
        
        do {
            //zip files
            let zipName = "nxv_6x.zip"
            var archiveURL = URL(fileURLWithPath: exportDir.path)
            archiveURL.appendPathComponent(zipName)
            
            if FileManager.default.fileExists(atPath: archiveURL.path) {
                try FileManager.default.removeItem(atPath: archiveURL.path)
            }
        
        
            guard let archive = Archive(url: archiveURL, accessMode: .create) else  {
                return callback(false)
            }
            
            let logFile = FileHelper.getPathForFilename(name: FileHelper.stdoutLog)
            let errFile = FileHelper.getPathForFilename(name: FileHelper.errLog)
           
            var files = [errFile,logFile]
        
            if FileManager.default.fileExists(atPath: logFile.path) == false {
                files = []
            }
            let osv = UIDevice.current.systemVersion
            let verInfo = appVer + " (" + osv + ")"
            let deviceIdiom = UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
            let feedback = "iOS: (" + deviceIdiom + ") " + verInfo + "\n" + comments + "\nfrom: " + email
            
            if let txtFile = FileHelper.createTxtFile(name: "comments.txt", contents: feedback) {
                files.append(txtFile)
            }
            
            //add in XML files
            let xmlFiles = FileHelper.getOnvifFiles()
            
            for xml in xmlFiles {
                files.append(xml)
            }
            
            for file in files {
                AppLog.write("Feedback add file",file.path)
               try archive.addEntry(with: file.lastPathComponent, relativeTo: file.deletingLastPathComponent())
            }
      
            
            let endpoint = "https://xtreme-iot.online/CloudGlu//DeviceProxyHandler.ashx?xop=nxv6fb"
            let apiUrl = URL(string: endpoint)!
            
            let contentType = "application/zip"
            
            var request = URLRequest(url: apiUrl)
            request.httpMethod = "POST"
            request.setValue("Connection", forHTTPHeaderField: "Close")
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
            
            try request.httpBody = Data(contentsOf: archiveURL)
           
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if error != nil {
                    AppLog.write(error?.localizedDescription ?? "No data")
                    callback(false)
                }else{
                    AppLog.write("Send feedback OK")
                    callback(true)
                }
            }
            task.resume()
        } catch {
            AppLog.write("Send feedback failed with error:\(error)")
            callback(false)
        }
        
    }
    
    //MARK: Known onvif ports dynamically updated on backedn
    static func downloadOnvifPorts(){
        let regUri = baseUri + "/onvif/ports.txt?dt=" + String(Date().timeIntervalSince1970)
        let apiUri = URL(string: regUri)!
        
        var request = URLRequest(url: apiUri)
        request.httpMethod = "GET"
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                AppLog.write("Failed to download onvif/ports.txt")
                return
            }else{
            
                //assume already authenticated so skip fault checking
                let resp = String(data: data!, encoding: .ascii)
                AppLog.write("NXVProxy:downloadOnvifPorts",resp!)
                
                let portsFile = FileHelper.getPathForFilename(name: "ports.txt")
                
                do{
                    if FileManager.default.fileExists(atPath: portsFile.path){
                        try FileManager.default.removeItem(at: portsFile)
                    }
                    try resp!.write(to: portsFile, atomically: true, encoding: .ascii)
                        AppLog.write("NXVProxy:downloadOnvifPorts ports.txt updated OK")
                }catch{
                    AppLog.write("NXVProxy:downloadOnvifPorts->failed to save")
                }
                
            }
        }
        task.resume()
    }
}
