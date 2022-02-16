//
//  NvrHeader.swift
//  DesignIdeas
//
//  Created by Philip Bishop on 05/09/2021.
//

import SwiftUI

class NvrHeaderModel : ObservableObject{
    @Published var vGroup: CameraGroup
    @Published var playEnabled: Bool
    @Published var rotation: Double = 90
    
    init(camera: Camera){
        self.playEnabled = true
        self.vGroup = CameraGroup()
        self.vGroup.id = Camera.VCAM_BASE_ID + camera.id
        self.vGroup.isNvr = true
        self.vGroup.name = camera.name
        self.vGroup.cameraIps.append(camera.getDisplayAddr())
        self.vGroup.cameras.append(camera)
        
    }
    
}

struct NvrHeader: View {
 
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var iconModel = AppIconModel()
    @ObservedObject var model: NvrHeaderModel
    
    var camera: Camera
    @State var groupName: String = "";
    
    init(camera: Camera){
        self.camera = camera
        self.model = NvrHeaderModel(camera: camera)
        
    }
    func enablePlay(enable: Bool){
        model.playEnabled = enable
    }
    var body: some View {
        HStack{
            Button(action: {
                if model.rotation == 0{
                    model.rotation = 90
                }else{
                    model.rotation = 0
                }
                camera.vcamVisible = model.rotation == 90
                
                globalCameraEventListener?.onGroupStateChanged()
                
            }){
                Image(systemName: (model.rotation==0 ? "arrow.right.circle" : "arrow.down.circle")).resizable().frame(width: 18,height: 18)
            }.padding(0).buttonStyle(PlainButtonStyle())
             
            Text(camera.getDisplayName())
           
            Spacer()
            
            Button(action:{
                //globalToolbarListener?.openGroupMulticams(group: model.vGroup)
            }){
                Image(iconModel.playIcon).resizable().opacity((model.playEnabled ? 1 : 0.5))
                    .frame(width: 18,height: 18)
            }.buttonStyle(PlainButtonStyle()).disabled(model.playEnabled==false)
           
            .padding()
        }.onAppear(){
            self.groupName = self.camera.name
            
            iconModel.initIcons(isDark: colorScheme == .dark)
        }
    }
}


