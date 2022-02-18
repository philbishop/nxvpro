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
    func dismissAndShare(localPath: URL)
}

protocol VideoPlayerListemer {
    func positionChanged(time: VLCTime?, remaining: VLCTime?)
    func playerStarted()
    func playerPaused()
    func onBuffering(pc: String)
    
    func playerError(status: String)
}
/*
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
    func terminate(){
        //stop callbacks as the window exists
        listener = nil
        
        if let mp = mediaPlayer{
            mp.stop()
           mediaPlayer = nil
        }
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
        guard mediaPlayer != nil else{
            return
        }
        if mediaPlayer!.isPlaying {
            pause()
            mediaPlayer!.time = VLCTime(int: Int32(position))
            resume()
        }else{
            playImpl()
        }
    }
    
    func mediaPlayerStateChanged(_ aNotification: Notification!) {
        if let mp = mediaPlayer{
            let mps = mp.state
            print("VideoPlayerState",mps.rawValue)
            if mps == VLCMediaPlayerState.error {
                // send a callback
                listener?.playerError(status: "Unable to play video")
                
            }
            if mps == VLCMediaPlayerState.stopped {
                
                //listener?.playerPaused()
                //mediaPlayer?.position = 0
            }
        }
    }
    func mediaPlayerTimeChanged(_ aNotification: Notification!) {
        guard mediaPlayer != nil else{
            return
        }
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
        if let mp = mediaPlayer{
            mp.stop()
        }
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
*/

class BaseVideoPlayer: UIView, VLCMediaPlayerDelegate,VLCLibraryLogReceiverProtocol {
    var mediaPlayer: VLCMediaPlayer!
    var vlclIb: VLCLibrary!
    var listener: VideoPlayerListemer?
    
    
    
    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let libVlcArgs = ["--no-osd", "--no-snapshot-preview","--rtsp-tcp"]
        vlclIb=VLCLibrary(options: libVlcArgs)
        vlclIb.debugLogging=true
        vlclIb.debugLoggingLevel=3
        vlclIb.debugLoggingTarget = self
        
        mediaPlayer = VLCMediaPlayer(library: vlclIb)
        mediaPlayer.delegate = self
        mediaPlayer.drawable = self
        
    }
    
    func mediaPlayerTimeChanged(_ aNotification: Notification!) {
        let time = mediaPlayer.time
        let remaining = mediaPlayer.remainingTime
        listener?.positionChanged(time: time,remaining: remaining)
    }
    
    var isRemovedFromSuperView = false
    override func removeFromSuperview() {
        isRemovedFromSuperView = true
        DispatchQueue.main.async {
            self.mediaPlayer.stop()
        }
        
    }
    var hasFirstFrame = false
    
    func handleMessage(_ message: String, debugLevel level: Int32) {
        if hasFirstFrame == false{
            if message.hasPrefix("Buffering"){
                listener?.onBuffering(pc: message)
            }
        }
        if level == 4 && isFirstError && playStarted == false{
            listener?.playerError(status: "Failed to connect to stream")
            
        }
        guard sdcardToken != nil else{
            return
        }
        print(message)
    }
    func isPlaying() -> Bool{
        return mediaPlayer.isPlaying
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
    func moveTo(position: Double){
        if mediaPlayer.isPlaying {
            pause()
            mediaPlayer.time = VLCTime(int: Int32(position))
            resume()
        }else{
            mediaPlayer.time = VLCTime(int: Int32(0))
            mediaPlayer.play()
        }
    }
    func pause(){
        mediaPlayer.pause()
    }
    func resume(){
        mediaPlayer.play()
    }
    
    func play(filePath: URL,listener: VideoPlayerListemer){
        self.listener = listener
        let media = VLCMedia(url: filePath)
        mediaPlayer.media = media
        mediaPlayer.play()
        
    }
    func stop(){
        mediaPlayer.stop()
    }
    
    //MARK: SDCard replay
    var hasStopped = false
    var playStarted = false
    var isFirstError = true
    
    var sdcardToken: RecordToken?
    func playStream(camera: Camera,token: RecordToken){
        hasStopped = false
        playStarted = false
        
        sdcardToken = token
        
        var url = token.ReplayUri
       
        var useVlcAuth = true
        
        if camera.password.isEmpty {
            useVlcAuth = false
            
            url = url.replacingOccurrences(of: "rtsp://", with: "rtsp://"+camera.user+":@")
        
            AppLog.write("Using URL auth",url)
        }
        
        RemoteLogging.log(item: "Connecting to replay Uri " + url)
        
        let media = VLCMedia(url: URL(string: url)!)
        
        if useVlcAuth {
            media.addOption("rtsp-user=" + camera.user)
            media.addOption("rtsp-pwd=" + camera.password)
            media.addOption("rtsp-frame-buffer-size=600000")
            media.addOption("start-time=" + String(token.startOffsetMillis / 1000))
        }
        mediaPlayer.delegate = self
        mediaPlayer.media = media
        
        //translatesAutoresizingMaskIntoConstraints = false
        
        
        isFirstError = true
       
        DispatchQueue(label: "remote_sdplayer").async{
            self.mediaPlayer.play()
            
        }
    }
    var state = -1
    
    func mediaPlayerStateChanged(_ aNotification: Notification!) {
        let mps = mediaPlayer.state
        print("VideoPlayerView:mediaState",mps)
        if mps == VLCMediaPlayerState.error  {
            self.state = 1
            self.listener?.playerError(status: "Failed to connect, error occured")
            return;
        }
        
        if( mps == VLCMediaPlayerState.stopped && hasStopped == false ){
            self.listener?.playerError(status: "Failed to connect, stopped")
            self.state = 1
            self.hasStopped = true
        }
        
        if(mediaPlayer.isPlaying && playStarted == false){
            playStarted = true
            hasStopped = false
            
            let mp = mediaPlayer!
            //AppLog.write("MediaPlayer:videoSize",mp.videoSize)
            //AppLog.write("MediaPlayer",mediaPlayer!.videoSize,frame,bounds)
            
            
            let q = DispatchQueue(label: "replay_video")
            q.async {
                var waitConter = 0
                
                while self.mediaPlayer!.hasVideoOut == false {
                    sleep(1)
                    waitConter += 1
                    
                    if self.isRemovedFromSuperView {
                        print("!>ReportStoragePlayer:isRemovedFromSuperView")
                        //self.listener?.onError(error: "Resources low, unable to open view " + self.theCamera!.getDisplayName())
                        return
                    }
                    if mp.state == VLCMediaPlayerState.paused || mp.state == VLCMediaPlayerState.stopped{
                        self.listener?.playerError(status: "Stream stopped")
                        return
                    }
                    
                }
                self.hasFirstFrame = true
                DispatchQueue.main.async {
                    self.listener?.playerStarted()
                }
                
            }
        }
    }
    
}
struct EmbeddedVideoPlayerView: UIViewRepresentable {
    
