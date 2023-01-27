//
//  NxvProSyncService.swift
//  NX-V
//
//  Created by Philip Bishop on 20/02/2022.
//

import SwiftUI


final class BonjourResolver: NSObject, NetServiceDelegate {

    typealias CompletionHandler = (Result<(String, Int), Error>) -> Void

    @discardableResult
    static func resolve(service: NetService, completionHandler: @escaping CompletionHandler) -> BonjourResolver {
        precondition(Thread.isMainThread)
        let resolver = BonjourResolver(service: service, completionHandler: completionHandler)
        resolver.start()
        return resolver
    }
    
    private init(service: NetService, completionHandler: @escaping CompletionHandler) {
        // We want our own copy of the service because we’re going to set a
        // delegate on it but `NetService` does not conform to `NSCopying` so
        // instead we create a copy by copying each property.
        let copy = NetService(domain: service.domain, type: service.type, name: service.name)
        self.service = copy
        self.completionHandler = completionHandler
    }
    
    deinit {
        // If these fire the last reference to us was released while the resolve
        // was still in flight.  That should never happen because we retain
        // ourselves on `start`.
        assert(self.service == nil)
        assert(self.completionHandler == nil)
        assert(self.selfRetain == nil)
    }
    
    private var service: NetService? = nil
    private var completionHandler: (CompletionHandler)? = nil
    private var selfRetain: BonjourResolver? = nil
    
    private func start() {
        precondition(Thread.isMainThread)

        guard let service = self.service else { fatalError() }
        service.delegate = self
        service.resolve(withTimeout: 5.0)
        // Form a temporary retain loop to prevent us from being deinitialised
        // while the resolve is in flight.  We break this loop in `stop(with:)`.
        selfRetain = self
    }
    
    func stop() {
        self.stop(with: .failure(CocoaError(.userCancelled)))
    }
    
    private func stop(with result: Result<(String, Int), Error>) {
        precondition(Thread.isMainThread)

        self.service?.delegate = nil
        self.service?.stop()
        self.service = nil

        let completionHandler = self.completionHandler
        self.completionHandler = nil
        completionHandler?(result)
        
        selfRetain = nil
    }
    
    func netServiceDidResolveAddress(_ sender: NetService) {
        let hostName = sender.hostName!
        let port = sender.port
        self.stop(with: .success((hostName, port)))
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        let code = (errorDict[NetService.errorCode]?.intValue)
            .flatMap { NetService.ErrorCode.init(rawValue: $0) }
            ?? .unknownError
        let error = NSError(domain: NetService.errorDomain, code: code.rawValue, userInfo: nil)
        self.stop(with: .failure(error))
    }
}

protocol NxvProSyncActionHandler{
    //MARK: Sync request handlers
    func handleMapRequest(reqId: String,outputStream: OutputStream)
    func handleWanRequest(reqId: String,outputStream: OutputStream)
    func handleGroupsRequest(reqId: String,outputStream: OutputStream)
    func handleStorageRequest(reqId: String,outputStream: OutputStream)
}

class NxvProSyncService : NSObject, NetServiceDelegate, StreamDelegate{
    func netServiceDidStop(_ sender: NetService) {
        AppLog.write(">>>>DidStop")
    }
    func netServiceWillPublish(_ sender: NetService) {
        AppLog.write(">>>>WillPublish");
    }
    func netServiceWillResolve(_ sender: NetService) {
        AppLog.write(">>>>WillResolve")
    }
    func netServiceDidResolveAddress(_ sender: NetService) {
        AppLog.write(">>>>DidResolveAddress")
    }
    func netServiceDidPublish(_ sender: NetService) {
        AppLog.write(">>>> DidPublish <<<<<",service.addresses,service.debugDescription);
        service.startMonitoring()
    }
    func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
        AppLog.write(">>>> DidNotPublish",errorDict)
    }
    func netService(_ sender: NetService, didUpdateTXTRecord data: Data) {
        AppLog.write(">>>> didUpdateTXTRecord")
    }
    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        AppLog.write(">>>> didNotResolve",errorDict)
    }
    func netService(_ sender: NetService, didAcceptConnectionWith inputStream: InputStream, outputStream: OutputStream) {
        AppLog.write(">>>> didAcceptConnectionWith")
        self.inputStream = inputStream
        self.outputStream = outputStream
        
        inputStream.delegate = self
        outputStream.delegate = self
        
        inputStream.schedule(in: .main, forMode: .default)
        outputStream.schedule(in: .main, forMode: .default)
        
        inputStream.open()
        outputStream.open()
        
       
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
                    if message == "request.map"{ 
                        listener?.handleMapRequest(reqId: message, outputStream: self.outputStream)
                    }else if message == "request.wan"{
                        listener?.handleWanRequest(reqId: message, outputStream: self.outputStream)
                    }
                    else if message == "request.groups"{
                        listener?.handleGroupsRequest(reqId: message, outputStream: self.outputStream)
                    }else if message == "request.storage"{
                        listener?.handleStorageRequest(reqId: message, outputStream: self.outputStream)
                    }
                    
                    RemoteLogging.log(item: "NxvProSyncService "+message)
                    AppLog.write(message)
                }
            default: break
            }
        //}
    }
   
    
    
    
    var abort = false
    var service: NetService!
    var inputStream: InputStream!
    var outputStream: OutputStream!
    var listener: NxvProSyncActionHandler?
    
    deinit{
        AppLog.write("deinit NxvProSyncService")
    }
    func stop(){
        if service != nil{
            service.stop()
        }
    }
    
    func start(){
        DispatchQueue.main.asyncAfter(deadline: .now() + 5,execute: {
            self.doStart()
        })
    }
    private func doStart(){
        var host = "local"
        
        service = NetService(domain: host,
                                 type: "_nxv._tcp.",
                                 name: "NX-V",port: 8216)
        service.delegate =  self
        
        let dictData = "NXV-PRO".data(using: String.Encoding.utf8)
        let data = NetService.data(fromTXTRecord: ["key":dictData!])
        AppLog.write("set data: \(service.setTXTRecord(data))")
        self.service.publish(options: NetService.Options.listenForConnections)
        
        BonjourResolver.resolve(service: service) { result in
            switch result {
            case .success(let hostName):
                AppLog.write("did resolve, host: \(hostName)")
                self.service.startMonitoring()
                break
            case .failure(let error):
                AppLog.write("did not resolve, error: \(error)")
                break
            default:
                AppLog.write(result)
                break
            }
    
        
        }
    }
    func send(_ message: String) {
        let dq = DispatchQueue(label: message)
        dq.asyncAfter(deadline: .now() + 0.5,execute:{
            if let data = message.data(using: .utf8){
                self.outputStream.write(data: data)
            }
        })
    }
    
}

