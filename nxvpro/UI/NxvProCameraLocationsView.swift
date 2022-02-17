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
    
    init(cameras: DiscoveredCameras){
        self.cameras = cameras
    }
    
    var body: some View {
        let camera = self.cameras.cameras
        let hasUnassigned = self.cameras.cameraGroups.hasUnassignedCameras(allCameras: self.cameras.cameras)
        
        List{
            if hasUnassigned{
                Section(header: Text("Cameras")) {
                    ForEach(cameras.cameras, id: \.self) { cam in
                        if !cam.isNvr() && !cameras.cameraGroups.isCameraInGroup(camera: cam){
                            CameraLocationViewFactory.getInstance(camera: cam).onTapGesture{
                                model.selectedCamera = cam
                                //switchCameraView(index: 2)
                            }.listRowBackground(model.selectedCamera == cam ? Color(iconModel.selectedRowColor) : Color(UIColor.clear)).padding(0)
                        }
                    }
                }
            }
            ForEach(cameras.cameraGroups.groups, id: \.self) { grp in
                Section(header: LocationHeader(group: grp)) {
                    
                    ForEach(grp.getCameras(), id: \.self) { vcam in
                        CameraLocationViewFactory.getInstance(camera: vcam).onTapGesture{
                            model.selectedCamera = vcam
                            //switchCameraView(index: 2)
                        }.listRowBackground(model.selectedCamera == vcam ? Color(iconModel.selectedRowColor) : Color(UIColor.clear)).padding(0)
                    }
                }
            }
            ForEach(camera, id: \.self) { cam in
                if cam.isNvr(){
                    Section(header: LocationHeader(nvr: cam)){
                        ForEach(cam.vcams, id: \.self) { vcam in
                            CameraLocationViewFactory.getInstance(camera: vcam).onTapGesture{
                                model.selectedCamera = vcam
                                //switchCameraView(index: 2)
                            }.listRowBackground(model.selectedCamera == vcam ? Color(iconModel.selectedRowColor) : Color(UIColor.clear)).padding(0)
                        }
                    }
                }
            }
        }.listStyle(PlainListStyle())
    }
}


