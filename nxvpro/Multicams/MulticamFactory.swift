//
//  MulticamFactory.swift
//  NXV-IOS
//
//  Created by Philip Bishop on 07/12/2021.
//

import SwiftUI

class MulticamFactory : ObservableObject, VLCPlayerReady{
    
    var favCameras: [Camera]
    var players: [String: MulticamPlayer]
    var ready: Bool = false
    /*
    @Published var playersReady: [String: Bool]
    @Published var isRecording: [String: Bool]
    @Published var vmdOn: [String: Bool]
    @Published var vmdActive: [String: Bool]
    @Published var playersReadyStatus: [String: String]
    */
    var delegateListener: VLCPlayerReady?
    
    var camsPerRow = 2
    var maxTvModeCams = 9
    
    init(){
        self.players = [String: MulticamPlayer]()
        self.favCameras = [Camera]()
        /*
        self.players = [String: CameraStreamingView]()
        self.playersReady = [String: Bool]()
        self.isRecording = [String: Bool]()
        self.vmdOn = [String: Bool]()
        self.vmdActive = [String: Bool]()
       
        self.playersReadyStatus = [String: String]()
         */
    }
   
    /*
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
     */
    func setIsRecording(_ camera: Camera,recording: Bool){
        let uid = camera.getStringUid()
        if let pv = players[uid]{
            pv.model.isRecording = recording
        }
    }
    func isRecording(_ camera: Camera) -> Bool{
        let uid = camera.getStringUid()
        if let pv = players[uid]{
            return pv.model.isRecording
        }
        return false
    }
    func isVmdActive(_ camera: Camera) -> Bool{
        let uid = camera.getStringUid()
        if let pv = players[uid]{
            return pv.model.vmdActive
        }
        return false
    }
    func setVmdOn(_ camera: Camera,isOn: Bool){
        let uid = camera.getStringUid()
        if let pv = players[uid]{
            pv.setVmdOn(isOn)
        }
    }
    func isVmdOn(_ camera: Camera) -> Bool{
        let uid = camera.getStringUid()
        if let pv = players[uid]{
            return pv.model.vmdOn
        }
        return false
    }
    func playersReady(_ camera: Camera) -> Bool{
        let uid = camera.getStringUid()
        if let pv = players[uid]{
            return pv.model.playerReady
        }
        return false
    }
    func isPlayerReady(_ cam: Camera) -> Bool{
        let uid = cam.getStringUid()
        if let pv = players[uid]{
            return pv.model.playerReady
        }
        return false
    }
    func updatePlayersReadyStatus(_ camera: Camera,status: String){
        let uid = camera.getStringUid()
        if let pv = players[uid]{
            
            pv.updateStatus(status)
        }
    }
    func playersReadyStatus(_ camera: Camera) -> String{
        let uid = camera.getStringUid()
        if let pv = players[uid]{
            return pv.model.playerReadyStatus
        }
        return "no status"
    }
    func onMotionEvent(camera: Camera,isStart: Bool){
        let uid = camera.getStringUid()
        if let pv = players[uid]{
            pv.vmdActive(isOn: isStart)
        }
        //self.vmdActive[camera.getStringUid()] = isStart
    }
    func setCameras(cameras: [Camera]){
        AppLog.write("MulticamFactory:setCameras",cameras.count)
        self.players = [String: MulticamPlayer]()
        self.favCameras = cameras
        /*
        self.players = [String: CameraStreamingView]()
        self.playersReady = [String: Bool]()
        self.isRecording = [String: Bool]()
        self.vmdOn = [String: Bool]()
        self.vmdActive = [String: Bool]()
        self.playersReadyStatus = [String: String]()
         */
    }
   
