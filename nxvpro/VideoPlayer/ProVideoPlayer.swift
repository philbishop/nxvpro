//
//  ProVideoPlayer.swift
//  nxvpro
//
//  Created by Philip Bishop on 23/04/2023.
//

import SwiftUI

struct ProVideoPlayer: View, VideoControlsListener{
    
    //MARK: VideoControlsListener
    func toggleAudio(){
        videoViewFactory?.toggleAudio(uid: uid)
    }

    func closePlayer() {
        DispatchQueue.main.async {
            presentationMode.wrappedValue.dismiss()
            videoViewFactory!.stopPlayer(uid: uid)
           
        }
    }
    func toggleFullScreen(){
        closePlayer()
    }
   
    func playbackRate(rate: Float){
        videoViewFactory!.setPlaybackSpeed(uid: uid,rate: rate)
    }
        
    func moveVideo(seconds: Int,fwd: Bool){
        videoViewFactory!.moveVideo(uid: uid,seconds,fwd)
    }
    
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var model = ProVideoControlsModel()
    var uid = "CloudPlayer"
    var videoUrl: URL
    var videoCtrl = ProVideoControls(uid: "CloudPlayer")
    
    init(videoUrl: URL){
        self.videoUrl = videoUrl
    }
    
    let fsInset = CGFloat(80)
    var body: some View {
        ZStack{
            
            let ctrlPadding = EdgeInsets(top: fsInset,leading: fsInset,bottom: fsInset/2,trailing: fsInset )
            
            GeometryReader { fullView in
                let cw = fullView.size.width
                //let ch = fullView.size.height
                
                ZStack(alignment: .topLeading){

                    playerView(pw: cw, ctrlPadding: ctrlPadding)
                    
                    
                }

            }.onAppear{
                videoCtrl.setListener(listener: self)
                videoViewFactory!.startPlayer(uid: uid, url: videoUrl)
            }
        
        
    
        }.ignoresSafeArea(model.isFullScreen ? .all : .init())
    }
    private func playerView(pw: CGFloat,ctrlPadding: EdgeInsets) -> some View{
        ZStack(alignment: .bottom){
            let ph = pw * AppSettings.aspectRatio
            videoViewFactory!.getPlayer(uid: uid, listener: videoCtrl.model)
                .frame(width: pw,height: ph)
            
            videoCtrl.padding(ctrlPadding)
        }
    }
}

