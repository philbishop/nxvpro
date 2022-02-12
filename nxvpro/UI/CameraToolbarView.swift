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
    
    //@Published var volumeIcon: String = "􀊨"
    @Published var maxVideoDuration: Double = 600
    @Published var rotateMenuDisabled: Bool = false
    @Published var volumeOn = true
    @Published var vmdEnabled = true
    @Published var toolbarWidth: CGFloat = 350.0
    @Published var showTimer = true

    @Published var imagingEnabled: Bool = false
    @Published var isPad: Bool = false
    
    var cameraEventListener: CameraToolbarListener?
    
    init(){
        if UIDevice.current.userInterfaceIdiom == .pad{
            isPad = true
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
    var body: some View {
        let iconSize = iconModel.iconSize
        
        HStack{
            HStack(spacing: 8){
                
                if model.isPad {
                    //IMAGING
                    Button(action: {
                        if model.imagingEnabled{
                         
                            model.cameraEventListener?.itemSelected(cameraEvent:  CameraEvent.Imaging)
                            
                        }
                    }){
                        Image(iconModel.imagingIcon).resizable()
                            .frame(width: iconSize, height: iconSize)
                            .opacity((model.imagingEnabled ? 1.0 : 0.5))
                    }.buttonStyle(PlainButtonStyle())
                   
                }
                
                //PTZ
                Button(action: {
                    model.cameraEventListener?.itemSelected(cameraEvent: CameraEvent.Ptz)
                }){
                  
                    Image(iconModel.ptzIcon).resizable().frame(width: iconSize, height: iconSize).opacity((model.ptzEnabled ? 1.0 : 0.5))
                }
                
                
               
                if model.vmdEnabled {
                    //VMD
                    Button(action: {
                        print("Vmd toolbar button click")
                        model.cameraEventListener?.itemSelected(cameraEvent: CameraEvent.Vmd)
                    }){
                     
                        Image(iconModel.vmdIcon).resizable().frame(width: iconSize, height: iconSize)
                            .opacity(model.isRecording ? 0.5 : 1.0)
                    }.disabled(model.isRecording)
                    
                }else{
                    //SEPARATOR
                    Text("")
                }
                /*
                //CLOUD
                Button(action: {
                 model.cameraEventListener?.itemSelected(cameraEvent: CameraEvent.Cloud)
                }){
                    //Text("􀇂")
                    Image(iconModel.activeCloudIcon).resizable().frame(width: iconSize, height: iconSize)
                }
                */
                
                
                //RECORD
                Button(action: {
                    model.cameraEventListener?.itemSelected(cameraEvent: CameraEvent.Record)
                    if model.isRecording {
                        model.isRecording = false
                        model.recordingTime = "00:00"
                    }else{
                        model.isRecording = true
                        startTimer()
                    }
                }){
                    //Text("􀢚").foregroundColor(.red)
                    Image(iconModel.recordIcon).resizable().frame(width: iconSize, height: iconSize)
                }
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
                //MUTE
                Button(action: {
                    model.volumeOn = !model.volumeOn
                    iconModel.volumeStatusChange(on: model.volumeOn)
                    model.cameraEventListener?.itemSelected(cameraEvent: CameraEvent.Mute)
                }){
                    //Text(model.volumeIcon).padding(0)
                    Image(iconModel.activeVolumeIcon).resizable().frame(width: iconSize, height: iconSize)
                
                }
                //ROTATE
                Button(action: {
                    model.cameraEventListener?.itemSelected(cameraEvent: CameraEvent.Rotate)
                }){
                  
                    Image(iconModel.rotateIcon).resizable().frame(width: iconSize, height: iconSize)
                }
                
                
                //SETTINGS
                Button(action: {
                    model.cameraEventListener?.itemSelected(cameraEvent: CameraEvent.Settings)
                }){
                    Image(iconModel.settingsIcon).resizable().frame(width: iconSize, height: iconSize)
                        .opacity((model.settingsEnabled ? 1.0 : 0.5))
                }.disabled(model.settingsEnabled == false)
                
                
                
                //Help
                Button(action: {
                    model.cameraEventListener?.itemSelected(cameraEvent: CameraEvent.Help)
                }){
                    Image(iconModel.infoIcon).resizable().frame(width: iconSize, height: iconSize)
                }
               
                
            }.padding(4).frame(width: model.toolbarWidth).background(Color(UIColor.tertiarySystemBackground)).cornerRadius(15)
            
            
        }.padding().onAppear(){
           
            iconModel.initIcons(isDark: colorScheme == .dark)
            
            if NXVProxy.isRunning {
                iconModel.cloudStatusChanged(on: true)
            }
            
            print("device model",UIDevice.current.model)
            
            if UIDevice.current.userInterfaceIdiom == .pad {
                if model.isPad{
                    model.toolbarWidth = 430
                }else{
                    model.toolbarWidth = 400
                }
            }
            
        }
    }
}

struct CameraToolbarView_Previews: PreviewProvider {
    static var previews: some View {
        CameraToolbarView()
    }
}
