//
//  NxvProSyncHandler.swift
//  NX-V
//
//  Created by Philip Bishop on 20/02/2022.
//

import Foundation

class NxvProSynHandler : NxvProSyncActionHandler{
    var flatWan = ""
    
    func handleWanRequest(reqId: String, outputStream: OutputStream) {
        RemoteLogging.log(item: "NxvProSyncHandler:wanRequest")
        AppLog.write(flatWan)
        let resp = reqId + "\n" + flatWan
        send(resp,outputStream: outputStream)
    }
    
    var flatMap = ""
    func handleMapRequest(reqId: String,outputStream: OutputStream) {
        RemoteLogging.log(item: "NxvProSyncHandler:mapRequest")
        AppLog.write(flatMap)
        let resp = reqId + "\n" + flatMap
        send(resp,outputStream: outputStream)
    }
    
    func send(_ message: String,outputStream: OutputStream) {
        let dq = DispatchQueue(label: message)
        dq.asyncAfter(deadline: .now() + 0.5,execute:{
            if let data = message.data(using: .utf8){
                outputStream.write(data: data)
            }
        })
    }
    
    var flatGroups = ""
    func handleGroupsRequest(reqId: String,outputStream: OutputStream) {
        RemoteLogging.log(item: "NxvProSyncHandler:groupsRequest")
        AppLog.write(flatGroups)
        let resp = reqId + "\n" + flatGroups
        send(resp,outputStream: outputStream)
    }
    
    var flatFtp = ""
    func handleStorageRequest(reqId: String,outputStream: OutputStream) {
        RemoteLogging.log(item: "NxvProSyncHandler:storageRequest")
        AppLog.write(flatFtp)
        let resp = reqId + "\n" + flatFtp
        send(resp,outputStream: outputStream)
    }
}