    func stopAll(){
        RemoteLogging.log(item: "MulticamFactory:stopAll")
        for cam in favCameras {
            if self.players[cam.getStringUid()] != nil {
                //players[cam.getStringUid()]?.stop(camera: cam)
                players[cam.getStringUid()]?.player.stop(camera: cam)
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
            if let pv = players[cam.getStringUid()]{
                pv.doPlay()
            }
            /*
            DispatchQueue.main.async {
                
                if self.players[cam.getStringUid()] != nil {
                    self.vmdActive[cam.getStringUid()] = false
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
             */
        }
        
    }
    func hasPlayer(camera: Camera) -> Bool{
        return players[camera.getStringUid()] != nil
    }
    func getExistingPlayer(camera: Camera) ->CameraStreamingView?{
        let uid = camera.getStringUid()
        
        if players[uid] != nil {
            return players[uid]!.player
        }
        return nil
    }
    func getPlayer(camera: Camera)-> MulticamPlayer{
        
        if players[camera.getStringUid()] == nil {
            
            AppLog.write("MulticamFactory:getPlayer created",camera.name)
            let spv = MulticamPlayer(camera: camera, listener: self)
            players[camera.getStringUid()] = spv
            /*
            let spv = CameraStreamingView(camera: camera, listener: self)
            
            players[camera.getStringUid()] = spv
            playersReady[camera.getStringUid()] = false
            playersReadyStatus[camera.getStringUid()] = "Connecting to " + camera.getDisplayName() + "..."
            isRecording[camera.getStringUid()] = false
            vmdOn[camera.getStringUid()] = false
            vmdActive[camera.getStringUid()] = false
             */
        }
        
        
        return players[camera.getStringUid()]!
    }
     
    //MARK: VLCPlayerReady
    func reconnectToCamera(camera: Camera,delayFor: Double){
        if let pv = players[camera.getStringUid()]{
            pv.doPlay()
        }
        /*
        if players[camera.getStringUid()] != nil{
            //AppLog.write("MulticamFactory:reconnectToCamera",camera.getDisplayName() + " " + camera.getDisplayAddr())
            
            //vmdEvent[camera.getStringUid()] = false
            players[camera.getStringUid()]!.stop(camera: camera)
            playersReady[camera.getStringUid()]! = false
            isRecording[camera.getStringUid()] = false
            
            playersReadyStatus[camera.getStringUid()]! = "Reconnecting to camera..."
            let player = self.getPlayer(camera: camera)
            let waitFor = player.playerView.getRetryWaitTime()
            DispatchQueue.main.asyncAfter(deadline: .now() + waitFor, execute: {
                
                player.play(camera: camera)
            })
        }else{
            AppLog.write("MulticamFactory:reconnectToCamera camera not found");
        }
         */
    }
    
    func onIsAlive(camera: Camera) {
        
    }
    func onRecordingEnded(camera: Camera) {
        //TO DO
    }
    func onPlayerReady(camera: Camera) {
        RemoteLogging.log(item: "onPlayerReady "+camera.getStringUid() + " " + camera.name)
        DispatchQueue.main.async {
            if let pv = self.players[camera.getStringUid()]{
                pv.playerReady(ready: true)
            }
            self.delegateListener?.onPlayerReady(camera: camera)
            /*
            self.playersReady[camera.getStringUid()] = true
            self.vmdOn[camera.getStringUid()] = camera.vmdOn
            self.vmdActive[camera.getStringUid()] = false
            self.delegateListener?.onPlayerReady(camera: camera)
            */
        }
    }
    
    func onBufferring(camera: Camera,pcent: String) {
        DispatchQueue.main.async {
            if let pv = self.players[camera.getStringUid()]{
                pv.updateStatus(camera.getDisplayName() + " - Connected\n" + pcent)
            }
            //self.playersReadyStatus[camera.getStringUid()] = camera.getDisplayName() + " - Connected\n" + pcent
            
        }
    }
    func onRecordingTerminated(camera: Camera, isTimeout: Bool){
        AppLog.write("MulticamFactory:onRecordingTerminated",camera.getStringUid(),camera.name)
        //isRecording[camera.getStringUid()] = false
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
            self.reconnectToCamera(camera: camera,delayFor: 1)
        }
        AppLog.write("MulticamFactory:onError",camera.getStringUid(),camera.name)
    }
}


