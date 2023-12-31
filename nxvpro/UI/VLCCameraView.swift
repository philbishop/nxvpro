//
//  VLCCameraView.swift
//  NXV-IOS
//
//  Created by Philip Bishop on 19/06/2021.
//

import SwiftUI
import MobileVLCKit
import AVFoundation

var vlcLoggerEnabled = true

class NxVlcLogger :  NSObject, VLCLogging{
    var level: VLCLogLevel
    var delegate: BaseNSVlcMediaPlayer?
    
   
    init(level: VLCLogLevel) {
        self.level = level
        
    }
    
    func handleMessage(_ message: String, logLevel level: VLCLogLevel, context: VLCLogContext?) {
        #if DEBUG_X
        print("XVLC:",message,level.rawValue)
        #endif
        if let handler = delegate{
            handler.handleMessage(message, debugLevel: level.rawValue)
            
        }
    }
    
}

protocol VLCPlayerReady {
    func onPlayerReady(camera: Camera)
    func onBufferring(camera: Camera,pcent: String)
    
    func onSnapshotChanged(camera: Camera)
    func onError(camera: Camera,error: String)
    func connectAuthFailed(camera: Camera)
    func onRecordingTerminated(camera: Camera)
    func onRecordingEnded(camera: Camera)
    func reconnectToCamera(camera: Camera)
    func autoSelectCamera(camera: Camera)
}

class BaseNSVlcMediaPlayer: UIView, VLCMediaPlayerDelegate, MotionDetectionListener,VLCLibraryLogReceiverProtocol {
    var mediaPlayer: VLCMediaPlayer?
    var listener: VLCPlayerReady?
    var motionListener: MotionDetectionListener?
    
    var theCamera: Camera?
    var vlclIb: VLCLibrary!
    var state: Int = -1
    var aniRotate = true
    var playStarted = false
    var hasFirstFrame = false
    var isInitialized = false
    var hasAuthError = false
    
    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let libVlcArgs = ["--no-osd", "--no-snapshot-preview","--rtsp-tcp"]
        vlclIb=VLCLibrary(options: libVlcArgs)//.shared()
        
        if vlcLoggerEnabled{
            let logger = NxVlcLogger(level: .debug)
            logger.delegate = self
            vlclIb.loggers = [logger]
        }else{
            vlclIb.debugLogging=true
            vlclIb.debugLoggingLevel=3
            vlclIb.debugLoggingTarget = self
        }
        
