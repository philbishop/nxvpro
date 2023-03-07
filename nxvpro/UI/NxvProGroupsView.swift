//
//  NxvProGroupsView.swift
//  nxvpro
//
//  Created by Philip Bishop on 16/02/2022.
//

import SwiftUI

class NxvProGroupsModel : ObservableObject{
    @Published var vizState = 1
    @Published var expandedMode = true
    
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
        AppLog.write("NxvProGroupsView:onCameraChanged")
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
    func highlightGroupNvr(camera: Camera){
        
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
                        
                   
                        ForEach(cameras.cameras, id: \.self) { cam in
                            if cam.isNvr(){
                               
                                Section(header: GroupHeaderFactory.getNvrHeader(camera: cam)) {
                                    if cam.gcamVisible && cam.isAuthenticated(){
                                        ForEach(cam.vcams, id: \.self) { vcam in
                                            
                                                DiscoCameraViewFactory.getInstance2(camera:  vcam).onTapGesture {
                                                    model.selectedCamera = vcam
                                                    model.listener?.onCameraSelected(camera: vcam, isCameraTap: true)
                                                    DiscoCameraViewFactory.setCameraSelected(camera: vcam)
                                                }
                                                .listRowInsets(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
                                                .listRowBackground(model.selectedCamera == vcam ? Color(iconModel.selectedRowColor) : Color(UIColor.clear)).padding(0)
                                        }
                                    }
                                 
                                }.listRowInsets(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
                                 
                            }
                        }
                        
                        ForEach(cameras.cameraGroups.groups, id: \.self) { grp in
                            if grp.cameras.count > 0 {
                                Section(header: GroupHeaderFactory.getHeader(group: grp,allGroups: cameras.cameraGroups.groups)) {
                                    
                                    ForEach(grp.getCameras(), id: \.self) { vcam in
                                        if vcam.gcamVisible && (vcam.isAuthenticated() || grp.name == CameraGroup.MISC_GROUP){
                                            DiscoCameraViewFactory.getInstance2(camera:  vcam).onTapGesture {
                                                //if grp.name != CameraGroup.MISC_GROUP{
                                                    model.selectedCamera = vcam
                                                    model.listener?.onCameraSelected(camera: vcam, isCameraTap: false)
                                                //}
                                            }
                                            .listRowInsets(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
                                            .listRowBackground(model.selectedCamera == vcam ? Color(iconModel.selectedRowColor) : Color(UIColor.clear)).padding(0)
                                        }
                                    }
                                    
                                }.listRowInsets(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
                            }
                        }
                    }
                    
                }.listStyle(PlainListStyle())
                
                Spacer()
                HStack(spacing: 10){
                    Button(action:{
                        let expanded = grpsModel.expandedMode
                        grpsModel.expandedMode = !expanded
                        GroupHeaderFactory.expandCollapseAll(expanded:  grpsModel.expandedMode)
                        globalCameraEventListener?.onGroupStateChanged(reload: false)
                        
                    }){
                        HStack{
                            Image(systemName: (grpsModel.expandedMode ? "arrow.right.circle" : "arrow.down.circle")).resizable().frame(width: 18,height: 18)
                            Text(grpsModel.expandedMode ? "Collapse all" : "Expand all").appFont(.body)
                        }
                    }
                    Spacer()
                }
                .padding()
            }
            .onAppear{
                DiscoCameraViewFactory.addListener(listener: self)
                GroupHeaderFactory.checkAndEnablePlay()
            }
            
        }
}


