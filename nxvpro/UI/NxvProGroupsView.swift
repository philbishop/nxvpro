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
    @Published var moveMode = false
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
                    if(hasGroups(checkViz: false)==false){
                        //Text(model.noGroupsLabel)
                        NoGroupsHelpView()
                    }else if grpsModel.vizState > 0{
                        
                   
                        ForEach(cameras.cameras, id: \.self) { cam in
                            if cam.isNvr(){
                                let vcams = cam.getSortedVCams()
                                Section(header: GroupHeaderFactory.getNvrHeader(camera: cam)) {
                                    if cam.gcamVisible && cam.isAuthenticated(){
                                        ForEach(vcams, id: \.self) { vcam in
                                            /*
                                                DiscoCameraViewFactory.getInstance2(camera:  vcam).onTapGesture {
                                                    model.selectedCamera = vcam
                                                    model.listener?.onCameraSelected(camera: vcam, isCameraTap: true)
                                                    DiscoCameraViewFactory.setCameraSelected(camera: vcam)
                                                }
                                             */
                                             DiscoveredCameraViewWrapper(camera: vcam, model: model, viewId: 2)
                                                .listRowInsets(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
                                                .listRowBackground(model.selectedCamera == vcam ? Color(iconModel.selectedRowColor) : Color(UIColor.clear)).padding(0)
                                        }
                                        .onMove { from, to in
                                            onListMove(vcams, from: from, to: to)
                                             
                                        }
                                    }
                                 
                                }.listRowInsets(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
                                 
                            }
                        }
                        
                        ForEach(cameras.cameraGroups.groups, id: \.self) { grp in
                            if grp.cameras.count > 0 {
                                let gcams = grp.getCameras()
                                Section(header: GroupHeaderFactory.getHeader(group: grp,allGroups: cameras.cameraGroups.groups)) {
                                    
                                    ForEach(gcams, id: \.self) { vcam in
                                        if vcam.gcamVisible && (vcam.isAuthenticated() || grp.name == CameraGroup.MISC_GROUP){
                                            
                                            DiscoveredCameraViewWrapper(camera: vcam, model: model, viewId: 2)
                                            .listRowInsets(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
                                            .listRowBackground(model.selectedCamera == vcam ? Color(iconModel.selectedRowColor) : Color(UIColor.clear)).padding(0)
                                        }
                                    }.onMove { from, to in
                                        onListMove(gcams, from: from, to: to)
                                         
                                    }
                                    
                                }.listRowInsets(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
                            }
                        }
                    }
                    
                }.listStyle(PlainListStyle())
                
                Spacer()
                if hasGroups(checkViz: true){
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
                        
                        toggleMoveView()
                        
                    }
                    .padding()
                }
            }
            .onAppear{
                DiscoCameraViewFactory.addListener(listener: self)
                GroupHeaderFactory.checkAndEnablePlay()
                
            }
            .environment(\.editMode, model.moveMode ? .constant(.active) : .constant(.inactive))
            
        }
    
    private func hasGroups(checkViz: Bool)-> Bool{
        for cam in cameras.cameras{
            if cam.isNvr(){
                return true
            }
        }
        for grp in cameras.cameraGroups.groups{
            let gcams = grp.getCameras()
            for gcam in gcams{
                if checkViz == false{
                    return true
                }
                if gcam.gcamVisible{
                    return true
                }
            }
        }
        return false
    }
    //MARK: Drag Move
    private func toggleMoveView() -> some View{
        Button(action:{
            toggleMoveMode()
            
        }){
            Image(systemName: toggleMoveIcon()).resizable()
                .frame(width: 18,height: 18)
        }.buttonStyle(.plain)
    }
    
    func toggleMoveIcon()->String{
        if model.moveMode{
            return "arrow.up.arrow.down.circle"
        }else{
            return "arrow.up.arrow.down"
        }
    }
    func disableMove(){
        model.moveMode = false
    }
    func toggleMoveMode(){
        model.moveMode = !model.moveMode
        if model.moveMode == false{
            cameras.sortByDisplayOrder()
        }
        DiscoCameraViewFactory.makeGroupThumbVisible(viz: model.moveMode==false)
    }
    func onListMove(_ cams: [Camera],from source: IndexSet, to destination: Int){
        debugPrint("Group:move camera",source,destination)
        
        var gcams = cams
        gcams.move(fromOffsets: source, toOffset: destination)
        for i in 0...gcams.count-1{
            let cam = gcams[i]
            cam.displayOrder = i
            cam.save()
        }
        
        for gc in gcams{
            debugPrint("Group:order",gc.getDisplayName())
        }
        
        DispatchQueue.main.async{
            model.vizState = model.vizState + 1
        }
    }
}