        mediaPlayer = VLCMediaPlayer(library: vlclIb)
        mediaPlayer!.delegate = self
        mediaPlayer!.drawable = self
    }
    
    //MARK: VLC Capture default filename part
    var baseVideoFilename = ""
    func setBaseVideoFilename(url: String){
        if let rtspUrl = NSURL(string: url){
            var port = "554";
            if let port = rtspUrl.port{
                let portStr = port.stringValue
                if let host = rtspUrl.host{
                    let fn = host + "_" + portStr
            
                    baseVideoFilename = fn
                }
            }
        }else{
            baseVideoFilename = "video"
        }
    }
    var vlcVideoFileName = ""
    func setVlcFilename(rtspUrl: String){
        let parts = rtspUrl.components(separatedBy: "?")
        let fn = parts[0].replacingOccurrences(of: "/", with: "_")
        vlcVideoFileName = fn.replacingOccurrences(of: ":", with: "_")
        
    }
    //MARK: VLCLibraryLogReceiverProtocol
    var isFirstError = true
   
    func handleMessage(_ message: String, debugLevel level: Int32) {
       
        if hasFirstFrame == false{
            if message.hasPrefix("Buffering"){
                listener?.onBufferring(camera: theCamera!,pcent: message)
            }else{
                //listener?.onBufferring(camera: theCamera!,pcent: "")
                
                if message.contains("buffering done"){
                    
                    grabFrameDelayed()
                }
            }
        }
        
        if level == 4 && isFirstError && playStarted == false{
            
            if message.hasPrefix("option") == false{
                isFirstError = false
                
                listener?.onError(camera: theCamera!,error: message)
            }
        }
        if message.hasPrefix("authentication failed"){
            isFirstError = false
            hasAuthError = true
            listener?.connectAuthFailed(camera: theCamera!)
            
        }
        if message.hasPrefix("decoder failure, Abort") || message.hasPrefix("RTSP/1.0 400 Bad Request")
            || message.hasPrefix("VoutDisplayEvent 'resize' 0x0 0"){
        
            print("VLC BAD: "+message)

            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: {
                self.listener?.reconnectToCamera(camera: self.theCamera!)
            });
            
        }
        //DON"T WANT ALL THIS NOW
        /*
        if !message.hasPrefix("picture"){
            print("VLC:",message,level)
        }
         */
    }
    //MARK: Playing
    var isRemovedFromSuperview = false
    override func removeFromSuperview() {
        
        isRemovedFromSuperview = true
        let tag = theCamera != nil ? theCamera!.name : "no camera"
        print("BaseNSVlcMediaPlayer:removeFromSuperview",tag)
        if playStarted || isInitialized {
            mediaPlayer!.stop()
            playStarted = false
            print("BaseNSVlcMediaPlayer:stop")
           
        }
        super.removeFromSuperview()
        
    }
    func stop(camera: Camera) -> Bool{
        if playStarted {
            if isRecording {
                startStopRecording(camera: camera)
            }
            motionDetector.enabled = false
            mediaPlayer!.stop()
            playStarted = false
            hasFirstFrame = false
            print("BaseNSVlcMediaPlayer:stop",camera.getDisplayAddr())
           return true
        }else if isInitialized {
            print("BaseNSVlcMediaPlayer:stop isPlaying not playStarted")
            mediaPlayer!.stop()
        }
        hasStopped = true
        return false
    }
    func play(camera: Camera)
    {
        theCamera = camera
        isFirstError = true
        hasStopped = false
        hasAuthError = false
        
        guard let cp = camera.selectedProfile()else{
            AppLog.write("VLCCameraView profile == nil")
            listener?.onError(camera: camera, error: "Invalid streaming profile")
            return
        }
        
        var url = cp.url
        if cp.url.isEmpty{
            AppLog.write("VLCCameraView URL isEmpty")
            listener?.onError(camera: camera, error: "Invalid streaming profile")
            return
        }
        print("BaseNSVlcMediaPlayer:play",url)
        
        setBaseVideoFilename(url: url)
        //set for vlc matching
        setVlcFilename(rtspUrl: url)
        
        let useVlcAuth = true
        if camera.password.isEmpty {
            
            url = url.replacingOccurrences(of: "rtsp://", with: "rtsp://"+camera.user+":@")
        
            AppLog.write("Using URL auth",url)
        }
       
        
        
        guard let rtspUrl = URL(string: url)else {
            AppLog.write("VLCCameraView rtspUrl == nil")
            listener?.onError(camera: camera, error: "Invalid streaming Uri")
            return
        }
        let media = VLCMedia(url: rtspUrl)//URL(string: url)!)
        
        if useVlcAuth {
            media.addOption("rtsp-user=" + camera.user)
            media.addOption("rtsp-pwd=" + camera.password)
            
        }
        mediaPlayer!.media = media
        
        //translatesAutoresizingMaskIntoConstraints = false
        
        isInitialized = false
        playStarted = false
        hasFirstFrame = false
        isHidden = true
        
        if let mp = mediaPlayer{
            mp.play()
            if let audio = mp.audio{
                audio.volume = camera.muted ? 0 : 100
                AppLog.write("Player vol",audio.volume)
            }
        }
        
        rotateBy(angle: CGFloat(camera.rotationAngle))
         
        RemoteLogging.log(item: "Connecting to " + url)
       
        
    }
    //MARK: Recording
    var isRecording = false
    var recordStartTime: Date?
    var isRecordingSnapshot = false
    var videoFileName: String = ""
    
    #if DEBUG
        let maxRecordTime = Double(60 * 3)
    #else
        let maxRecordTime = Double(60 * 15) // 15 minutes in seconds
    #endif
    
    func checkVideoMaxDuration(){
        if isRecording {
            let elaspedTimeSeconds = Date().timeIntervalSince(recordStartTime!)
            if elaspedTimeSeconds > maxRecordTime {
                AppLog.write("BaseNSVlcMediaPlayer exceeded max record time",maxRecordTime)
                startStopRecording(camera: theCamera!)
                listener?.onRecordingTerminated(camera: theCamera!)
            }
        }
    }
    func getEventOrVideoFilename(camera: Camera,timestamp: Date) -> String {
        /*
       
        
        guard let cp = camera.selectedProfile()else{
            return camName+"_XxX_"+FileHelper.getDateStr(date: timestamp)
        }
        let res = cp.resolution
        
        return camName+"_"+res+"_"+FileHelper.getDateStr(date: timestamp)
    */
        //let camName = FileHelper.removeIllegalChars(str: camera.getDisplayName())
            return camera.getStringUid()+"_"+FileHelper.getDateStr(date: timestamp)
        }
    
    func startStopRecording(camera: Camera) -> Bool{
    
        if(isRecording){
            isRecording = false
           
            self.mediaPlayer!.stopRecording()
           
            recordStartTime = nil
            
            //rename
           
            FileHelper.renameLastCapturedVideo(videoFileName: videoFileName, targetDir: FileHelper.getVideoStorageRoot(),srcFile: vlcVideoFileName) {
                self.listener?.onRecordingEnded(camera: self.theCamera!)
            }
            print("VideoSaved",videoFileName)
            
            RemoteLogging.log(item: "Stop recording " + theCamera!.name)
        }else{
            if mediaPlayer!.hasVideoOut==false{
                AppLog.write("BaseNSVlcMediaPlayer: Start recording, ignored no video out")
                return false
            }
            let videoDir = FileHelper.getTempVideoStorageRoot()
            AppLog.write("BaseNSVlcMediaPlayer: Start recording path",videoDir.path)
            self.mediaPlayer!.startRecording(atPath: videoDir.path)
            AppLog.write("BaseNSVlcMediaPlayer: Start recording")
    
            recordStartTime = Date()
            isRecording = true
            
            RemoteLogging.log(item: "Start recording " + theCamera!.name)
            
            videoFileName = getEventOrVideoFilename(camera: camera,timestamp: recordStartTime!)
            
            let thumb = FileHelper.getVideoStorageRoot().appendingPathComponent(videoFileName+".png")
            print("VideoThumb",thumb)
            takeThumbnailSnapshot(thumbPath: thumb)
        }
        return isRecording
    }
    func recordVmdVideoClip(durationSeconds: Double,timestamp: Date){
        
        if isRecording {
            AppLog.write("BaseNSVlxPlayer:recordVideoClip ignored, already recording")
            return
        }
        recordStartTime = Date()
        isRecording = true
        
        let videoDir = FileHelper.getTempVideoStorageRoot()
        AppLog.write("BaseNSVlxPlayer: RecordClip path",videoDir.path)
        self.mediaPlayer!.startRecording(atPath: videoDir.path)
        
        DispatchQueue.main.asyncAfter(deadline: .now()+durationSeconds, execute: {
            
            self.mediaPlayer!.stopRecording()
            //rename
             
            let vfn = self.getEventOrVideoFilename(camera: self.theCamera!, timestamp: timestamp)
            
            FileHelper.renameLastCapturedVideo(videoFileName: vfn,targetDir: FileHelper.getVideoStorageRoot(),srcFile: self.vlcVideoFileName){
                self.listener?.onRecordingEnded(camera: self.theCamera!)
            }
            
            RemoteLogging.log(item: "BaseNSVlxPlayer: Stopped Clip  " + self.theCamera!.name)
            
            self.isRecording = false
        })
       
    }
    //MARK: MediaPlayerDelegate
    var hasStopped = false
    var lastState = VLCMediaPlayerState.stopped
    
    func mediaPlayerStateChanged(_ aNotification: Notification!) {
        
        
        if mediaPlayer == nil {
             AppLog.write("BaseNSVlcMediaPlayer:mediaPlayerStateChanged mediaPlayer == nil")
            return
        }
        isInitialized = true
        
        let mps = mediaPlayer!.state
        if lastState != mps {
            AppLog.write("mediaPlayerStateChanged",mps.rawValue,theCamera!.name)
            lastState = mps
        }
        if hasAuthError{
            AppLog.write("BaseNSVlcMediaPlayer:mediaPlayerStateChanged ignored hasAuth error",mps.rawValue)
            return
        }
        if( mps == VLCMediaPlayerState.stopped && playStarted ){
            self.listener?.onError(camera: theCamera!,error: "Failed to connect, stopped")
            self.state = 1
        }
        if mps == VLCMediaPlayerState.error  {
            self.state = 1
            self.listener?.onError(camera: theCamera!,error: "Failed to connect, error occured")
            AppLog.write("BaseNSVlcMediaPlayer VLCMediaPlayerState.error")
            return;
        }
        
        if( mps == VLCMediaPlayerState.stopped && playStarted ){
            self.listener?.onError(camera: theCamera!,error: "Connection error, stopped")
            self.listener?.reconnectToCamera(camera: theCamera!)
            self.state = 1
            self.hasStopped = true
            AppLog.write("BaseNSVlcMediaPlayer VLCMediaPlayerState.stopped")
            
            return
        }
        
        /*
        if mps == VLCMediaPlayerState.buffering && !playStarted {
            
            listener?.onBufferring(camera: theCamera!)
        }
        */
        
        
        if(mediaPlayer!.isPlaying && playStarted == false){
            AppLog.write("BaseNSVlcMediaPlayer VLCMediaPlayerState -> playStarted")
           
            playStarted = true
            hasStopped = false
    
            let q = DispatchQueue(label: theCamera!.name)
            q.async {
                //keep a copy here as theCamera might change if user selects different camera before
                let camToSave =  self.theCamera!
                var waitCount = 0
                
                while self.mediaPlayer!.hasVideoOut == false {
                    sleep(1)
                    if self.isRemovedFromSuperview{
                        self.listener?.onError(camera: self.theCamera!, error: "Camera state error")
                        return
                    }
                    if self.mediaPlayer?.isPlaying == false && !self.hasStopped {
                        self.listener?.onError(camera: self.theCamera!, error: "Disconnected")
                        return
                    }
                    
                    waitCount += 1
                
                    if waitCount >= 30 {
                        print("BaseNSVlcMediaPlayer VLCMediaPlayerState -> timeout", waitCount)
                        
                        self.hasStopped = true
                        self.mediaPlayer!.stop()
                        self.listener?.onError(camera: self.theCamera!, error: "Timeout connecting")
                        return
                    }
                }
                
                
                self.listener?.onPlayerReady(camera: self.theCamera!)
                
                self.hasFirstFrame = true
                
                camToSave.save()
                self.state = 0
               
                DispatchQueue.main.async {
                    self.isHidden = false
                    
                };
                
                if self.theCamera!.vmdOn{
                    self.setVmdEnabled(enabled: true)
                }
                
                
                self.grabFrameDelayed()
               
                sleep(1)
                
                while self.isRemovedFromSuperview == false && self.mediaPlayer!.isPlaying {
                    sleep(1)
                    self.checkVideoMaxDuration()
                    if self.hasStopped {
                        break
                    }
                    //BUG hides error the status overlay
                    if self.mediaPlayer!.hasVideoOut && self.hasFirstFrame{
                        //self.listener?.onIsAlive(camera: self.theCamera!)
                    }
                }
            }
        }
    }
    func grabFrameDelayed(){
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
            if self.mediaPlayer!.hasVideoOut && self.isRemovedFromSuperview == false{
                if let cam = self.theCamera{
                    let jpg = cam.thumbName()
                    let filePath = FileHelper.getPathForFilename(name: jpg)
                    let tw = 320.0
                   
                        let th = tw / cam.getAspectRatio()
                        self.mediaPlayer!.saveVideoSnapshot(at: filePath.path,withWidth: Int32(tw),andHeight: Int32(th))
                    }
                }
            })
    }
    //MARK: Volume
    func toggleMute(){
        let cam = theCamera!
        if cam.muted {
            cam.muted = false
        }else{
            cam.muted = true
        }
        cam.save()
        muteSettingsChanged()
    }
    func muteSettingsChanged(){
        if let mp = mediaPlayer{
            if let camera = theCamera{
                if let audio = mp.audio{
                    audio.volume = camera.muted ? 0 : 100
                    AppLog.write("Player vol",audio.volume)
                }
            }
        }
        
    }
    func setMuted(muted: Bool){
        if let mp = mediaPlayer{
            if let camera = theCamera{
                if let audio = mp.audio{
                    audio.volume = muted ? 0 : 100
                    AppLog.write("Player vol",audio.volume)
                }
            }
        }
   }
    //MARK: MotionDetectionListener
    var lastEventTime: Date?
    func onLevelChanged(camera: Camera,level: Int){
        motionListener?.onLevelChanged(camera: camera,level: level)
    }
    func onMotionEvent(camera: Camera,start: Bool,time: Date){
        motionListener?.onMotionEvent(camera: camera,start: start,time: Date())
        
        if start {
          
            lastEventTime = time
            ignoreNextSnap = true
            
            //need to set event on NXVProxy if running
            
            //moved to onMotionEvent to take fullsized pic
            let fn =  getEventOrVideoFilename(camera: theCamera!, timestamp: lastEventTime!)
            let vmdRoot = FileHelper.getVideoStorageRoot()
            let eventFile = vmdRoot.appendingPathComponent( fn + ".png" )
            let fullSizeEventsFile = vmdRoot.appendingPathComponent( "_" + fn + ".png" )
            takeFullSizeSnap(dest: fullSizeEventsFile)
            do{
                try FileManager.default.moveItem(atPath: vmdFrame!.path, toPath: eventFile.path)
                print("VMDEvent",eventFile.path)
                
            }catch{
                AppLog.write("BaseNSVlcPlayer:event move snapshot failed")
            }
            
            print("onMotioneEvent vidOn,isRecording",theCamera!.vmdVidOn,isRecording)
            if theCamera!.vmdVidOn && !isRecording {
               
                AppLog.write("BaseNSVlcPlayer record video clip for ",theCamera!.vmdRecTime)
                recordVmdVideoClip(durationSeconds: Double(theCamera!.vmdRecTime),timestamp: lastEventTime!)
            }
            
            
            if(UserDefaults.standard.object(forKey: Camera.VMD_AUDIO_KEY) != nil){
                let soundId = UserDefaults.standard.integer(forKey: Camera.VMD_AUDIO_KEY)
                if soundId > 0{
                    DispatchQueue.main.async{
                        AudioServicesPlayAlertSound(SystemSoundID(soundId))
                    }
                }
            }
            
        }
        
        
 
    }
    //MARK: VMD
    var vmdFrame: URL?
    var motionDetector = MotionDetector()
    func setVmdSensitivity(sens: Int){
        //nneds to morph the sens valiue
        motionDetector.maxThreshold = sens
        theCamera!.vmdSens = sens
    }
    func setVmdEnabled(enabled: Bool){
        motionDetector.enabled = enabled
        
        if motionDetector.enabled {
            //globalVmdCtrls?.resetVmd()
            
            //motionDetector.name = theCamera!.name.replacingOccurrences(of: " ",with: "_")
            motionDetector.name = FileHelper.removeIllegalChars(str: theCamera!.getDisplayName())
            motionDetector.vmdStorageRoot = FileHelper.getVmdStorageRoot()
            motionDetector.listener = self
            motionDetector.maxThreshold = theCamera!.vmdSens
            
            motionDetector.busy = false
            motionDetector.startNewSession(camera: theCamera!) // resets ignore flags to avoid spikes
            
            startCaptureBackgroundTask()
        }else{
            //stop events until capture task exists
            motionDetector.busy = true
        }
    }
    func setVmdVideoEnabled(enabled: Bool){
        theCamera!.vmdVidOn = enabled
    }
    //MARK: capture task also used for cloud
    var captureTaskRunnng = false
    var cloudCaptureInterval: UInt32 = 1
    func startCaptureBackgroundTask(){
        
        if(captureTaskRunnng){
            AppLog.write("BasNSVlcPlayer capture task already running")
            return
        }
        captureTaskRunnng = true
        waitingForSnap = false
        
        let camName = FileHelper.removeIllegalChars(str: theCamera!.getDisplayName())
        let jpg = camName + ".png"
        vmdFrame = FileHelper.getPathForFilename(name: jpg)
        
        let q = DispatchQueue(label: "vmd_"+theCamera!.name)
        let currentCam = theCamera!
        waitingForSnap = false
        q.async {
            AppLog.write("BasNSVlcPlayer capture task START",currentCam.getDisplayAddr())
            while(self.motionDetector.enabled){
                
                
                sleep(1)
                
                 if self.isRemovedFromSuperview{
                    break
                 }
                if self.waitingForSnap && (self.motionDetector.enabled){
                    continue
                }
                  if self.mediaPlayer!.hasVideoOut {
                    //larger image for viewing events
                    let tw = 320.0
                    let th = tw / self.theCamera!.getAspectRatio()
                    self.mediaPlayer!.saveVideoSnapshot(at: self.vmdFrame!.path,withWidth: Int32(tw),andHeight: Int32(th))
                    
                    self.waitingForSnap = true
                    
                }
            }
            AppLog.write("BasNSVlcPlayer capture task EXIT",currentCam.getDisplayAddr())
            self.captureTaskRunnng = false
        }
    }
    //MARK: Vmd and Cloud capture
    var ignoreNextSnap = false
    var waitingForSnap = false
    
    func mediaPlayerSnapshot(_ aNotification: Notification!) {
        if ignoreNextSnap {
            waitingForSnap = false
            ignoreNextSnap = false
            return
        }
        //AppLog.write("Snapped",theCamera!.name)
        listener?.onSnapshotChanged(camera: self.theCamera!)
        
        
        if motionDetector.enabled && vmdFrame != nil{
            let isEvent=motionDetector.setCurrentPath(imagePath: vmdFrame!)
            if isEvent {
                /*
                if let img = UIImage(contentsOfFile: vmdFrame!.path) {
                    if let bwi = ImageHelper.toBlackAndWhite(uiImage: img) {
                        if let data = bwi.jpegData(compressionQuality: 1.0) {
                            let filename = vmdFrame!.path.replacingOccurrences(of: ".png", with: ".jpg")
                            try? data.write(to: URL(fileURLWithPath: filename))
                        }
                    }
                }
                 */
            }
        }
 
        waitingForSnap = false
    }
    func takeFullSizeSnap(dest: URL){
        let eventFile = dest
        let tw = 1080.0
        let th = tw / self.theCamera!.getAspectRatio()
        self.mediaPlayer!.saveVideoSnapshot(at: eventFile.path,withWidth: Int32(tw),andHeight: Int32(th))
    }
    func takeThumbnailSnapshot(thumbPath: URL){
        if mediaPlayer!.hasVideoOut==false{
            AppLog.write("BaseNSVlcMediaPlayer:takeThumbnailSnapshot, ignored no video out")
            return
            
        }
        let tw = 720.0
        let th = tw / self.theCamera!.getAspectRatio()
        
        self.isRecordingSnapshot = true
        self.mediaPlayer!.saveVideoSnapshot(at: thumbPath.path,withWidth: Int32(tw),andHeight: Int32(th))
    }
    
    func mediaPlayerStartedRecording(_ player: VLCMediaPlayer!) {
        AppLog.write("started recording",theCamera?.name)
    }
    func mediaPlayer(_ player: VLCMediaPlayer, recordingStoppedAtPath path: String) {
        print ("BaseNSVlcMediaPlayer:recordingStoppedAtPath",path);
    }

    var lastRotationAngle = 0.0
    func rotateNext() -> Int {
        let nextAngle = lastRotationAngle + 90
        if nextAngle == 360 {
            lastRotationAngle = 0
        }else{
            lastRotationAngle = nextAngle
        }
        
        rotateBy(angle: CGFloat(lastRotationAngle))
        
        let cam = theCamera!
        cam.rotationAngle = Int(lastRotationAngle)
        return cam.rotationAngle
    }
    
    
    func rotateBy(angle: CGFloat){
     
        lastRotationAngle = Double(angle)
        
        layer.transform = CATransform3D()
        layer.position = CGPoint(x: frame.midX,y: frame.midY)
        layer.anchorPoint = CGPoint(x: 0.5,y: 0.5);

        
        
        layer.transform = CATransform3DMakeRotation((.pi / 180) * angle, 0, 0, 1)
    }
}
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

