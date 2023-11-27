//
//  NxvProCameraLocationsView.swift
//  nxvpro
//
//  Created by Philip Bishop on 17/02/2022.
//

import SwiftUI


struct NxvProCameraLocationsView: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var iconModel = AppIconModel()
    
    @ObservedObject var cameras: DiscoveredCameras
    
    @ObservedObject var model = NxvProCamerasModel()
    @ObservedObject var grpsModel = NxvProGroupsModel()
    
    let netStreams = AllNetStreams()
    
    init(cameras: DiscoveredCameras){
        self.cameras = cameras
    }
    func touch(){
        CameraLocationViewFactory.reset()
        model.vizState = model.vizState + 1
    }
    func setListener(listener: CameraEventListener){
        model.listener = listener
    }
    
    private func hasUnassignedNetStreams(_ ns: AllNetStreams) -> Bool{
        for vcam in ns.cameras{
           
            if cameras.cameraGroups.isCameraInGroup(camera: vcam) == false{
                return true
            }
        
        }
        return false
    }
    
    private func netStreamView(_ ns: AllNetStreams) -> some View{
        ForEach(ns.cameras, id: \.self) { vcam in
            if cameras.cameraGroups.isCameraInGroup(camera: vcam) == false{
                if vcam.locCamVisible{
                    CameraLocationViewFactory.getInstance(camera: vcam).onTapGesture{
                        model.selectedCamera = vcam
                        model.listener?.onCameraLocationSelected(camera: vcam)
                    }.listRowBackground(model.selectedCamera == vcam ? Color(iconModel.selectedRowColor) : Color(UIColor.clear)).padding(0)
                }
            }
        }
    }
    private func cameraListAdvanced() -> some View{
        Group{
            if #available(iOS 17, *){
                //.
                camerasList()
                    .background(colorScheme == .dark ? .clear : .white)
                    .scrollContentBackground(.hidden)
                    .listSectionSpacing(.compact)
                    .listStyle(.grouped)
            }else{
                camerasList().listStyle(PlainListStyle())
            }
        }
    }
    private func camerasList() -> some View{
        List(){
            let camera = self.cameras.cameras
            let hasUnassigned = self.cameras.cameraGroups.hasUnassignedCameras(allCameras: self.cameras.cameras)
            
            if model.vizState > 0 {
                if cameras.cameras.count == 0{
                    Text("No cameras found").appFont(.caption)
                }else if grpsModel.vizState > 0{
                    
                    ForEach(cameras.cameraGroups.groups, id: \.self) { grp in
                        let gcams = grp.getCameras()
                        if gcams.count > 0 {
                            Section(header: LocationHeaderFactory.getHeader(group: grp)) {
                                
                                ForEach(grp.getCameras(), id: \.self) { vcam in
                                    if vcam.locCamVisible{
                                        CameraLocationViewFactory.getInstance(camera: vcam).onTapGesture{
                                            model.selectedCamera = vcam
                                            model.listener?.onCameraLocationSelected(camera: vcam)
                                        }
                                        .listRowInsets(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
                                        .listRowBackground(model.selectedCamera == vcam ? Color(iconModel.selectedRowColor) : Color(UIColor.clear)).padding(0)
                                    }
                                }
                            }.listRowInsets(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
                        }
                    }
                    ForEach(camera, id: \.self) { cam in
                        if cam.isNvr(){
                            Section(header: LocationHeaderFactory.getHeader(nvr: cam)){
                                if cam.locCamVisible{
                                    ForEach(cam.vcams, id: \.self) { vcam in
                                        CameraLocationViewFactory.getInstance(camera: vcam).onTapGesture{
                                            model.selectedCamera = vcam
                                            model.listener?.onCameraLocationSelected(camera: vcam)
                                        }
                                        .listRowInsets(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
                                        .listRowBackground(model.selectedCamera == vcam ? Color(iconModel.selectedRowColor) : Color(UIColor.clear)).padding(0)
                                    }
                                }
                            }.listRowInsets(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
                        }
                    }
                    
                    if hasUnassigned{
                        Section(header: LocationHeaderFactory.getUnassignedHeader(cameras: cameras.cameras, cameraGroups: cameras.cameraGroups)){
                            ForEach(cameras.cameras, id: \.self) { cam in
                                if cam.locCamVisible{
                                    if !cam.isNvr() && !cameras.cameraGroups.isCameraInGroup(camera: cam){
                                        CameraLocationViewFactory.getInstance(camera: cam).onTapGesture{
                                            model.selectedCamera = cam
                                            model.listener?.onCameraLocationSelected(camera: cam)
                                        }
                                        .listRowInsets(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
                                        .listRowBackground(model.selectedCamera == cam ? Color(iconModel.selectedRowColor) : Color(UIColor.clear)).padding(0)
                                    }
                                }
                            }.listRowInsets(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
                        }
                    }
                    if hasUnassignedNetStreams(netStreams){
                        Section(header: LocationHeaderFactory.getNetStreamHeader(cameras: netStreams.cameras, cameraGroups: cameras.cameraGroups)){
                            netStreamView(netStreams)
                        }.listRowInsets(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
                    }
                }
            }
            
        }
    }
    var body: some View {
        
        VStack{
                cameraListAdvanced()
            
            HStack(spacing: 10){
                Button(action:{
                    let expanded = grpsModel.expandedMode
                    grpsModel.expandedMode = !expanded
                    LocationHeaderFactory.expandCollapseAll(expanded:  grpsModel.expandedMode)
                    globalCameraEventListener?.onGroupStateChanged(reload: false)
                    
                }){
                    HStack{
                        Image(systemName: (grpsModel.expandedMode ? "arrow.right.circle" : "arrow.down.circle")).resizable().frame(width: 18,height: 18)
                        Text(grpsModel.expandedMode ? "Collapse all" : "Expand all").appFont(.body)
                    }
                }
                Spacer()
            }.padding()
        }
    }
}


