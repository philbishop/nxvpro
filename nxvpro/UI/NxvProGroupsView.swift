//
//  NxvProGroupsView.swift
//  nxvpro
//
//  Created by Philip Bishop on 16/02/2022.
//

import SwiftUI

class NxvProGroupsModel : ObservableObject{
    @Published var vizState = 1
    var listener: CameraEventListener?
}

struct NxvProGroupsView: View, CameraChanged {
    
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var iconModel = AppIconModel()
    @ObservedObject var model = NxvProCamerasModel()
    @ObservedObject var cameras: DiscoveredCameras
    @ObservedObject var grpsModel = NxvProGroupsModel()
    
    init(cameras: DiscoveredCameras){
        self.cameras = cameras
    }
    //MARK: CameraChanged impl
    func onCameraChanged() {
        //enable / disable multicam button
        print("NxvProGroupsView:onCameraChanged")
        DispatchQueue.main.async{
            GroupHeaderFactory.checkAndEnablePlay()
        }
    }
    func getSrc() -> String {
        return "NxvProGroupsView"
    }
    func setListener(listener: CameraEventListener){
        model.listener = listener
    }
    func touch(){
        grpsModel.vizState = grpsModel.vizState + 1
    }
    var body: some View {
        //let cameraGroups = self.cameras.cameraGroups.groups
        //let camera = self.cameras.cameras
        
        VStack{
            List(){
                if(cameras.cameraGroups.groups.count == 0 && cameras.hasNvr() == false){
                    //Text(model.noGroupsLabel)
                    NoGroupsHelpView()
                }else if grpsModel.vizState > 0{
                    ForEach(cameras.cameraGroups.groups, id: \.self) { grp in
                        Section(header: GroupHeaderFactory.getHeader(group: grp,allGroups: cameras.cameraGroups.groups)) {
                            
                            ForEach(grp.getCameras(), id: \.self) { vcam in
                                if vcam.vcamVisible && vcam.isAuthenticated(){
                                    ZStack(alignment: .top){
                                        DiscoCameraViewFactory.getInstance(camera:  vcam).onTapGesture {
                                            model.selectedCamera = vcam
                                            model.listener?.onCameraSelected(camera: vcam, isMulticamView: false)
                                        }
                                        
                                    }
                                    .listRowBackground(model.selectedCamera == vcam ? Color(iconModel.selectedRowColor) : Color(UIColor.clear)).padding(0)
                                }
                            }
                            
                        }
                    }
                
               
                    ForEach(cameras.cameras, id: \.self) { cam in
                        if cam.isNvr(){
                            
                            Section(header: GroupHeaderFactory.getNvrHeader(camera: cam)) {
                                if cam.vcamVisible && cam.isAuthenticated(){
                                    ForEach(cam.vcams, id: \.self) { vcam in
                                        
                                        ZStack(alignment: .top){
                                            DiscoCameraViewFactory.getInstance(camera:  vcam).onTapGesture {
                                                model.selectedCamera = vcam
                                                model.listener?.onCameraSelected(camera: vcam, isMulticamView: false)
                                            }
                                           
                                        }
                                        .listRowBackground(model.selectedCamera == vcam ? Color(iconModel.selectedRowColor) : Color(UIColor.clear)).padding(0)
                                    }
                                }
                            }
                        }
                    }
                }
                
            }.listStyle(PlainListStyle())
        }.onAppear{
            DiscoCameraViewFactory.addListener(listener: self)
            GroupHeaderFactory.checkAndEnablePlay()
        }
        
    }
}


