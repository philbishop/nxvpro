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
    
    var body: some View {
        let camera = self.cameras.cameras
        let hasUnassigned = self.cameras.cameraGroups.hasUnassignedCameras(allCameras: self.cameras.cameras)
        VStack{
            List{
                if model.vizState > 0 {
                    if cameras.cameras.count == 0{
                        Text("No cameras found").appFont(.caption)
                    }else if grpsModel.vizState > 0{
                        
                        ForEach(cameras.cameraGroups.groups, id: \.self) { grp in
                            Section(header: LocationHeaderFactory.getHeader(group: grp)) {
                                
                                ForEach(grp.getCameras(), id: \.self) { vcam in
                                    if vcam.locCamVisible{
                                        CameraLocationViewFactory.getInstance(camera: vcam).onTapGesture{
                                            model.selectedCamera = vcam
                                            model.listener?.onCameraLocationSelected(camera: vcam)
                                        }.listRowBackground(model.selectedCamera == vcam ? Color(iconModel.selectedRowColor) : Color(UIColor.clear)).padding(0)
                                    }
                                }
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
                                            }.listRowBackground(model.selectedCamera == vcam ? Color(iconModel.selectedRowColor) : Color(UIColor.clear)).padding(0)
                                        }
                                    }
                                }
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
                                            }.listRowBackground(model.selectedCamera == cam ? Color(iconModel.selectedRowColor) : Color(UIColor.clear)).padding(0)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
            }.listStyle(PlainListStyle())
            
            HStack(spacing: 10){
                Button(action:{
                    let expanded = grpsModel.expandedMode
                    grpsModel.expandedMode = !expanded
                    LocationHeaderFactory.expandCollapseAll(expanded:  grpsModel.expandedMode)
                    globalCameraEventListener?.onGroupStateChanged(reload: false)
                    
                }){
                    HStack{
                        Image(systemName: (grpsModel.expandedMode ? "arrow.right.circle" : "arrow.down.circle")).resizable().frame(width: 18,height: 18)
                        Text(grpsModel.expandedMode ? "Collapse all" : "Expand all")
                    }
                }
                Spacer()
            }.padding()
        }
    }
}


