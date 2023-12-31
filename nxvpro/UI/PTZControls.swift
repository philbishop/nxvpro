//
//  PTZControls.swift
//  DesignIdeas
//
//  Created by Philip Bishop on 30/05/2021.
//

import SwiftUI

class PTZControlsModel : ObservableObject{
    @Published var toolbarWidth = CGFloat(450)
    @Published var isSmallScreen = false
    @Published var showLabel = false
    @Published var presetsEnabled = false
    @Published var spacing = CGFloat(10)
    @Published var padding = CGFloat(4)
    @Published var helpHidden = false
    var ptzCamera: Camera?
    var presetListener: PtzPresetEventListener?
    var toolbarListener: CameraToolbarListener?
    
    init(){
        showLabel = (UIDevice.current.userInterfaceIdiom == .pad)
        if UIDevice.current.userInterfaceIdiom == .phone{
           toolbarWidth = 325
            spacing = 3.5
            padding = 0
        }
    }
    
    func setPresetsEnabled(enabled: Bool){
        presetsEnabled = enabled
    }
    
    
}

struct PTZControls: View, PtzActionHandler {
    
    func setCamera(camera: Camera,toolbarListener: CameraToolbarListener,presetListener: PtzPresetEventListener?){
        model.ptzCamera = camera
        model.toolbarListener = toolbarListener
        model.presetListener = presetListener
        model.presetsEnabled = false
    }
    
    func onActionStart(action: PtzAction){
        AppLog.write("onActionStart",action)
        
        if action == PtzAction.Presets{
            //TO DO
            return
        }
        let ptzCmd = OnvifDisco()
        ptzCmd.prepare();
        ptzCmd.sendPtzStartCommand(camera: model.ptzCamera!, cmd: action)
        
    }
    func onActionEnd(action: PtzAction){
        AppLog.write("onActionEnd",action)
        
        if(action == PtzAction.none || action == PtzAction.help || action == PtzAction.Presets){
            return
        }
        
        let ptzCmd = OnvifDisco()
        ptzCmd.prepare();
        let isZoom = (action == PtzAction.zoomin || action == PtzAction.zoomout)
        ptzCmd.sendPtzStopCommand(camera: model.ptzCamera!,isZoom: isZoom)
    }
    
    @ObservedObject var model = PTZControlsModel()
    
    @ObservedObject var iconModel = AppIconModel()
    @Environment(\.colorScheme) var colorScheme
    
    var btnSize = CGFloat(30)
    var btnPadding: CGFloat = 0.0
    var nativeSize = CGFloat(34)
    var body: some View {
        HStack(){
            HStack(alignment: .center,spacing: model.spacing){
            
            Text("PTZ").font(.system(size: 12,weight: .semibold)).hidden(model.showLabel == false)
            
            PtzButtonView(icon: iconModel.ptzLeft,action: PtzAction.left,handler: self).frame(width: btnSize, height: btnSize).padding(btnPadding).clipShape(/*@START_MENU_TOKEN@*/Circle()/*@END_MENU_TOKEN@*/)
           
            PtzButtonView(icon: iconModel.ptzRight,action: PtzAction.right,handler: self).frame(width: btnSize, height: btnSize).padding(btnPadding).clipShape(/*@START_MENU_TOKEN@*/Circle()/*@END_MENU_TOKEN@*/)
            
            PtzButtonView(icon: iconModel.ptzUp,action: PtzAction.up,handler: self).frame(width: btnSize, height: btnSize).padding(btnPadding).clipShape(/*@START_MENU_TOKEN@*/Circle()/*@END_MENU_TOKEN@*/)
            
            PtzButtonView(icon: iconModel.ptzDown,action: PtzAction.down,handler: self).frame(width: btnSize, height: btnSize).padding(btnPadding).clipShape(/*@START_MENU_TOKEN@*/Circle()/*@END_MENU_TOKEN@*/)
           
            PtzButtonView(icon: iconModel.ptzZoomIn,action: PtzAction.zoomin,handler: self).frame(width: btnSize, height: btnSize).padding(btnPadding).clipShape(/*@START_MENU_TOKEN@*/Circle()/*@END_MENU_TOKEN@*/)
           
            PtzButtonView(icon: iconModel.ptzZoomOut,action: PtzAction.zoomout,handler: self).frame(width: btnSize, height: btnSize).padding(btnPadding).clipShape(/*@START_MENU_TOKEN@*/Circle()/*@END_MENU_TOKEN@*/)
           
            //if model.presetsEnabled{
               //PRESETS
                Button(action: {
                    if model.presetsEnabled{
                        model.presetListener?.togglePtzPresets()

                    }
                }){
                    Image(iconModel.ptzIcon).resizable()
                        .opacity(model.presetsEnabled ? 1.0 : 0.5)
                        .frame(width: nativeSize, height: nativeSize)
                       
                }.padding(0).buttonStyle(PlainButtonStyle())
                    
            //}
            
            //Help
            Button(action: {
                model.toolbarListener?.itemSelected(cameraEvent: .Help)
            }){
                Image(iconModel.infoIcon).resizable().frame(width: nativeSize, height: nativeSize)
            }.padding(0).buttonStyle(PlainButtonStyle())
                    .hidden( model.helpHidden )
        
            
            //CLOSE
            Button(action: {
                model.toolbarListener?.itemSelected(cameraEvent: CameraActionEvent.CloseToolbar)
                //globalEventListener?.hidePtzPresets()
            }){
               
                Image(iconModel.closeIcon).resizable().frame(width: nativeSize,height: nativeSize)
            }.padding(0).buttonStyle(PlainButtonStyle())
           
            }.padding(model.padding)
        .frame(width: model.toolbarWidth).background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(15)
            
        }.padding().onAppear(){
            AppLog.write("PtzToolbar:onAppear")
            iconModel.initIcons(isDark: colorScheme == .dark)
            
            if model.isSmallScreen {
                model.toolbarWidth = 295
            }
            
        }
    }
}

struct PTZControls_Previews: PreviewProvider {
    static var previews: some View {
            ZStack(alignment: .center){
                PTZControls()
        }.frame(width: 400,height: 400)
    }
}
