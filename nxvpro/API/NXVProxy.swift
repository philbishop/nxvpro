//
//  NXVProxy.swift
//  NX-V
//
//  Created by Philip Bishop on 04/06/2021.
//

import SwiftUI
import Foundation
import ZIPFoundation
//import SDWebImageWebPCoder

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

class NXVProxyHandler : NXVProxyListener{
    
    var mainProxyListener: NXVProxyListener?
    var multicamProxyListener: NXVProxyListener?
    
    func onSessionStart(started: Bool) {
        mainProxyListener?.onSessionStart(started: started)
        multicamProxyListener?.onSessionStart(started: started)
    }
    func onReady(proxy: NXVProxy, ready: Bool) {
        mainProxyListener?.onReady(proxy: proxy, ready: ready)
        multicamProxyListener?.onReady(proxy: proxy, ready: ready)
    }
}



class NXVProxy{
#if DEBUG_X
    static var baseUri = "https://incax.com/CloudGlu";
    #else
    static var baseUri = "https://incax.com/CloudGlu";
    #endif
  
    var listener: NXVProxyListener?
    
   
    private func getHttpResp(apiUrl: String) -> (String,Bool) {
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration)
        
        let reply = session.synchronousDataTask(with: URL(string: apiUrl)!)
        if reply.0 != nil{
            
            //let jsonData =   String(data: reply.0!, encoding: .utf8)
            let resp = String(decoding: reply.0!, as: UTF8.self)
            let parts = resp.components(separatedBy: "|")
            if parts.count==3{
                if (parts[0] == "200"){
                    return (parts[2],true)
                }
                return (parts[2],false)
            }
        }
        return ("",false)
    }
    
    //MARK: Pro install
    static func sendInstallNotifcationIfNew(){
        #if DEBUG
            return
        #endif
        if FileHelper.installLogExists(){
            return
        }
        let dq = DispatchQueue(label: "instlog")
        dq.async {
            sendFeedback(comments: "App installed", email: "", isFeedback: false) { success in
                
            }
        }
    }
    //MARK: Send feedback
    static func sendFeedback(comments: String,email: String,isFeedback: Bool,callback: @escaping (Bool) -> Void ){
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
           // let errFile = FileHelper.getPathForFilename(name: FileHelper.errLog)
           
            var files = [logFile]
        
            if FileManager.default.fileExists(atPath: logFile.path) == false {
                files = []
            }
            let osv = ProcessInfo.processInfo.operatingSystemVersionString
            let verInfo = appVer + " (" + osv + ")"
            let deviceIdiom = "IOS"
           
            let appName = "NX-V PRO"
            let feedback = appName+": (" + deviceIdiom + ") " + verInfo + "\n" + comments + "\nfrom: " + email
            
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
      
            var zipSize = archiveURL.fileSizeString
            print(zipSize)
            
            var endpoint = NXVProxy.baseUri+"/DeviceProxyHandler.ashx?xop=nxv6fb"
            if isFeedback == false{
                //this is a pro install
                endpoint = endpoint + "&pi=1"
            }
            let apiUrl = URL(string: endpoint)!
            
            let contentType = "application/zip"
            
            var request = URLRequest(url: apiUrl)
            request.httpMethod = "POST"
            request.setValue("Connection", forHTTPHeaderField: "Close")
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
            
            try request.httpBody = Data(contentsOf: archiveURL)
           
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if error != nil || data == nil{
                    AppLog.write(error?.localizedDescription ?? "No data")
                    callback(false)
                }else{
                    if let uResp = response{
                        if let hresp = uResp as? HTTPURLResponse{
                            if hresp.statusCode != 200{
                                callback(false)
                                return
                            }
                        }
                    }
                    if let d = data{
                        if let repsStr = String(data: d, encoding: .utf8){
                            print(repsStr)
                        }
                    }
                    AppLog.write("Send feedback OK")
                    callback(true)
                    
                    if !isFeedback{
                        FileHelper.createInstallLog(item: feedback)
                    }
                }
                    
                FileHelper.deleteZips()
                
                
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
