//
//  SingleCameraView.swift
//  nxvpro
//
//  Created by Philip Bishop on 12/02/2022.
//

import SwiftUI

class SingleCameraModel : ObservableObject{
    @Published var toolbarHidden = true
    @Published var helpHidden = true
}

struct SingleCameraView : View, CameraToolbarListener, ContextHelpViewListener{
    
    @ObservedObject var model = SingleCameraModel()
    
    let thePlayer = CameraStreamingView()
    let toolbar = CameraToolbarView()
    let helpView = ContextHelpView()
    
    func hideControls(){
        model.toolbarHidden = true
    }
    func showToolbar(){
        model.toolbarHidden = false
    }
    
    //MARK: ContextHelpViewListener
    func onCloseHelp() {
        model.helpHidden = true
    }
    
    //MARK: CameraToolbarListener
    func itemSelected(cameraEvent: CameraEvent) {
        //Ptz, Vmd, Mute, Record, Cloud, Rotate, Settings, Help, CloseToolbar, ProfileChanged, CapturedVideos, StopVideoPlayer, StopMulticams, Feedback, StopMulticamsShortcut, Imaging
        switch(cameraEvent){
        case .Ptz:
            
            break
        case .Vmd:
            
            break
            
        case .Record:
            break
            
        case .Rotate:
            break
            
        case .Settings:
            break
            
        case .Help:
            helpView.setContext(contextId: 0, listener: self)
            model.helpHidden = false
            break
            
        default:
            break
        }
    }
    
    
    //MARK: BODY
    var body: some View {
        ZStack(alignment: .bottom){
            thePlayer
            toolbar.hidden(model.toolbarHidden)
            
            VStack{
                Spacer()
                HStack{
                    Spacer()
                    helpView
                }
                Spacer()
                
            }.hidden(model.helpHidden)
        }.onAppear{
            toolbar.setListener(listener: self)
        }
    }
}
