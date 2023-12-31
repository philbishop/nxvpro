//
//  NxvProSyncService.swift
//  nxvpro
//
//  Created by Philip Bishop on 20/02/2022.
//

import SwiftUI

extension OutputStream {
    @discardableResult
    func write(data: Data) -> Int {
        let count = data.count
        return data.withUnsafeBytes {
            write($0.bindMemory(to: UInt8.self).baseAddress!, maxLength: count)
        }
    }
}
extension InputStream {
    private var maxLength: Int { 4096 }
    
    func read(data: inout Data) -> Int {
        var totalReadCount: Int = 0
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: maxLength)
        while hasBytesAvailable {
            let numberOfBytesRead = read(buffer, maxLength: maxLength)
            if numberOfBytesRead < 0 {
                let error = streamError
                AppLog.write(error)
                return totalReadCount
            }
            data.append(buffer, count: numberOfBytesRead)
            totalReadCount += numberOfBytesRead
        }
        return totalReadCount
    }
}
class NetworkHelper{
    static func getIPAddress(wifiOnly: Bool) -> String {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }

                guard let interface = ptr?.pointee else { return "" }
                let addrFamily = interface.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {

                    // wifi = ["en0"]
                    // wired = ["en2", "en3", "en4"]
                    // cellular = ["pdp_ip0","pdp_ip1","pdp_ip2","pdp_ip3"]

                    let name: String = String(cString: (interface.ifa_name))
                    if (wifiOnly && name ==  "en0") || ( name == "en0" || name == "en2" || name == "en3" || name == "en4" || name == "pdp_ip0" || name == "pdp_ip1" || name == "pdp_ip2" || name == "pdp_ip3") {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface.ifa_addr, socklen_t((interface.ifa_addr.pointee.sa_len)), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        return address ?? ""
    }
    static func getHost(data: Data) -> String{
        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        data.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) -> Void in
                let sockaddrPtr = pointer.bindMemory(to: sockaddr.self)
                guard let unsafePtr = sockaddrPtr.baseAddress else { return }
                guard getnameinfo(unsafePtr, socklen_t(data.count), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 else {
                    return
                }
            }
        let ipAddress = String(cString:hostname)
        AppLog.write(ipAddress)
        return ipAddress
    }
}

protocol NxvZeroConfigResultsListener{
    func handleResult(strData: String)
}



class NxvBonjourSession : NSObject, StreamDelegate,URLSessionStreamDelegate{
    
    var service: NetService
    var inputStream: InputStream!
    var outputStream: OutputStream!
    var currentCmd: String?
    var resultsHandler: NxvZeroConfigResultsListener?
   
    init(service: NetService){
        self.service = service
    }
    private func send(_ message: String) {
        if let data = message.data(using: .utf8){
            outputStream.write(data: data)
        }
    }
    
    //MARK: StreamDelegate
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        //if inputStream == aStream {
        AppLog.write(">>>stream",eventCode.rawValue)
            switch eventCode {
            case .hasBytesAvailable:
                var data = Data()
                guard inputStream.read(data: &data) > 0 else { return }
                if let message = String(data: data, encoding: .utf8){
                    resultsHandler?.handleResult(strData: message)
                    AppLog.write("GOT RESPSONSE",message)
                }
            default: break
            }
        //}
    }
    func connect() {
        AppLog.write("NxvBonjourSession:connect",service.hostName,service.port,service.name,service.type)
        
        var host = service.hostName == nil ? "" : service.hostName!
        let wifiAdd = NetworkHelper.getIPAddress(wifiOnly: true)
        let wfp = wifiAdd.components(separatedBy: ".")
        if let address = service.addresses{
            for adr in address{
                let ipa = NetworkHelper.getHost(data: adr)
                let iparts = ipa.components(separatedBy: ".")
                if iparts[0] == wfp[0] && iparts[1] == wfp[1] && iparts[2] == wfp[2]{
                    host = ipa
                    AppLog.write("Connecting to",host)
                    break
                }
                /*
                if ipa == wifiAdd{
                    host = ipa
                    AppLog.write("Connecting to",host)
                    break
                }
                 */
            }
        }
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        let task = session.streamTask(withHostName: host, port: service.port)
        task.resume()
        task.captureStreams()
        
    }

    //URLSessionStreamDelegate
    func urlSession(_ session: URLSession, streamTask: URLSessionStreamTask, didBecome inputStream: InputStream, outputStream: OutputStream) {
        self.outputStream = outputStream
        self.inputStream = inputStream
            
        outputStream.delegate = self
        inputStream.delegate = self
      
        inputStream.schedule(in: .main, forMode: .default)
        outputStream.schedule(in: .main, forMode: .default)
            
        inputStream.open()
        outputStream.open()
        
        if let req = currentCmd{
            AppLog.write("sending request",req)
            send(req)
            currentCmd = nil
        }
        
    }
}

class NetworkServiceWrapper : Identifiable,Hashable{
    static func == (lhs: NetworkServiceWrapper, rhs: NetworkServiceWrapper) -> Bool {
        return lhs.id == rhs.id
    }
    
    var id = UUID()
    var service: NetService
    
