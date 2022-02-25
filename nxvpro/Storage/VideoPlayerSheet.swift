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
    
        let ftpDataSrc = FtpDataSource(listener: ftpListener)
        let ok = ftpDataSrc.connect(credential: token.creds!, host: token.remoteHost)
        if ok{
            ftpDataSrc.download(path: token.ReplayUri)
        }
    
    
    }
    func cancelDownload() -> Bool{
        
        return isDownloading
    }
}

struct VideoPlayerSheet : View, FtpDataSourceListener,VideoPlayerListemer{
    
    
    //MARK: VideoPlayerListemer
    func positionChanged(time: VLCTime?, remaining: VLCTime?) {
        
    }
    
    func playerStarted() {
        model.statusHidden = true
        if model.isCameraUri{
            //cameraModel.toolbarHidden = false
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
        }
    }
    
    func playerError(status: String) {
        if model.closed || playerView.player.playerView.isRemovedFromSuperView{
            return
        }
        DispatchQueue.main.async{
            model.status = status
            model.statusHidden = false
        }
    }
    
    
    @ObservedObject var model = VideoPlayerSheetModel()
    @ObservedObject var cameraModel = SingleCameraModel()
    
    let playerView = VideoPlayerView()
    let toolbar = CameraToolbarView()
    
    init(video: CardData,listener: VideoPlayerDimissListener){
        model.listener = listener
        model.localFilePath = video.filePath
        model.setCard(video: video)
        playerView.play(video: video)
    }
    init(token: RecordToken,listener: VideoPlayerDimissListener){
        model.listener = listener
        let targetUrl = StorageHelper.getLocalFilePath(remotePath: token.ReplayUri)
        
        if targetUrl.1{
            downloadComplete(localFilePath: targetUrl.0.path, success: nil)
            
        }else{
            model.setToken(token: token,ftpListener: self)
        }
    }
    init(camera: Camera,token: RecordToken,listener: VideoPlayerDimissListener){
        model.listener = listener
        model.title = "REPLAY: " + camera.getDisplayName()
        playerView.setListener(listener: self)
        playerView.playStream(camera: camera, token: token)
    }
    init(camera: Camera,listener: VideoPlayerDimissListener){
        
        model.listener = listener
        var profileStr = ""
        if let profile = camera.selectedProfile(){
            profileStr = " " + profile.resolution
        }
        model.isCameraUri  = true
        playerView.setListener(listener: self)
        model.title = camera.getDisplayName() + " " + profileStr
        playerView.playCameraStream(camera: camera)
    }
    //MARK: FtpDataSourceListener
    func actionComplete(success: Bool) {}
    func fileFound(path: String, modified: Date?) {}
    func directoryFound(dir: String) {}
    func done() {}
    
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
                    Text(model.title).appFont(.smallTitle)
                        .padding()
                }
                Spacer()
                Button(action: {
                    //share
                    
                    if let localPath = model.localFilePath{
                        stopPlayback()
                        model.listener?.dismissAndShare(localPath: localPath)
                    }
                }){
                    Image(systemName: "square.and.arrow.up").resizable()
                        .frame(width: 14,height: 14).padding()
                }.disabled(model.localFilePath == nil)
                
                Button(action: {
                    //check if downloading
                    stopPlayback()
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
                    toolbar.hidden(cameraModel.toolbarHidden)
                }
                Text(model.status).appFont(.caption).hidden(model.statusHidden)
            }
        }.interactiveDismissDisabled()
            .onDisappear {
            model.closed = true
        }
    }
}
