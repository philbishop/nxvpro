//
//  VideoPlayerSheet.swift
//  nxvpro
//
//  Created by Philip Bishop on 14/02/2022.
//

import SwiftUI
import MobileVLCKit

class VideoPlayerSheetModel : ObservableObject{
    @Published var status = "Downloading...."
    @Published var statusHidden = true
    @Published var localFilePath: URL?
    @Published var isCameraUri = false
    //Timeline for REPLAY
    var videoTimeline: VideoPlayerTimeline?
    @Published var camera: Camera?
    @Published var timelineHidden = true
    @Published var replayToken: ReplayToken?
    
    @Published var captureOverlayHidden = true
  
    @Published var isDeleted = false
    
    var isDownloading = false
    var downloadCancelled = false
    var closed = false
    
    var title = ""
    var listener: VideoPlayerDimissListener?
    
    
    
    func setCard(video: CardData){
        title = video.name + " " + video.shortDateString()
    }
    func setToken(token: RecordToken,ftpListener: FtpDataSourceListener){
        statusHidden = false
        status = "Downloading file, please wait..."
        title = token.cameraName + " " + token.Time
        
        
        let mode = FtpDataSource.getSelectedMode(selectedMode: token.ftpMode)
        let ftpDataSrc = FtpDataSource(listener: ftpListener)
        let ok = ftpDataSrc.connect(credential: token.creds!, host: token.remoteHost,mode: mode)
        if ok{
            ftpDataSrc.download(path: token.ReplayUri)
        }
    
    
    }
    func cancelDownload() -> Bool{
        
        return isDownloading
    }
    
    @Published var playbackList = [ReplayToken]()
    
    func prepareVideoList(camera: Camera,token: RecordToken){
        self.camera = camera
        self.replayToken = ReplayToken(id: 999,token: token)
        if let results = camera.tmpSearchResults{
            var uniqueReplayUri = [RecordToken]()
            for res in results{
                if shouldAddToken(token: res, allTokens: uniqueReplayUri){
                    uniqueReplayUri.append(res)
                }
            }
            AppLog.write("VideoPlayerModel:uniqueReplayUri count",uniqueReplayUri.count)
            playbackList.removeAll()
            let nt = uniqueReplayUri.count
            if nt > 2{
                for i in 0...nt-1{
                    let tok = uniqueReplayUri[i]
                    let rt = ReplayToken(id: i,token: tok)
                    if tok.Time == token.Time && tok.Token == token.Token{
                        self.replayToken = rt
                    }
                    playbackList.append(rt)
                }
                
                AppLog.write("VideoPlayerModel:playback count",playbackList.count)
                timelineHidden = false
            }
        }
       
    }
    private func shouldAddToken(token: RecordToken,allTokens: [RecordToken]) -> Bool{
        if token.ReplayUri.isEmpty{
            return false
        }
        for tok in allTokens{
            if tok.Time == token.Time || tok.ReplayUri == token.ReplayUri{
                return false
            }
        }
        return true
    }
}

struct VideoPlayerSheet : View, FtpDataSourceListener,VideoPlayerListemer, CameraToolbarListener, RemoteStorageTransferListener,OnboardCaptureSaveListener{
    
    //MAR: OnboardCaptureSaveListener
    func onCaptureSaved() {
        model.captureOverlayHidden = true
        
    }
    func doDelete(token: RecordToken) {
        //doesn't appear in UI yet
        
    }
    
