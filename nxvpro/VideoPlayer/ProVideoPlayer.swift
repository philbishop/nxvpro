//
//  ProVideoPlayer.swift
//  nxvpro
//
//  Created by Philip Bishop on 23/04/2023.
//

import SwiftUI

protocol ProPlayerEventListener{
    func onDeletVideo(video: URL,title: String)
}

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
    var title: String
    var videoCtrl = ProVideoControls(uid: "CloudPlayer")
    
    
    init(videoUrl: URL,title: String){
        self.videoUrl = videoUrl
        self.title = title
    }
    
    var iconSize = CGFloat(18)
    var body: some View {
        VStack{
            HStack{
                Text(title).foregroundColor(.white)
                    .appFont(.titleBar)
                .padding(8)
                
                Spacer()
                Button(action: {
                    //share
                    showShareSheet(with: [videoUrl])
                    
                    closePlayer()
                    
                    
                    
                }){
                    Image(systemName: "square.and.arrow.up").resizable()
                        .frame(width: iconSize,height: iconSize).padding()
                }
                
                Button(action: {
                    //delete
                    closePlayer()
                    globalProPlayerListener?.onDeletVideo(video: videoUrl, title: title)
                }){
                    Image(systemName: "trash").resizable()
                        .frame(width: 14,height: 16).padding()
                }
                
                Button(action: {
                    
                    closePlayer()
                })
                {
                    Image(systemName: "xmark").resizable()
                        .frame(width: iconSize,height: iconSize).padding()
                }//.foregroundColor(Color.accentColor)
            }
            ZStack{
                
                let ctrlPadding = EdgeInsets(top: 0,leading: 0,bottom:10,trailing: 0 )
                
                GeometryReader { fullView in
                    let cw = fullView.size.width
                    //let ch = fullView.size.height
                    
                        
                    playerView(pw: cw, ctrlPadding: ctrlPadding)
                        
                
                    VStack{
                        Spacer()
                        HStack{
                            Spacer()
                            videoCtrl
                            Spacer()
                        }.padding(ctrlPadding)
                    }
                    
                    
                }.onAppear{
                    
                    videoViewFactory!.startPlayer(uid: uid, url: videoUrl)
                }
                
                
            }
    
        }
        .background(Color.black)
        .ignoresSafeArea(model.isFullScreen ? .all : .init())
    }
    private func playerView(pw: CGFloat,ctrlPadding: EdgeInsets) -> some View{
        ZStack(alignment: .bottom){
            let ph = pw * AppSettings.aspectRatio
            videoViewFactory!.getPlayer(uid: uid, listener: videoCtrl.model)
                .frame(width: pw,height: ph)
                .onAppear{
                    videoCtrl.setListener(listener: self)
                    model.isFullScreen = true
                }
            
            
        }
    }
}

