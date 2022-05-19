//
//  OnboardCaptureOverlay.swift
//  NX-V PRO
//
//  Created by Philip Bishop on 18/05/2022.
//

import SwiftUI

protocol OnboardCaptureSaveListener{
    func onCaptureSaved()
}

class OnboatdCaptureModel : ObservableObject{
    
    @Published var locaRtspFilepath = ""
    @Published var stopDisabled = false
    @Published var waitingOnStream = false
    
    var videoPlayer: BaseVideoPlayer?
    var token: RecordToken?
    var listener: OnboardCaptureSaveListener?
    var dismissListener: VideoPlayerDimissListener?
    
    func stopRecording(){
        if let vp = videoPlayer{
            if let tok = token{
                vp.stopIfRecording(token: tok)
                stopDisabled = true
            }
        }
    }
}

struct OnboardCaptureOverlay: View {
    
    @ObservedObject var model = OnboatdCaptureModel()
    
   
    
    func reset(){
        model.locaRtspFilepath = ""
        model.stopDisabled = false
        model.waitingOnStream = false
    }
    
    func onWaitingForStream(){
        model.waitingOnStream = true
    }
    
    func onRecordingStarted(vp: BaseVideoPlayer,token: RecordToken,listener: OnboardCaptureSaveListener, dismissListener: VideoPlayerDimissListener){
        model.videoPlayer = vp
        model.token = token
        model.listener = listener
        model.dismissListener = dismissListener
        reset()
    }
    func onRecordingEnded(token: RecordToken){
        if FileHelper.hasOnboardCachedVideo(token: token){
            FileHelper.populateOnboardFilePath(token: token)
            model.locaRtspFilepath = token.localRtspFilePath
            RemoteLogging.log(item: "VideoPlayerSheet:videoCaptureEnded " + token.localRtspFilePath)
            
        }else{
            print("VideoPlayerSheet:videoCaptureEnded nothing captured")
        }
    }
    func showSaveDialog(){
        
        let sdDir = FileHelper.getSdCardStorageRoot()
        let uri = sdDir.appendingPathComponent(model.locaRtspFilepath)
        
        DispatchQueue.main.async {
            model.videoPlayer?.stop()
            model.dismissListener?.dismissAndShare(localPath: uri)
        }
        
    }
    var body: some View {
        VStack{
            HStack{
                Spacer()
                ZStack(alignment: .topTrailing){
                    ZStack{
                        
                        HStack{
                            Spacer()
                            Text(" CAPTURING STREAM ").foregroundColor(.white).appFont(.caption)
                               .padding(5)
                               .background(Color.gray)
                               .cornerRadius(15)
                               
                            
                            Text(" STOP ").foregroundColor(.white).appFont(.caption)
                            .padding(5)
                            .background(model.stopDisabled ? Color.gray : Color.accentColor)
                            .cornerRadius(15).onTapGesture {
                                //need to invoke method to stop recording to force stop callback
                                
                                model.stopRecording()
                            }
                        }
                        .hidden(model.locaRtspFilepath.isEmpty==false || model.waitingOnStream)
                        
                    Text(" SAVE CAPTURED VIDEO ").foregroundColor(.white).appFont(.caption)
                        .padding(5)
                        .background(Color.accentColor)
                        .cornerRadius(15).onTapGesture {
                            showSaveDialog()
                        }.hidden(model.locaRtspFilepath.isEmpty || model.waitingOnStream)
                    
                    
                    Text(" MOVING TO STREAM START POSITION ").foregroundColor(.white).appFont(.caption)
                       .padding(5)
                       .background(Color.gray)
                       .cornerRadius(15)
                       
                       .hidden(model.waitingOnStream == false)
                    }
                }.padding(.top,5)
            }
            Spacer()
        }
    }
}

struct OnboardCaptureOverlay_Previews: PreviewProvider {
    static var previews: some View {
        OnboardCaptureOverlay()
    }
}
