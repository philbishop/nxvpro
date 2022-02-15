//
//  VideoPlayerSheet.swift
//  nxvpro
//
//  Created by Philip Bishop on 14/02/2022.
//

import SwiftUI

class VideoPlayerSheetModel : ObservableObject{
    @Published var status = "Downloading...."
    @Published var statusHidden = true
    @Published var localFilePath: URL?
    
    var isDownloading = false
    var downloadCancelled = false
    
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

struct VideoPlayerSheet : View, FtpDataSourceListener{
    
    @ObservedObject var model = VideoPlayerSheetModel()
    let playerView = VideoPlayerView()
    
    init(video: CardData,listener: VideoPlayerDimissListener){
        model.listener = listener
        model.localFilePath = video.filePath
        model.setCard(video: video)
        playerView.play(video: video)
    }
    init(token: RecordToken,listener: VideoPlayerDimissListener){
        model.listener = listener
        model.setToken(token: token,ftpListener: self)
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
    private func stopPlayback(){
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
                playerView.hidden(model.statusHidden==false)
                Text(model.status).appFont(.caption).hidden(model.statusHidden)
            }
        }
    }
}
