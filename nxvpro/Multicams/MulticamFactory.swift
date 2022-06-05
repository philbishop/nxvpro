//
//  MulticamFactory.swift
//  NXV-IOS
//
//  Created by Philip Bishop on 07/12/2021.
//

import SwiftUI

class MulticamFactory : ObservableObject, VLCPlayerReady{
    
    var favCameras: [Camera]
    var players: [String: CameraStreamingView]
    var ready: Bool = false
    @Published var playersReady: [String: Bool]
    @Published var isRecording: [String: Bool]
    @Published var vmdOn: [String: Bool]
    @Published var playersReadyStatus: [String: String]
    
    var delegateListener: VLCPlayerReady?
    
    var camsPerRow = 2
    
    init(){
        self.players = [String: CameraStreamingView]()
        self.playersReady = [String: Bool]()
        self.isRecording = [String: Bool]()
        self.vmdOn = [String: Bool]()
        self.favCameras = [Camera]()
        self.playersReadyStatus = [String: String]()
    }
    func reconnectToCamera(camera: Camera){
        if players[camera.getStringUid()] != nil{
            players[camera.getStringUid()]!.stop(camera: camera)
            isRecording[camera.getStringUid()] = false
            
            let player = self.getPlayer(camera: camera)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                
                player.play(camera: camera)
            })
        }
    }
    func setCameras(cameras: [Camera]){
        print("MulticamFactory:setCameras",cameras.count)
        
        self.favCameras = cameras
        
        self.players = [String: CameraStreamingView]()
        self.playersReady = [String: Bool]()
        self.isRecording = [String: Bool]()
        self.vmdOn = [String: Bool]()
        self.playersReadyStatus = [String: String]()
    }
   
    func stopAll(){
        RemoteLogging.log(item: "MulticamFactory:stopAll")
        for cam in favCameras {
            if self.players[cam.getStringUid()] != nil {
                players[cam.getStringUid()]?.stop(camera: cam)
            }
        }
        
        players.removeAll()
    }
    func playAll(){
        RemoteLogging.log(item: "MulticamFactory:playAll " + String(favCameras.count))
        
        let dq = DispatchQueue(label: "mcplay")
        dq.asyncAfter(deadline: .now() + 0.5, execute: {
            self.playAllImpl()
        })
    }
    private func playAllImpl(){
        
        for cam in favCameras{
            DispatchQueue.main.async {
                if self.players[cam.getStringUid()] != nil {
                    self.playersReadyStatus[cam.getStringUid()] = "Connecting to " + cam.getDisplayName() + "..."
                    AppLog.write("MulticamFactory:playWithEvents",cam.name)
                    
                    if cam.hasStreamingUti(){
                        self.players[cam.getStringUid()]?.play(camera: cam)
                        self.players[cam.getStringUid()]?.makeVisible()
                    }else{
                        self.playersReadyStatus[cam.getStringUid()] = "Camera not ready";
                    }
                    
                }
            }
        }
        
    }
    func hasPlayer(camera: Camera) -> Bool{
        return players[camera.getStringUid()] != nil
    }
    func getPlayer(camera: Camera)-> CameraStreamingView{
        
        if players[camera.getStringUid()] == nil {
            
            AppLog.write("MulticamFactory:getPlayer created",camera.name)
            let spv = CameraStreamingView(camera: camera, listener: self)
            
            players[camera.getStringUid()] = spv
            playersReady[camera.getStringUid()] = false
            playersReadyStatus[camera.getStringUid()] = "Connecting to " + camera.getDisplayName() + "..."
            isRecording[camera.getStringUid()] = false
            vmdOn[camera.getStringUid()] = false
        }
        
        
        return players[camera.getStringUid()]!
    }
     
    //MARK: VLCPLayerReady
    func onRecordingEnded(camera: Camera) {
        //TO DO
    }
    func onPlayerReady(camera: Camera) {
        RemoteLogging.log(item: "onPlayerReady "+camera.getStringUid() + " " + camera.name)
        DispatchQueue.main.async {
            self.playersReady[camera.getStringUid()] = true
            self.vmdOn[camera.getStringUid()] = camera.vmdOn
            
            self.delegateListener?.onPlayerReady(camera: camera)
            
        }
    }
    
    func onBufferring(camera: Camera,pcent: String) {
        DispatchQueue.main.async {
            self.playersReadyStatus[camera.getStringUid()] = camera.getDisplayName() + " - Connected\n" + pcent
            
        }
    }
    func onRecordingTerminated(camera: Camera) {
        AppLog.write("MulticamFactory:onRecordingTerminated",camera.getStringUid(),camera.name)
        isRecording[camera.getStringUid()] = false
        //globalEventListener?.onRecordingTerminated(camera: camera)
    }
    func onSnapshotChanged(camera: Camera) {
        //AppLog.write("MulticamFactory:onSnapshotChanged",camera.getStringUid(),camera.name)
        globalCameraEventListener?.onSnapshotChanged(camera: camera)
    }
    func autoSelectCamera(camera: Camera) {
        //nothing to do here
    }
    func connectAuthFailed(camera: Camera) {
        onError(camera: camera, error: "Authentication failed")
    }
    func onError(camera: Camera, error: String) {
        DispatchQueue.main.async {
            self.playersReadyStatus[camera.getStringUid()] = camera.getDisplayName() + "\nConnection error"
        }
        AppLog.write("MulticamFactory:onError",camera.getStringUid(),camera.name)
    }
}