    var playerView = BaseVideoPlayer(frame: CGRect.zero)
    
    func makeUIView(context: Context) -> UIView {
        
        //globalVideoPlayer = playerView
        return playerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        print("EmbeddedVideoPlayerView:updateUIView")
        
    }
    
}

class VideoPlayerModel : ObservableObject {
    @Published var title: String = "Loading..."
    @Published var selectedVideoId: Int? = 0
    @Published var status = ""
    
}

struct VideoPlayerView: View, VideoPlayerListemer{
    
    var videoCtrls = VideoPlayerControls()
    var player = EmbeddedVideoPlayerView()
    @ObservedObject var vmodel = VideoPlayerModel()
    @State var hideCtrls = false
    
    
    @Environment(\.colorScheme) var colorScheme
    var iconModel = AppIconModel()
   
    func terminate(){
        //player.playerView.terminate()
    }
    
    var body: some View {
        GeometryReader { gr in
            
            let isSmallScreen = gr.size.width  < 350
            
            VStack(spacing: 0){
                ZStack(alignment: .bottom){
                    player
                    videoCtrls.hidden(hideCtrls)
                    Text(vmodel.status).hidden(vmodel.status.isEmpty)
                }.background(Color(UIColor.systemBackground))
                
            }
            
        } .background(Color(UIColor.secondarySystemBackground))
            .onAppear(){
                iconModel.initIcons(isDark: colorScheme == .dark )
                videoCtrls.setPlayer(player: player.playerView)
                print("VideoPlayer:onAppear()")
            }
    }
    
    func play(video: CardData){
        print("VideoPlayer:play",video.name,video.id)
        playLocal(filePath: video.filePath)
    }
    func playLocal(filePath: URL){
        print("VideoPlayer:playLocal",filePath.path)
        vmodel.selectedVideoId = 0
        player.playerView.play(filePath: filePath,listener: self)
        //player.playerView.play(filePath: filePath, model: self)
        //player.playerView.mediaPlayer?.audio.volume = videoCtrls.model.volumeOn ? 100 : 0
    }
    func playStream(camera: Camera,token: RecordToken){
        print("VideoPlayer:playStream",token.ReplayUri)
        vmodel.status = "Connecting to onboard storage...."
        player.playerView.playStream(camera: camera, token: token)
    }
    func stop(){
        player.playerView.stop()
    }
    func playerError(status: String) {
        print("VideoPlayerView:playerError",status)
        DispatchQueue.main.async{
            vmodel.status = status
        }
    }
    func onBuffering(pc: String){
        if pc.isEmpty == false{
            DispatchQueue.main.async{
                vmodel.status = pc
            }
        }
    }
    func playerPaused() {
        videoCtrls.playerStarted(playing: false)
    }
    
    func setTitle(title: String){
        vmodel.title = title
    }
    func playerStarted() {
        vmodel.status = ""
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
