//
//  VideoPlayerView.swift
//  NX-V
//
//  Created by Philip Bishop on 05/06/2021.
//

import SwiftUI
import MobileVLCKit

protocol VideoPlayerDimissListener{
    func dimissPlayer()
}

protocol VideoPlayerListemer {
    func positionChanged(time: VLCTime?, remaining: VLCTime?)
    func playerStarted()
    func playerPaused()
    func playerError(status: String)
}

class VlcPlayerNSView : UIView,VLCMediaPlayerDelegate {
    
    var listener: VideoPlayerListemer?
    
    var mediaPlayer: VLCMediaPlayer?
    var playStarted = false
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let vlclIb=VLCLibrary.shared()
        vlclIb.debugLogging=false
        vlclIb.debugLoggingLevel=3
        
        mediaPlayer = VLCMediaPlayer(library: vlclIb)
        mediaPlayer!.delegate = self
        mediaPlayer!.drawable = self
    }
    func stop(){
        mediaPlayer!.stop()
    }
    func pause(){
        mediaPlayer!.pause()
        listener?.playerPaused()
    }
    func resume(){
        
        mediaPlayer!.play()
        listener?.playerStarted()
    }
    func isPlaying() -> Bool {
        return mediaPlayer!.isPlaying
    }
    var currentVideoPath: URL?
    
    func play(filePath: URL,model: VideoPlayerListemer) {
        self.listener = model
        self.currentVideoPath = filePath
        if mediaPlayer!.isPlaying {
            mediaPlayer!.stop()
        }
        playImpl()
    }
    func playImpl(){
        
        let media = VLCMedia(url: currentVideoPath!)
        
        mediaPlayer!.media = media
        
        //translatesAutoresizingMaskIntoConstraints = false
        //isHidden = false
        playStarted = false
        mediaPlayer!.play()
        
        listener?.playerStarted()
    }
    func moveTo(position: Double){
        if mediaPlayer!.isPlaying {
            pause()
            mediaPlayer!.time = VLCTime(int: Int32(position))
            resume()
        }else{
            playImpl()
        }
    }
    
    func mediaPlayerStateChanged(_ aNotification: Notification!) {
        let mps = mediaPlayer!.state
        print("Video",mps.rawValue)
        if mps == VLCMediaPlayerState.error {
            // send a callback
            listener?.playerError(status: "Unable to play video")
            
        }
        if mps == VLCMediaPlayerState.stopped {
            
            //listener?.playerPaused()
            //mediaPlayer?.position = 0
        }
    }
    func mediaPlayerTimeChanged(_ aNotification: Notification!) {
        let time = mediaPlayer!.time
        let remaining = mediaPlayer?.remainingTime
        listener?.positionChanged(time: time,remaining: remaining)
        
        if playStarted == false {
            playStarted = true
            //force a redraw ?
            //eventsAndVideosView?.playerStarted()
            
        }
        
    }
    
    override func removeFromSuperview() {
        mediaPlayer!.stop()
    }
    
    var lastRotationAngle = CGFloat(0)
    
    func rotateNext(){
        var angle = lastRotationAngle + 90
        if angle == 360 {
            angle = 0
        }
        rotateCamera(angle: angle)
    }
    func rotateCamera(angle: CGFloat){
        
        lastRotationAngle = angle
        layer.transform = CATransform3D()
        layer.position = CGPoint(x: frame.midX,y: frame.midY)
        layer.anchorPoint = CGPoint(x: 0.5,y: 0.5);
        
        layer.transform = CATransform3DMakeRotation((.pi / 180) * angle, 0, 0, 1)
    }
    
}

var globalVideoPlayer: VlcPlayerNSView?

struct EmbeddedVideoPlayerView: UIViewRepresentable {
    
    var playerView = VlcPlayerNSView(frame: CGRect.zero)
    
    func makeUIView(context: Context) -> UIView {
        globalVideoPlayer = playerView
        return playerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        print("EmbeddedVideoPlayerView:updateUIView")
        
    }
    
}

class VideoPlayerModel : ObservableObject {
    @Published var title: String = "Loading..."
    @Published var selectedVideoId: Int? = 0
}

struct VideoPlayerView: View, VideoPlayerListemer{
    
    var videoCtrls = VideoPlayerControls()
    var player = EmbeddedVideoPlayerView()
    @ObservedObject var vmodel = VideoPlayerModel()
    @State var hideCtrls = false
    
    
    @Environment(\.colorScheme) var colorScheme
    var iconModel = AppIconModel()
   
    var body: some View {
        GeometryReader { gr in
            
            let isSmallScreen = gr.size.width  < 350
            
            VStack(spacing: 0){
                ZStack(alignment: .bottom){
                    player
                    videoCtrls.hidden(hideCtrls)
                    
                }.background(Color(UIColor.systemBackground))
                
            }
            
        } .background(Color(UIColor.secondarySystemBackground))
            .onAppear(){
                iconModel.initIcons(isDark: colorScheme == .dark )
                
                print("VideoPlayer:onAppear()")
            }
    }
    
    func play(video: CardData){
        print("VideoPlayer:play",video.name,video.id)
        vmodel.selectedVideoId = video.id
        player.playerView.play(filePath: video.filePath, model: self)
        player.playerView.mediaPlayer?.audio.volume = videoCtrls.model.volumeOn ? 100 : 0
    }
    func stop(){
        player.playerView.stop()
    }
    func playerError(status: String) {
        print("VideoPlayerView:playerError",status)
    }
    func playerPaused() {
        videoCtrls.playerStarted(playing: false)
    }
    
    func setTitle(title: String){
        vmodel.title = title
    }
    func playerStarted() {
        videoCtrls.playerStarted(playing: true)
        hideCtrls = false
    }
    func positionChanged(time: VLCTime?, remaining: VLCTime?){
        if time != nil {
            hideCtrls = false
            //print("positionChanged",time!.intValue,remaining!.intValue)
            let duration = time!.intValue + abs(remaining!.intValue)
            videoCtrls.timeChanged(time: time!.stringValue,remaining: remaining!.stringValue,position: Int(time!.intValue),duration: Int(duration))
            
            videoCtrls.playerStarted(playing: true)
        }
    }
}

struct VideoPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        VideoPlayerView()
    }
}
