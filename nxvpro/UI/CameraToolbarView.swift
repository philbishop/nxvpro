//
//  CamearToolbarView.swift
//  DesignIdeas
//
//  Created by Philip Bishop on 26/05/2021.
//

import SwiftUI
import Foundation

class CameraToolbarUIModel: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var recordStartTime: Date?
    @Published var recordingTime: String = "00:00"
    @Published var ptzEnabled: Bool = false
    @Published var settingsEnabled: Bool = true
    @Published var isMiniToolbar = false
    @Published var spacing = CGFloat(8)
    //@Published var volumeIcon: String = "􀊨"
    @Published var maxVideoDuration: Double = 600
    @Published var rotateMenuDisabled: Bool = false
    @Published var volumeOn = true
    @Published var vmdEnabled = true
    @Published var vmdOn = false
    @Published var vmdMode = 0
    
    @Published var toolbarWidth: CGFloat = 430.0
    @Published var showTimer = true
    
    @Published var imagingEnabled: Bool = false
    @Published var imagingHidden: Bool = false
    
    @Published var isPad: Bool = false
    @Published var helpHidden = false
    @Published var xoffset = CGFloat(0)
    
    var camera: Camera?
    
    var cameraEventListener: CameraToolbarListener?
    
    init(){
        if UIDevice.current.userInterfaceIdiom == .pad{
            isPad = true
            imagingHidden = false
        }else if UIDevice.current.userInterfaceIdiom == .phone || UIScreen.main.bounds.width < 400{
            showTimer = false
            if UIScreen.main.bounds.width == 320{
                toolbarWidth = 270
                imagingHidden = true
                spacing = 1
            }else{
                toolbarWidth = 325
                spacing = 6
            }
            
            //toolbarWidth = 285
            //helpHidden = true
            //xoffset = UIScreen.main.bounds.width - 400
        }
    }
    
    func setCamera(_ cam: Camera){
        self.camera = cam
        self.vmdMode = cam.vmdMode
        self.vmdOn = cam.vmdOn
    }
    func onVmdStateChanged(_ ocam: Camera){
        if let cam = self.camera{
            if cam.sameAs(camera: ocam){
                self.camera = ocam
                self.vmdOn = ocam.vmdOn
                self.vmdMode = ocam.vmdMode
            }
        }
    }
}

//var cameraToolbarInstance: CameraToolbarView?

struct CameraToolbarView: View {
    
    var toolbarHeight = CGFloat(38)
    
    @ObservedObject var model = CameraToolbarUIModel()
    
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var iconModel = AppIconModel()
    
    //var isSingleInstance: Bool = false
    
    func setListener(listener: CameraToolbarListener){
        model.cameraEventListener = listener
    }
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    func reset(){
        stopTimer()
    }
    func setCamera(camera: Camera){
        model.setCamera(camera)
        setVmdEnabled(camera,enabled: camera.vmdOn)
        setPtzEnabled(enabled: camera.hasPtz())
        setAudioMuted(muted: camera.muted)
        setImagingEnabled(enabled: camera.hasImaging())
        reset()
    }
    func setRecordStartTime(startTime: Date?){
        model.isRecording = startTime != nil
        model.recordStartTime = startTime
    }
    func setPtzEnabled(enabled: Bool){
        model.ptzEnabled = enabled
    }
    func setImagingEnabled(enabled: Bool){
        model.imagingEnabled = enabled
        
    }
    func setAudioMuted(muted: Bool){
        model.volumeOn = !muted
        iconModel.volumeStatusChange(on: model.volumeOn)
    }
    func startTimer(){
        model.recordStartTime = Date()
        model.isRecording = true
    }
    func stopTimer(){
        model.isRecording = false
    }
    
