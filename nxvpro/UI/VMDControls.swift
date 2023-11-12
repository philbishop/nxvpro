//
//  VMDControls.swift
//  DesignIdeas
//
//  Created by Philip Bishop on 30/05/2021.
//

import SwiftUI
struct CheckToggleStyle: ToggleStyle {
    
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            Label {
                configuration.label
            } icon: {
                Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "smallcircle.circle")
                    .foregroundColor(configuration.isOn ? .accentColor : .secondary)
                    .accessibility(label: Text(configuration.isOn ? "Checked" : "Unchecked"))
                    .appFont(.title)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
struct CheckBoxToggleStyle: ToggleStyle {
    
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            Label {
                configuration.label
            } icon: {
                Image(systemName: configuration.isOn ? "checkmark.square" : "square")
                    .foregroundColor(configuration.isOn ? .primary : .secondary)
                    .accessibility(label: Text(configuration.isOn ? "Checked" : "Unchecked"))
                    .appFont(.caption)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
protocol VmdEventListener{
    func vmdVideoEnabledChanged(camera: Camera,enabled: Bool)
    func vmdEnabledChanged(camera: Camera,enabled: Bool)
    func vmdSensitivityChanged(camera: Camera,sens: Int)
    func showHelpContext(context: Int)
    func closeVmd()
}

class VmdLevelModel: ObservableObject {
    @Published var curX: CGFloat = 0
    @Published var sensitivity: Double = 0.0
    @Published var sensPercent: Float = 0.0
    @Published var vmdEnabled: Bool = false
    @Published var videoEnabled: Bool = false
    @Published var currentCamera: Camera?
    @Published var isPad = false
    @Published var isSmallScreen = false
    var ctrlWidth = CGFloat(170)
    @Published var toolbarWidth = CGFloat(360)
    @Published var sliderWidth = CGFloat(150)
    @Published var spacing = CGFloat(1.5)
    
    var listener: VmdEventListener?
    
    var max = CGFloat(300)
    
    func setAsSmallScreen(isSmall: Bool){
        isSmallScreen = isSmall
            
         if UIDevice.current.userInterfaceIdiom == .pad {
            isPad = true
            spacing = 2
            toolbarWidth = 460
            sliderWidth = 200
        }else{
            toolbarWidth = 325
            sliderWidth = 105
            spacing = 1.5
        }
        //
    }
    
    func reset(){
         curX = 0
    }
    func setCurrent(pk: Int){
        var level = CGFloat(pk)
        if level > max {
            level = max
        }
        
        let pc = (CGFloat(level)/max) * 100
        curX = 200 * (pc/100)
        AppLog.write("VmdLevelModel",curX)
    }
}

//var globalVmdCtrls: VMDControls?

struct VMDControls: View, MotionDetectionListener, NxvSliderListener {
    
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var model = VmdLevelModel()
    @ObservedObject var iconModel = AppIconModel()
    
    @State var showVideOn: Bool = false
    var maxSens: Float = 300.0
    @State var slider = NxvSlider()
    
    func resetVmd(){
        AppLog.write("In VMDCtrls setCamera")
        fflush(stdout)
        model.reset()
    }
    func nxvSliderChangeEnded(source: NxvSlider) {
        if let cam = model.currentCamera{
            cam.save()
        }
    }
    func nxvSliderChanged(percent: Float,source: NxvSlider){
       let sens = maxSens - (maxSens * (percent/100))
        AppLog.write("VmdControls:nxvSliderChanged",sens)
        model.listener?.vmdSensitivityChanged(camera: model.currentCamera!,sens: Int(sens))
    }
    
    func setCamera(camera: Camera,listener: VmdEventListener){
        model.listener = listener
        
        //auto record for iOS, simplifies views
        if showVideOn == false {
            camera.vmdVidOn = true
        }
        
        model.currentCamera = camera
        model.sensitivity = Double(camera.vmdSens)
        
        var senspc = (Float(model.sensitivity) / maxSens) * 100.0
        if senspc == 0 {
           senspc = 95
            
        }
        model.sensPercent = senspc
        slider.setPercentage(pc: 100 - senspc)
        slider.setInnerPercentage(pc: 0)
        model.videoEnabled = camera.vmdVidOn
        model.vmdEnabled = camera.vmdOn
        iconModel.vmdStatusChange(status: camera.vmdOn ? 1 : 0)
    }
    
    func onMotionEvent(camera: Camera, start: Bool, time: Date, box: MotionMetaData) {
        
        if model.currentCamera?.xAddr == camera.xAddr {
            if start {
                AppLog.write("VMDControls:onMotionEvent on",start)
            }
            
            //to route back to camera labels
            globalCameraEventListener?.onMotionEvent(camera: camera, start: start)
        
            iconModel.vmdStatusChange(status: start ? 2 : 1)
        }
       
    }
    func onLevelChanged(camera: Camera,level: Int) {
        if model.currentCamera?.xAddr == camera.xAddr {
            model.setCurrent(pk: level)
            slider.setInnerPercentage(pc: Float(level))
        }else{
            AppLog.write("VmdControls:onLevelChange for different camera")
        }
    }
    
    var body: some View {
       
            ZStack(alignment: .bottom){
                HStack(spacing: model.spacing){
                    
                    if model.isPad && !model.isSmallScreen{
                        Text("Motion").font(.system(size: 12,weight: .semibold))
                        Text("Low").font(.system(size: 10,weight: .light))
                    }else{
                        Text("Motion ").font(.system(size: 10,weight: .semibold))
                    }
                   
                    slider.frame(width: model.sliderWidth,height: 26)
                   
                    if model.isPad && !model.isSmallScreen{
                        Text("high").font(.system(size: 10,weight: .light))
                    }else{
                        Text(" ")
                    }
                    Toggle("",isOn: $model.vmdEnabled).toggleStyle(CheckToggleStyle()).onChange(of: model.vmdEnabled, perform: { value in
                        AppLog.write("VMDControls:vmdOn",model.vmdEnabled)
                        
                        if let cam = model.currentCamera{
                            cam.vmdOn = model.vmdEnabled
                           
                            iconModel.vmdStatusChange(status: model.vmdEnabled ? 1 : 0)
                            model.listener?.vmdEnabledChanged(camera:cam,enabled: model.vmdEnabled)
                            cam.save()
                        }
                    })
                    
                    Image(iconModel.activeVmdIcon).resizable().frame(width: iconModel.iconSize,height: iconModel.iconSize)
                
                    if showVideOn {
                        Button(action: {
                            if let cam = model.currentCamera{
                                model.videoEnabled = !model.videoEnabled
                                iconModel.vidOnStatusChanged(isOn: model.videoEnabled)
                                cam.vmdVidOn = model.videoEnabled
                                cam.save()
                                model.listener?.vmdVideoEnabledChanged(camera: cam, enabled: model.videoEnabled)
                            }
                        }){
                            Image(iconModel.activeVidIcon).resizable().frame(width: iconModel.iconSize,height: iconModel.iconSize)
                        }
                        
                        .contextMenu(ContextMenu(menuItems: {
                            Button("10 seconds",action: {model.currentCamera?.vmdRecTime = 10}).disabled(model.currentCamera?.vmdRecTime == 10)
                            Button("20 seconds",action: {model.currentCamera?.vmdRecTime = 20}).disabled(model.currentCamera?.vmdRecTime == 20)
                            Button("30 seconds",action: {model.currentCamera?.vmdRecTime = 30}).disabled(model.currentCamera?.vmdRecTime == 30)
                        }))
                    }
                    //Help
                    Button(action: {
                        //cameraPageInstance?.itemSelected(itemIndex: 61)
                        model.listener?.showHelpContext(context: 1)
                    }){
                        Image(iconModel.infoIcon).resizable().frame(width: iconModel.iconSize, height: iconModel.iconSize)
                    }.buttonStyle(.plain)
                   
                    //CLOSE
                    Button(action: {
                        model.listener?.closeVmd()
                    }){
                       
                        Image(iconModel.closeIcon).resizable().frame(width: 32,height: 32)
                    }.buttonStyle(.plain)
                }
                
            }
            .padding(4).frame(width: model.toolbarWidth,height: 42).background(Color(UIColor.tertiarySystemBackground)).cornerRadius(15).onAppear(){
                iconModel.initIcons(isDark: colorScheme == .dark)
                iconModel.vmdStatusChange(status: model.vmdEnabled ? 1 : 0)
                iconModel.vidOnStatusChanged(isOn: model.videoEnabled)
                //globalVmdCtrls = self
            }.padding()
            .onAppear(){
                slider.listener = self
                model.setAsSmallScreen(isSmall: false)
                
            }
    }
}

struct VMDControls_Previews: PreviewProvider {
    static var previews: some View {
        VMDControls()
    }
}

