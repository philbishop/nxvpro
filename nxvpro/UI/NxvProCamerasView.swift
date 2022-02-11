//
//  NxvProCamerasView.swift
//  nxvpro
//
//  Created by Philip Bishop on 10/02/2022.
//

import SwiftUI
var appToolbarIconSize = CGFloat(20)

class NXSearchbarModel : ObservableObject{
    @Published var searchText = "" {
        didSet{
            //print("searchText",searchText)
            //globalToolbarListener?.onFilterCameras(filter: searchText)
        }
    }
}
struct NXSearchbar : View{
    @ObservedObject var model = NXSearchbarModel()
    
    var body: some View {
        ZStack(alignment: .topTrailing){
            TextField("Filter list", text: $model.searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Button(action: {
                model.searchText = String()
            }){
                Image(systemName: "xmark.circle").resizable().opacity(0.5)
                    .frame(width:appToolbarIconSize,height: appToolbarIconSize)
            }.buttonStyle(PlainButtonStyle()).padding(.top,8)
        }//
    }
}
struct NxvProAppToolbar :  View{
    var iconSize = appToolbarIconSize
    var searchBar = NXSearchbar()
    
    var body: some View {
        HStack(spacing: 15){
            Button(action: {
              //showImportSheet = true
          }){
              Image(systemName: "plus.app")
                  .resizable()
                  //.foregroundColor(Color.accentColor)
                  .frame(width: iconSize, height: iconSize)
          }.buttonStyle(PlainButtonStyle()).padding(.leading,2)
            
            searchBar
        
            Button(action: {
                //show refresh alert
                // Button(action: {
                //show refresh alert
                //globalToolbarListener?.resetDiscovery()
                //AppDelegate.Instance.showRefreshAlert()
            }){
                Image(systemName: "arrow.triangle.2.circlepath")
                    .resizable()
                    //.foregroundColor(Color.accentColor)
                    .frame(width: iconSize + 4, height: iconSize)
                
            }.buttonStyle(PlainButtonStyle())
            
            Button(action: {
                //show / hide multicams
                //globalToolbarListener?.toggleMulticamView()
            }){
            Image(systemName: "play")//model.isMulticamActive ? "play.slash" : "play")
                    .resizable()
                    
                    .frame(width: iconSize, height: iconSize)
                
            }.buttonStyle(PlainButtonStyle()).padding(.trailing,2)
        }.padding(.bottom)
    }
}

class NxvProCamerasModel : ObservableObject{
    @Published var selectedCamera: Camera?
    var listener: CameraEventListener?
}

struct NxvProCamerasView: View {
    
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var iconModel = AppIconModel()
    
    @ObservedObject var cameras: DiscoveredCameras
    @ObservedObject var model = NxvProCamerasModel()
    
   
    
    init(cameras: DiscoveredCameras){
        self.cameras = cameras
    }
    func setListener(listener: CameraEventListener){
        model.listener = listener
    }
    var body: some View {
        VStack{
            List{
                if cameras.cameras.count == 0{
                    Text("No cameras found").appFont(.caption)
                }else{
                    ForEach(cameras.cameras, id: \.self) { cam in
                        DiscoCameraViewFactory.getInstance(camera: cam).onTapGesture {
                            model.selectedCamera = cam
                            
                            model.listener?.onCameraSelected(camera: cam, isMulticamView: false)
                            
                        }.background(model.selectedCamera == cam ? Color(iconModel.selectedRowColor) : Color(UIColor.clear)).padding(0)
                    }
                }
            }.listStyle(PlainListStyle()).padding(0)
            Spacer()
            NxvProAppToolbar().padding(.leading)
        }.onAppear {
            iconModel.initIcons(isDark: colorScheme == .dark)
        }
    }
}


