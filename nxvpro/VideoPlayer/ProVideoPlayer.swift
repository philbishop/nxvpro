//
//  ProVideoPlayer.swift
//  nxvpro
//
//  Created by Philip Bishop on 23/04/2023.
//

import SwiftUI
protocol ProVideoPlayerChangeListener{
    func getNextVideo(current: URL) -> RecordToken?
    func getPreviousVideo(current: URL) -> RecordToken?
}

var globalProPlayerChangeListener: ProVideoPlayerChangeListener?

class ProVideoPlayerModel : ObservableObject{
    var videoUrl: URL!
    var nextVideo: RecordToken?
    var prevVideo: RecordToken?
    
    @Published var title: String = ""
    
    func setVideo(videoUrl: URL,title: String){
        self.videoUrl = videoUrl
        self.title = title
        if let gpl = globalProPlayerChangeListener{
            nextVideo = gpl.getNextVideo(current: self.videoUrl)
            prevVideo = gpl.getPreviousVideo(current: self.videoUrl)
        }
    }
    func hasNext() -> Bool{
        if nextVideo == nil{
            return false
        }
        return true
    }
    func hasPrev() -> Bool{
        if prevVideo == nil{
            return false
        }
        return true
    }
}
struct ProVideoPlayer: View, VideoControlsListener{
    
    //MARK: VideoControlsListener
    func toggleAudio(){
        videoViewFactory?.toggleAudio(uid: uid)
    }

    func closePlayer() {
        videoViewFactory!.stopPlayer(uid: uid)
        DispatchQueue.main.async {
            presentationMode.wrappedValue.dismiss()
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
    @ObservedObject var vmodel = ProVideoPlayerModel()
    
    var uid = "CloudPlayer"
    //var videoUrl: URL
    //var title: String
    var videoCtrl = ProVideoControls(uid: "CloudPlayer")
    
    
    init(videoUrl: URL,title: String){
        //self.videoUrl = videoUrl
        //self.title = title
        vmodel.setVideo(videoUrl: videoUrl, title: title)
    }
    
    var iconSize = CGFloat(18)
    var chevronSize = CGFloat(24)
    
    var body: some View {
        VStack{
            HStack{
                Text(vmodel.title).foregroundColor(.white)
                    .appFont(.titleBar)
                .padding(8)
                
                Spacer()
                Button(action: {
                    //share
                    closePlayer()
                    
                    globalProPlayerListener?.onShareVideo(video: vmodel.videoUrl, title: vmodel.title)
                    
                    
                    
                    
                    
                }){
                    Image(systemName: "square.and.arrow.up").resizable()
                        .frame(width: iconSize,height: iconSize).padding()
                }
                
                Button(action: {
                    //delete
                    closePlayer()
                    globalProPlayerListener?.onDeletVideo(video: vmodel.videoUrl, title: vmodel.title)
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
                
                let ctrlPadding = EdgeInsets(top: 0,leading: 0,bottom:40,trailing: 0 )
                
                GeometryReader { fullView in
                    let cw = fullView.size.width
                    let ch = fullView.size.height
                    
                    VStack{
                        if ch > cw{
                            Spacer()
                        }
                        playerView(pw: cw, ctrlPadding: ctrlPadding)
                        Spacer()
                    }
#if os(iOS)
                    .gesture(DragGesture(minimumDistance: 3,coordinateSpace: .local).onEnded{
                        value in
                            let direction = atan2(value.translation.width, value.translation.height)
                            switch direction {
                                case (-Double.pi/4..<Double.pi/4):
                                    debugPrint("Swipe down")
                                    break
                                case (Double.pi/4..<Double.pi*3/4):
                                    debugPrint("Swipe right")
                                
                                //if let gpl = globalProPlayerChangeListener{
                                if let nextTokem = vmodel.nextVideo{
                                        playNextVideo(nextTokem)
                                    }
                                //}
                                    break
                                case (Double.pi*3/4...Double.pi), (-Double.pi..<(-Double.pi*3/4)):
                                    debugPrint("Swipe up")
                                    break
                                case (-Double.pi*3/4..<(-Double.pi/4)):
                                    debugPrint("Swipe left")
                                //if let gpl = globalProPlayerChangeListener{
                                if let nextTokem = vmodel.prevVideo{//gpl.playPrev(current: vmodel.videoUrl){
                                        playNextVideo(nextTokem)
                                        
                                    }
                                //}
                                    break
                                default:
                                    debugPrint("Swipe unknown")
                                    break
                            }
                    })
#endif
                    VStack{
                    
                        Spacer()
                        HStack{
                            Spacer()
                            videoCtrl
                            Spacer()
                        }.padding(ctrlPadding)
                    }
                    
                    
                }.onAppear{
                    
                    videoViewFactory!.startPlayer(uid: uid, url: vmodel.videoUrl)
                }
                
                if vmodel.hasPrev(){
                    HStack{
                        Button(action:{
                            if let pv = vmodel.prevVideo{
                                playNextVideo(pv)
                            }
                        }){
                            Image(systemName: "chevron.left").resizable()
                                .frame(width: chevronSize,height: chevronSize*2)
                        }//.background(bgCol).clipShape(Circle())
                        .buttonStyle(NxvButtonStyle())
                        
                        Spacer()
                    }
                }
                if vmodel.hasNext(){
                    HStack{
                        Spacer()
                        
                        Button(action:{
                            if let nv = vmodel.nextVideo{
                                playNextVideo(nv)
                            }
                        }){
                            Image(systemName: "chevron.right").resizable()
                                .frame(width: chevronSize,height: chevronSize*2)
                        }//.background(bgCol).clipShape(Circle())
                        .buttonStyle(NxvButtonStyle())
                        
                    }
                }
            }
    
        }
        .background(Color.black)
        .ignoresSafeArea(model.isFullScreen ? .all : .init())
    }
    private func playNextVideo(_ nextToken: RecordToken){
        if let nextVideo = nextToken.getReplayUrl(){
            
            DispatchQueue.main.async{
                vmodel.setVideo(videoUrl: nextVideo, title: nextToken.getCardTitle())
                videoViewFactory!.stopPlayer(uid: uid)
                videoViewFactory!.startPlayer(uid: uid, url: nextVideo)
            }
        }
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