    init(service: NetService){
        self.service = service
    }
    func displayStr() -> String{
        
        if let shost = service.hostName{
            return shost.replacingOccurrences(of: ".local", with: "")
        }
        return service.debugDescription
    }
    private func getHostName() -> String?{
        if let address = service.addresses{
            for adr in address{
                let ipa = NetworkHelper.getHost(data: adr)
                if ipa.contains((".local")){
                    return ipa
                }
            }
        }
        return nil
    }
    func hash(into hasher: inout Hasher) {
            hasher.combine(id)

        
        }
}

class NxvProSyncClient : NSObject, NetServiceBrowserDelegate, NetServiceDelegate, ObservableObject{
    
    var serviceBrowser = NetServiceBrowser()
    var resolvedDevices = [NetService]()
    @Published var discoServices = [NetService]()
    @Published var services = [NetworkServiceWrapper]()
    //var currentSession: NxvBonjourSession?
    
    func startDiscovery(){
        serviceBrowser.delegate = self
        serviceBrowser.searchForServices(ofType: "_nxv._tcp.", inDomain: "")
        serviceBrowser.schedule(in: RunLoop.main, forMode: .common)
        
    }
    func mapSync(service: NetService,handler: NxvZeroConfigResultsListener){
        let session = NxvBonjourSession(service: service)
        session.resultsHandler = handler
        session.currentCmd = "request.map"
        session.connect()
}
    func wanSync(service: NetService,handler: NxvZeroConfigResultsListener){
        let session = NxvBonjourSession(service: service)
        session.resultsHandler = handler
        session.currentCmd = "request.wan"
        session.connect()
    }
    func groupsSync(service: NetService,handler: NxvZeroConfigResultsListener){
        let session = NxvBonjourSession(service: service)
        session.resultsHandler = handler
        session.currentCmd = "request.groups"
        session.connect()
    }
    func storageSync(service: NetService,handler: NxvZeroConfigResultsListener){
        let session = NxvBonjourSession(service: service)
        session.resultsHandler = handler
        session.currentCmd = "request.storage"
        session.connect()
    }
    var lock = NSLock()
    //MARK: NetServiceDeleagte
    func netServiceDidResolveAddress(_ sender: NetService) {
        AppLog.write("ServiceAgent",sender.debugDescription)
        if let data = sender.txtRecordData() {
            let dict = NetService.dictionary(fromTXTRecord: data)
            AppLog.write("Resolved: \(dict)",sender.debugDescription,sender.hostName)
            AppLog.write(dict.mapValues { String(data: $0, encoding: .utf8) })
            
            lock.lock()
            
            
            
            let nrd = resolvedDevices.count
            if nrd > 0 {
                var removeItemAt = -1
                
                for i in 0...nrd-1{
                    if resolvedDevices[i].hostName == sender.hostName{
                        removeItemAt = i
                        break
                    }
                }
                
                if removeItemAt >= 0{
                    AppLog.write("Removing existing service ref",sender.hostName)
                    resolvedDevices.remove(at: removeItemAt)
                    services.remove(at: removeItemAt)
                }
            }
            resolvedDevices.append(sender)
            services.append(NetworkServiceWrapper(service: sender))
            
            lock.unlock()
            //currentSession = NxvBonjourSession(service: sender)
            
            /*
            if currentSession == nil{
                 currentSession = NxvBonjourSession(service: sender)
                 currentSession?.connect()
            }
             */
        }
    }
    
    
    //MARK: NetServiceBrowserDelegate
    func netServiceBrowser(_ aNetServiceBrowser: NetServiceBrowser, didFind aNetService: NetService, moreComing: Bool) {
      //Store a reference to aNetService for later use.
        
        AppLog.write(">>>>DISCOVERED SERVICE",aNetService.debugDescription)
        //need to keep reference???
        discoServices.append(aNetService)
        
        //serviceBrowser.stop()
        
        aNetService.delegate = self
        //connects if resolved
        aNetService.resolve(withTimeout: 50)
        
    }
    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        AppLog.write(">>>>netServiceBrowserWillSearch")
    }
    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        AppLog.write(">>>>netServiceBrowserDidStopSearch")
    }
    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        AppLog.write(">>>>netServiceBrowser didRemove",service.type)
        let ns = resolvedDevices.count
        if ns > 0{
            for i in 0...ns-1{
                let ds = resolvedDevices[i]
                if ds.hostName == service.hostName && ds.name == service.name{
                    AppLog.write(">>>>netServiceBrowser removing from list")
                    resolvedDevices.remove(at: i)
                    break
                }
            }
        }
    }
    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        AppLog.write(">>>>netServiceBrowser didNotSearch",errorDict)
    }
    func netServiceBrowser(_ browser: NetServiceBrowser, didFindDomain domainString: String, moreComing: Bool) {
        AppLog.write(">>>>netServiceBrowser didFindDomain",domainString)
    }
    func netServiceBrowser(_ browser: NetServiceBrowser, didRemoveDomain domainString: String, moreComing: Bool) {
        AppLog.write(">>>>netServiceBrowser didRemoveDomain",domainString)
    }
 
    //MARK Helper funcs
    func isThisDevice(service: NetService) -> Bool{
       let myIpa = NetworkHelper.getIPAddress(wifiOnly: true)
        if let address = service.addresses{
            for adr in address{
                let ipa = NetworkHelper.getHost(data: adr)
                if ipa == myIpa{
                    return true
                }
            
            }
        }
        return false
        
    }
}

