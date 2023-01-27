//
//  PortScanner.swift
//  iosTestApp
//
//  Created by Philip Bishop on 08/10/2021.
//

import Foundation
import CocoaAsyncSocket

protocol PortScannerListener{
    func onPortFound(port: UInt16)
    func onCompleted()
    func onPortCheckStart(port: UInt16)
}

class PortScanner : NSObject, GCDAsyncSocketDelegate{
    var ipa: String = ""
    var sp: UInt16 = 0
    var ep: UInt16 = 0
    var cp: UInt16 = 0
    var stop = false
    var timeout: Double = 1
    var abort = false
    var listener: PortScannerListener?
    
    var knownPorts: [String]?
    var portIndex = -1
    
    func initKnownPorts(ipAddress: String){
        
        ipa = ipAddress
        knownPorts = FileHelper.getKnownPorts()
        portIndex = 0
        isTestingPort = false
        timeout = 1
        scan()
        RemoteLogging.log(item: "PortScanner:initKnownPorts")
    }
    
    func initAndscan(ipAddress: String,startAt: UInt16,endAt: UInt16){
        ipa = ipAddress
        sp = startAt
        ep = endAt
        cp = sp
        knownPorts = nil
        portIndex = -1
        if startAt == endAt{
            timeout = 5
        }
        isTestingPort = false
        scan()
    }
    
    func scan(){
        abort = false
        let q = DispatchQueue(label: "Scanner")
        q.async {
            self.doScan()
        }
        RemoteLogging.log(item: "PortScanner start " + ipa)
    }
    func cameraExists(host: String,port: UInt16) -> Bool{
        
        return FileHelper.cameraExists(host: host, port: port)
    }
    private func doScan(){
        
        if portIndex != -1{
            cp = UInt16(knownPorts![portIndex])!
        }
        
        AppLog.write("Scanning",cp)
        listener?.onPortCheckStart(port: cp)
        if FileHelper.cameraExists(host: ipa, port: cp){
            AppLog.write("Scanning camera exists",ipa,cp)
            scanNext();
            return
        }
        let socket = GCDAsyncSocket(delegate: self,delegateQueue: DispatchQueue.main)
        do { try socket.connect(toHost: ipa, onPort: cp,withTimeout: timeout)} catch {
            AppLog.write("connect failed",cp)
            
            scanNext()
        }
        
    }
    func scanNext(){
        if abort{
            return
        }
        if portIndex != -1{
            portIndex += 1
            if portIndex < knownPorts!.count{
                doScan()
            }else{
                listener?.onCompleted()
                RemoteLogging.log(item: "PortScanner end tried " + String(knownPorts!.count))
            }
        }else{
            if cp < ep{
                cp += 1
                doScan()
            }else{
                listener?.onCompleted()
            }
        }
        
    }
    var isTestingPort = false
    //MARK: GCDSocketDelegate
    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        if isTestingPort{
            AppLog.write("PortScanner BUG didConnectToHost when isTestingPort == true")
            return
        }
        //AppLog.write("didConnectToHost",host,port)
        RemoteLogging.log(item: "PortScanner connected " + host + ":" + String(port))
        isTestingPort = true
        sock.disconnect()
        tryGetSystemTime()
    }
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        if !isTestingPort{
            AppLog.write("socketDidDisconnect",cp)
            scanNext()
        }
    }
    
    /*
     //MARK: GCDAsyncUdpSocketDelegate
     func udpSocketDidClose(_ sock: GCDAsyncUdpSocket, withError error: Error?) {
     AppLog.write("connect closed",cp)
     }
     func udpSocket(_ sock: GCDAsyncUdpSocket, didNotConnect error: Error?) {
     scanNext()
     }
     func udpSocket(_ sock: GCDAsyncUdpSocket, didConnectToAddress address: Data) {
     AppLog.write("Connected",cp)
     sock.close()
     }
     */
    
    func tryGetSystemTime(){
        
        let soapPacket = getXmlPacket(fileName: "soap_system_time")
        let action = "http://www.onvif.org/ver10/device/wsdl/GetSystemDateAndTime"
        
        //let action = "http://www.onvif.org/ver10/device/wsdl/GetDeviceInformation";
        //let soapPacket = getXmlPacket(fileName: "soap_device_info")
        
        let xAddr = "http://" + ipa + ":" + String(cp) + "/onvif/device_service"
        
        AppLog.write("PortScanner:tryGetSystemTime",xAddr)
        
        let apiUrl = URL(string: xAddr)!
        
        let contentType = "application/soap+xml; charset=utf-8; action=\"" + action + "\"";
        
        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        request.setValue("Connection", forHTTPHeaderField: "Close")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout
        
        let configuration = URLSessionConfiguration.default
        configuration.urlCredentialStorage = nil
        
        let session = URLSession(configuration: configuration)
        
        request.httpBody = soapPacket.data(using: String.Encoding.utf8)
        let task = session.dataTask(with: request) { data, response, error in
            self.isTestingPort = false
            if error != nil {
                
                RemoteLogging.log(item: "PortScanner tryGetSystemTime failed " + self.ipa + ":" + String(self.cp))
                self.scanNext()
                return
            }else{
                
                let fparser = FaultParser()
                fparser.parseRespose(xml: data!)
                if fparser.hasFault(){
                    RemoteLogging.log(item: "PortScanner tryGetSystemTime failed " + fparser.authFault + " " + fparser.faultReason)
                }
                
                let parser = SystemTimeParser()
                parser.parseRespose(xml: data!)
                
                if parser.hasDateTime{
                    RemoteLogging.log(item: "PortScanner FOUND ONVIF PORT " + self.ipa + ":" + String(self.cp))
                    self.listener?.onPortFound(port: self.cp)
                    self.abort = true
                    
                }else{
                    self.scanNext()
                }
                
            }
        }
        task.resume()
    }
    
    func getXmlPacket(fileName: String) -> String{
        if let filepath = Bundle.main.path(forResource: fileName, ofType: "xml") {
            do {
                let contents = try String(contentsOfFile: filepath)
                return contents
            } catch {
                AppLog.write("Failed to load XML from bundle",fileName)
            }
        }
        return ""
    }
    
}