    func setCloudOn(on: Bool){
        iconModel.cloudStatusChanged(on: on)
    }
    func setSettingsEnabled(enabled: Bool){
        model.settingsEnabled = enabled
    }
    func setVmdEnabled(_ cam: Camera,enabled: Bool){
#if DEBUG
print("CameraToolbar:setVmdEnabled",enabled)
#endif
        DispatchQueue.main.async{
            self.model.onVmdStateChanged(cam)
            self.iconModel.vmdStatusChange(status: enabled ? 1 : 0)
        }
    }
    /*
    func setOrientation(isLandscape: Bool){
        if model.isPad{
            if isLandscape{
                model.toolbarWidth = 430
                model.helpHidden = false
                model.showTimer = true
            }else{
                model.toolbarWidth = 340.0
                model.helpHidden = true
                model.showTimer = false
            }
        }else{
            model.toolbarWidth = 350
        }
    }
    */
    var body: some View {
        let iconSize = iconModel.iconSize
        
        HStack{
            HStack(spacing: model.spacing){
                
                if model.imagingHidden == false {
                    //IMAGING
                    Button(action: {
                        if model.imagingEnabled{
                            
                            model.cameraEventListener?.itemSelected(cameraEvent:  CameraActionEvent.Imaging)
                            
                        }
                    }){
                        Image(iconModel.imagingIcon).resizable()
                            .frame(width: iconSize, height: iconSize)
                            .opacity((model.imagingEnabled ? 1.0 : 0.5))
                    }.buttonStyle(PlainButtonStyle())
                    
                }
                
                //PTZ
                Button(action: {
                    model.cameraEventListener?.itemSelected(cameraEvent: CameraActionEvent.Ptz)
                }){
                    
                    Image(iconModel.ptzIcon).resizable().frame(width: iconSize, height: iconSize).opacity((model.ptzEnabled ? 1.0 : 0.5))
                }
                
                
                if !model.isMiniToolbar {
                    if model.vmdEnabled{
                        //VMD
                        Button(action: {
                            AppLog.write("Vmd toolbar button click")
                            model.cameraEventListener?.itemSelected(cameraEvent: CameraActionEvent.Vmd)
                        }){
                            
                            Image(model.vmdMode == 0 && model.vmdOn ? iconModel.vmdOnIcon : iconModel.vmdIcon)
                                .resizable()
                                .frame(width: iconSize, height: iconSize)
                                .opacity(model.isRecording ? 0.5 : 1.0)
                        }.disabled(model.isRecording)
                        
                        if AppSettings.IS_PRO{
                            Button(action: {
                                AppLog.write("Body detect toolbar button click")
                                model.cameraEventListener?.itemSelected(cameraEvent: CameraActionEvent.bodyDetection)
                                
                            }){
                                Image(iconModel.getActiveDetectIconFor(model.camera))
                                    .resizable().frame(width: iconSize - 5, height: iconSize - 5)
                                  
                            }.disabled(model.vmdMode == 0 && model.vmdOn)
                            
                        }
                        
                    }else{
                        //SEPARATOR
                        Text("")
                    }
                    
                    //RECORD
                    Button(action: {
                        model.cameraEventListener?.itemSelected(cameraEvent: CameraActionEvent.Record)
                        
                        if model.isRecording {
                            model.isRecording = false
                            model.recordingTime = "00:00"
                        }else{
                            model.isRecording = true
                            startTimer()
                        }
                        
                    }){
                        Image(iconModel.recordIcon).resizable().frame(width: iconSize, height: iconSize)
                            
                    }
                    .opacity(model.vmdOn ? 0.5 : 1.0)
                    .disabled(model.vmdOn)
                    
                    if model.showTimer{
                        Text("\(model.recordingTime)")
                            .appFont(.body)
                            .onReceive(timer, perform: { _ in
                                
                                if(model.isRecording){
                                    iconModel.recordingStatusChange(status: true)
                                    let elaspedTime = Date().timeIntervalSince(model.recordStartTime!)
                                    model.recordingTime = Helpers.stringFromTimeInterval(interval: elaspedTime) as String
                                }else{
                                    model.recordingTime = "00:00"
                                    iconModel.recordingStatusChange(status: false)
                                }
                                
                            })
                    }
                }
                //MUTE
                Button(action: {
                    model.volumeOn = !model.volumeOn
                    iconModel.volumeStatusChange(on: model.volumeOn)
                    model.cameraEventListener?.itemSelected(cameraEvent: CameraActionEvent.Mute)
                }){
                    //Text(model.volumeIcon).padding(0)
                    Image(iconModel.activeVolumeIcon).resizable().frame(width: iconSize, height: iconSize)
                    
                }
                //ROTATE
                Button(action: {
                    model.cameraEventListener?.itemSelected(cameraEvent: CameraActionEvent.Rotate)
                }){
                    
                    Image(iconModel.rotateIcon).resizable().frame(width: iconSize, height: iconSize)
                }
                
                if !model.isMiniToolbar{
                    //SETTINGS
                    Button(action: {
                        model.cameraEventListener?.itemSelected(cameraEvent: CameraActionEvent.Settings)
                    }){
                        Image(iconModel.settingsIcon).resizable().frame(width: iconSize, height: iconSize)
                            .opacity((model.settingsEnabled ? 1.0 : 0.5))
                    }.disabled(model.settingsEnabled == false)
                    
                    if !model.helpHidden{
                        //Help
                        Button(action: {
                            model.cameraEventListener?.itemSelected(cameraEvent: CameraActionEvent.Help)
                        }){
                            Image(iconModel.infoIcon).resizable().frame(width: iconSize, height: iconSize)
                        }
                    }
                }
                
            }.padding(4).frame(width: model.toolbarWidth).background(Color(UIColor.tertiarySystemBackground)).cornerRadius(15)
            
            
        }.padding()
          
            .onAppear(){
            
            iconModel.initIcons(isDark: colorScheme == .dark)
            
            if let cam = model.camera{
                iconModel.vmdStatusChange(status: cam.vmdOn ? 1 : 0)
            }
          
            if model.isMiniToolbar{
                model.toolbarWidth = 200
            }
            
        }
    }
}

struct CameraToolbarView_Previews: PreviewProvider {
    static var previews: some View {
        CameraToolbarView()
    }
}
