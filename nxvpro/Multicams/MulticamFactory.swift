//
//  MulticamFactory.swift
//  NXV-IOS
//
//  Created by Philip Bishop on 07/12/2021.
//

import SwiftUI

class MulticamFactory : ObservableObject, VLCPlayerReady{
    
    var favCameras: [Camera]
    var players: [Int: CameraStreamingView]
    var ready: Bool = false
    @Published var playersReady: [Int: Bool]
    @Published var isRecording: [Int: Bool]
    @Published var vmdOn: [Int: Bool]
    @Published var playersReadyStatus: [Int: String]
    
    var delegateListener: VLCPlayerReady?
    
    var camsPerRow = 2
    
    init(){
        self.players = [Int: CameraStreamingView]()
        self.playersReady = [Int: Bool]()
        self.isRecording = [Int: Bool]()
        self.vmdOn = [Int: Bool]()
        self.favCameras = [Camera]()
        self.playersReadyStatus = [Int: String]()
    }
    
    func setCameras(cameras: [Camera]){
        print("MulticamFactory:setCameras",cameras.count)
        
        self.favCameras = cameras
        
        self.players = [Int: CameraStreamingView]()
        self.playersReady = [Int: Bool]()
        self.isRecording = [Int: Bool]()
        self.vmdOn = [Int: Bool]()
        self.playersReadyStatus = [Int: String]()
    }
   
    func stopAll(){
        AppLog.write("MulticamFactory:stopAll")
        for cam in favCameras {
            if self.players[cam.id] != nil {
                players[cam.id]?.stop(camera: cam)
            }
        }
        
        players.removeAll()
    }
    func playAll(){
        AppLog.write("MulticamFactory:playAll",favCameras.count)
        let dq = DispatchQueue(label: "mcplay")
        dq.asyncAfter(deadline: .now() + 0.5, execute: {
            self.playAllImpl()
        })
    }
    private func playAllImpl(){
        
        for cam in favCameras{
            DispatchQueue.main.async {
                if self.players[cam.id] != nil {
                    self.playersReadyStatus[cam.id] = "Connecting to " + cam.getDisplayName() + "..."
                    AppLog.write("MulticamFactory:playWithEvents",cam.name)
                    
                    if cam.hasStreamingUti(){
                        self.players[cam.id]?.play(camera: cam)
                        self.players[cam.id]?.makeVisible()
                    }else{
                        self.playersReadyStatus[cam.id] = "Camera not ready";
                    }
                    
                }
            }
        }
        
    }
    func hasPlayer(camera: Camera) -> Bool{
        return players[camera.id] != nil
    }
    func getPlayer(camera: Camera)-> CameraStreamingView{
        
        if players[camera.id] == nil {
            
            AppLog.write("MulticamFactory:getPlayer created",camera.name)
            let spv = CameraStreamingView(camera: camera, listener: self)
            
            players[camera.id] = spv
            playersReady[camera.id] = false
            playersReadyStatus[camera.id] = "Connecting to " + camera.getDisplayName() + "..."
            isRecording[camera.id] = false
            vmdOn[camera.id] = false
        }
        
        
        return players[camera.id]!
    }
    
    //MARK: VLCPLayerReady
    func onRecordingEnded(camera: Camera) {
        //TO DO
    }
    func onPlayerReady(camera: Camera) {
        AppLog.write("MulticamFactory:onPlayerReady",camera.id,camera.name)
        DispatchQueue.main.async {
            self.playersReady[camera.id] = true
            self.vmdOn[camera.id] = camera.vmdOn
            
            self.delegateListener?.onPlayerReady(camera: camera)
        }
    }
    
    func onBufferring(camera: Camera,pcent: String) {
        DispatchQueue.main.async {
            self.playersReadyStatus[camera.id] = camera.getDisplayName() + " - Connected\n" + pcent
            
        }
    }
    func onRecordingTerminated(camera: Camera) {
        AppLog.write("MulticamFactory:onRecordingTerminated",camera.id,camera.name)
        isRecording[camera.id] = false
        //globalEventListener?.onRecordingTerminated(camera: camera)
    }
    func onSnapshotChanged(camera: Camera) {
        AppLog.write("MulticamFactory:onSnapshotChanged",camera.id,camera.name)
    }
    func onIsAlive(camera: Camera) {
        //nothing to do here
    }
    func connectAuthFailed(camera: Camera) {
        onError(camera: camera, error: "Authentication failed")
    }
    func onError(camera: Camera, error: String) {
        DispatchQueue.main.async {
            self.playersReadyStatus[camera.id] = camera.getDisplayName() + "\nConnection error"
        }
        AppLog.write("MulticamFactory:onError",camera.id,camera.name)
    }
}


