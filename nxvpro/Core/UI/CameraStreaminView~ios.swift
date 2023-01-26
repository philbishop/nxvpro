//
//  CameraStreaminView~ios.swift
//  nxvpro
//
//  Created by Philip Bishop on 26/01/2023.
//

import Foundation
import SwiftUI

struct CameraStreamingView: UIViewRepresentable {
    var playerView = BaseNSVlcMediaPlayer(frame: CGRect.zero)
   
    
    init(){
       
    }
    
    init(camera: Camera,listener: VLCPlayerReady){
       
        playerView.theCamera = camera
        playerView.listener = listener
    }
   
    func setListener(listener: VLCPlayerReady){
        playerView.listener = listener
    }
    
    func setCamera(camera: Camera,listener: VLCPlayerReady){
        print("CameraStreamingView:setCamera",camera.name)
        playerView.setVmdEnabled(enabled: false)
        playerView.listener = listener
        play(camera: camera)
    }
    
    func makeUIView(context: Context) -> UIView {
        print("CameraStreamingView:makeUIView",playerView.theCamera?.name)
        return playerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        print("CameraStreamingView:updateUIView",playerView.frame)
        playerView.isHidden = false
        if playerView.isRemovedFromSuperview {
            print("CameraStreamingView:updateUIView isRemovedFromSuperview",playerView.isRemovedFromSuperview)
        }
    
    }
    
    func play(camera: Camera){
        let wasPlaying = playerView.stop(camera: camera)
        if wasPlaying {
            print("CameraStreamingView:play stopped existing stream",camera.getDisplayAddr(),camera.name)
            
        }
        print("CameraStreamingView:play",camera.getDisplayAddr(),camera.name)
        print("CameraStreamingView:body",playerView.frame)
        
        playerView.play(camera: camera)
        
    }
    
    func makeVisible(){
        //testing for multicam view
        playerView.isHidden = false
    }
    func stop(camera: Camera) -> Bool{
        print("CameraStreamingView:stop",camera.getDisplayAddr(),camera.name)
        return playerView.stop(camera: camera)
    }
    func rotateNext() -> Int {
        return playerView.rotateNext()
        
    }
    func setMuted(muted: Bool){
        playerView.setMuted(muted: muted)
    }
    func toggleMute(){
        playerView.toggleMute()
    }
    
    func startStopRecording(camera: Camera) -> Bool {
        return playerView.startStopRecording(camera: camera)
    }
    func isPlaying() -> Bool{
        return playerView.playStarted
    }
    
    //MARK: iPhone specific
    func setSize(size: CGRect){
        print("CameraStreamingView:body:setSize",size);
        playerView.frame = size
    }
}
