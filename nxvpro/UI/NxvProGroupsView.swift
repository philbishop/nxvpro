//
//  NxvProGroupsView.swift
//  nxvpro
//
//  Created by Philip Bishop on 16/02/2022.
//

import SwiftUI

class NxvProGroupsModel : ObservableObject{
    @Published var vizState = 1
}

struct NxvProGroupsView: View {
    
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var iconModel = AppIconModel()
    @ObservedObject var model = NxvProCamerasModel()
    @ObservedObject var cameras: DiscoveredCameras
    @ObservedObject var grpsModel = NxvProGroupsModel()
    
    init(cameras: DiscoveredCameras){
        self.cameras = cameras
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
                                            //handleDiscoveredCameraTap(cam: vcam)
                                        }
                                        
                                        /*
                                        VStack(alignment: .top){
                                            HStack{
                                                let dcv = DiscoCameraViewFactory.getInstance(camera:  vcam)
                                                Spacer()
                                                Button(action: {
                                                    let isFav = dcv.toggleAndUpdateFavIcon()
                                                    print("DiscoverCameraUIView:favbutton click",isFav)
                                                    
                                                    model.selectedCamera = nil
                                                    model.selectedCamera = vcam
                                                    favsHelpHidden = true
                                                    
                                                }){
                                                    Image(vcam.isFavorite ? iconModel.activeFavIcon : iconModel.favIcon).resizable().frame(width: 24,height: 24)
                                                    
                                                }.buttonStyle(PlainButtonStyle()).padding(0)
                                                
                                            }
                                        }
                                         */
                                    }
                                    .listRowBackground(model.selectedCamera == vcam ? Color(iconModel.selectedRowColor) : Color(UIColor.tertiarySystemBackground)).padding(0)
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
                                                //handleDiscoveredCameraTap(cam: vcam)
                                            }
                                           
                                            /*
                                            HStack(alignment: .top){
                                                //let fc = model.setFav(camera: cam)
                                                let dcv = DiscoCameraViewFactory.getInstance(camera:  vcam)
                                                Spacer()
                                                Button(action: {
                                                    let isFav = dcv.toggleAndUpdateFavIcon()
                                                    print("DiscoverCameraUIView:favbutton click",isFav)
                                                    
                                                    model.selectedCamera = nil
                                                    model.selectedCamera = vcam
                                                    //favsHelpHidden = true
                                                    
                                                }){
                                                    Image(vcam.isFavorite ? iconModel.activeFavIcon : iconModel.favIcon).resizable().frame(width: 24,height: 24)
                                                    
                                                }.buttonStyle(PlainButtonStyle())
                                                
                                            }.hidden(cam.isAuthenticated() == false)
                                            */
                                        }
                                        .listRowBackground(model.selectedCamera == vcam ? Color(iconModel.selectedRowColor) : Color(UIColor.tertiarySystemBackground)).padding(0)
                                    }
                                }
                            }
                        }
                    }
                }
                
            }.listStyle(PlainListStyle())
        }
    }
}