    //MARK: RemoteStorageTransferListener
    func doPlay(token: RecordToken) {
        AppLog.write("VideoPlayerSheet:doPlay",token.ReplayUri)
        if let cam = model.camera{
            //playerView.stop()
            
            model.status = "Connecting to " + token.Time
            model.statusHidden = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5,execute:{
                self.playerView.playStream(camera: cam, token: token)
            })
        }
                                          
    }
    func doDownload(token: RecordToken) {
        //RTSP capture
        AppLog.write("VideoPlayerSheet:doDownload",token.ReplayUri)
    }
    //MARK: VideoPlayerListemer
    func onWaitingForStream(){
        //show overlay with waiting
        DispatchQueue.main.async{
            self.captureOverlay.onWaitingForStream()
            self.model.captureOverlayHidden = false
        }
    }
    func videoCaptureStarted(token: RecordToken){
        
        //make record overlay visible
        DispatchQueue.main.async{
            self.captureOverlay.onRecordingStarted(vp: playerView.player.playerView,token: token,listener: self, dismissListener: model.listener!)
            self.model.captureOverlayHidden = false
        }
        AppLog.write("VideoPlayerSheet:videoCaptureStarted")
    }
    func videoCaptureEnded(token: RecordToken){
        AppLog.write("VideoPlayerSheet:videoCaptureEnded")
        DispatchQueue.main.async {
            self.captureOverlay.onRecordingEnded(token: token)
            
        }
    }
    
    func positionChanged(time: VLCTime?, remaining: VLCTime?) {
        
    }
    
    func playerStarted() {
        model.statusHidden = true
        if model.isCameraUri{
            cameraModel.playerReady = true
        }
    }
    
    func playerPaused() {
        
    }
    
    func onBuffering(pc: String) {
        if pc.isEmpty == false{
            DispatchQueue.main.async{
                model.statusHidden = false
                model.status = pc
            }
        }else{
            model.statusHidden = true
        }
    }
    
    func playerError(status: String) {
        if model.closed || playerView.player.playerView.isRemovedFromSuperView{
            return
        }
        DispatchQueue.main.async{
            model.status = status
            model.statusHidden = false
            cameraModel.playerReady = false
        }
    }
    
    
    @ObservedObject var model = VideoPlayerSheetModel()
    @ObservedObject var cameraModel = SingleCameraModel()
    //MARK: CameraToolbarListener
    func itemSelected(cameraEvent: CameraActionEvent) {
        cameraModel.cameraEventHandler?.itemSelected(cameraEvent: cameraEvent, thePlayer: nil)
        
        switch(cameraEvent){
        case .Imaging:
              //handled
            break
        case .Ptz:
            //cameraModel.hideConrols()
            //cameraModel.ptzCtrlsHidden = false
            break
            
        case.Rotate:
            playerView.rotateNext()
            break
            
        case .Mute:
            if let cam = cameraModel.theCamera{
                cam.muted = !cam.muted
                cam.save()
                toolbar.setAudioMuted(muted:  cam.muted)
                playerView.setMuted(muted: cam.muted)
            }
            break
            
        default:
           
            break
        }
    }
    
    let playerView = VideoPlayerView()
    //for map live stream
    let toolbar = CameraToolbarView()
    let vmdCtrls = VMDControls()
    let helpView = ContextHelpView()
    let settingsView = CameraPropertiesView()
    let ptzControls = PTZControls()
    let presetsView = PtzPresetView()
    let imagingCtrls = ImagingControlsContainer()
    let captureOverlay = OnboardCaptureOverlay()
    
    func doInit(video: CardData,listener: VideoPlayerDimissListener){
        model.listener = listener
        model.localFilePath = video.filePath
        model.captureOverlayHidden = true
        model.setCard(video: video)
        playerView.play(video: video)
    }
    func doInit(token: RecordToken,listener: VideoPlayerDimissListener){
        model.listener = listener
        model.captureOverlayHidden = true
        model.title = "FTP: " + token.cameraName + " " + token.Time
        let targetUrl = StorageHelper.getLocalFilePath(remotePath: token.ReplayUri)
        
        if targetUrl.1{
            downloadComplete(localFilePath: targetUrl.0.path, success: nil)
            
        }else{
            model.setToken(token: token,ftpListener: self)
        }
    }
    func doInit(camera: Camera,token: RecordToken,listener: VideoPlayerDimissListener){
        model.listener = listener
        model.title = "REPLAY: " + camera.getDisplayName()
        model.prepareVideoList(camera: camera, token: token)
        model.videoTimeline = VideoPlayerTimeline(token: model.replayToken!,tokens: model.playbackList,listener: self)
        //model.status = "Connecting to " + camera.getDisplayAddr() + "\n" + token.Time
        //model.statusHidden = false
        playerView.setListener(listener: self)
        playerView.playStream(camera: camera, token: token)
    }
    func doInit(camera: Camera,listener: VideoPlayerDimissListener){
        
        model.listener = listener
        var profileStr = ""
        if let profile = camera.selectedProfile(){
            profileStr = " " + profile.resolution
        }
        model.isCameraUri  = true
        cameraModel.cameraEventHandler = CameraEventHandler(model: cameraModel,toolbar: toolbar,ptzControls: ptzControls,settingsView: settingsView,helpView: helpView,presetsView: presetsView,imagingCtrls: imagingCtrls)
        
        if let handler = cameraModel.cameraEventHandler{
            
            ptzControls.setCamera(camera: camera, toolbarListener: self, presetListener: handler)
            
            handler.getPresets(cam: camera)
            handler.getImaging(camera: camera)
        }
        
        cameraModel.theCamera = camera
        toolbar.model.isMiniToolbar = true
        toolbar.setListener(listener: self)
        toolbar.setCamera(camera: camera)
        ptzControls.model.helpHidden = true
        playerView.setListener(listener: self)
        model.title = camera.getDisplayName() + " " + profileStr
        playerView.playCameraStream(camera: camera)
    }
    //MARK: FtpDataSourceListener
    func actionComplete(success: Bool) {}
    func fileFound(path: String, modified: Date?) {}
    func directoryFound(dir: String) {}
    func done(withError: String) {
        //nada here
    }
    func searchComplete(filePaths: [String]) {}
    
    func downloadComplete(localFilePath: String, success: String?) {
        DispatchQueue.main.async {
            
            if success == nil{
                model.statusHidden = true
                let rpu = URL(fileURLWithPath: localFilePath)
                model.localFilePath = rpu
                self.playerView.playLocal(filePath: rpu)
            }else{
                if let error = success{
                    model.status = error
                }else{
                    model.status = "Download failed"
                }
            }
        }
    }
    private func terminate(){
        model.cancelDownload()
        playerView.terminate()
        //stopPlayback()
    }
    private func stopPlayback(){
        model.closed = true
        if !model.cancelDownload(){
            playerView.stop()
        }
    }
    var body: some View {
        VStack{
            HStack{
                VStack{
                    Text(model.title).appFont(.titleBar)
                        .padding()
                }
                Spacer()
                if model.localFilePath != nil{
                    Button(action: {
                        //share
                        
                        if let localPath = model.localFilePath{
                            stopPlayback()
                            model.listener?.dismissAndShare(localPath: localPath)
                        }
                    }){
                        Image(systemName: "square.and.arrow.up").resizable()
                            .frame(width: 14,height: 16).padding()
                    }.disabled(model.localFilePath == nil)
                    
                
                    Button(action: {
                        //delete
                        
                        if let localPath = model.localFilePath{
                            stopPlayback()
                            model.isDeleted = true
                            model.listener?.dimissPlayer()
                        }
                    }){
                        Image(systemName: "trash").resizable()
                            .frame(width: 14,height: 16).padding()
                    }.disabled(model.localFilePath == nil)
                }
                
                Button(action: {
                    //check if downloading
                    stopPlayback()
                    model.isDeleted = false
                    model.listener?.dimissPlayer()
                })
                {
                    Image(systemName: "xmark").resizable()
                        .frame(width: 14,height: 14).padding()
                }.foregroundColor(Color.accentColor)
            }
           
            ZStack{
                ZStack(alignment: .bottom) {
                    playerView.hidden(model.statusHidden==false)
                        .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .phone ? UIScreen.main.bounds.width : .infinity)
                    if model.videoTimeline != nil{
                        model.videoTimeline
                    }
                    ZStack{
                        toolbar
                        ptzControls.hidden(cameraModel.ptzCtrlsHidden)
                        
                    }.hidden(cameraModel.playerReady==false)
                        .padding(.bottom)
                        .frame(height: 32)
                    
                    captureOverlay.hidden(model.captureOverlayHidden)
                }
                VStack{
                    Spacer()
                    HStack{
                        imagingCtrls.hidden(cameraModel.imagingHidden)
                        Spacer()
                        presetsView.hidden(cameraModel.presetsHidden)
                    }
                    Spacer()
                }.hidden(cameraModel.playerReady==false)
                
                Text(model.status).appFont(.caption).hidden(model.statusHidden)
            }
            
        }.interactiveDismissDisabled()
            .onDisappear {
            model.closed = true
        }
    }
}
