//
//  NxvProAppToolbar.swift
//  nxvpro
//
//  Created by Philip Bishop on 12/02/2022.
//

import SwiftUI

var appToolbarIconSize = CGFloat(20)

protocol CameraFilterChangeListener{
    func onFilterCameras(filter: String)
}

var cameraFilterListener: CameraFilterChangeListener?

class NXSearchbarModel : ObservableObject{
    
    @Published var searchText = "" {
        didSet{
            //print("searchText",searchText)
            cameraFilterListener?.onFilterCameras(filter: searchText)
        
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
                UIApplication.shared.endEditing()
            }){
                Image(systemName: "xmark.circle").resizable().opacity(0.5)
                    .frame(width:appToolbarIconSize,height: appToolbarIconSize)
            }.buttonStyle(PlainButtonStyle()).padding(.top,8)
        }//
    }
}
class NxvProAppToolbarModel : ObservableObject{
    @Published var playEnabled = false
    @Published var refreshEnabled = false
    @Published var addEnabled = true
}

struct NxvProAppToolbar :  View{
    
    @ObservedObject var model = NxvProAppToolbarModel()
    
    var iconSize = appToolbarIconSize
    var searchBar = NXSearchbar()

    init(addEnabled: Bool = true){
        model.addEnabled = addEnabled
    }
    
    func enableRefresh(enable: Bool){
        model.refreshEnabled = enable
    }
    
    func enableMulticams(enable: Bool){
        model.playEnabled = enable
    }
    
    var body: some View {
        HStack(spacing: 15){
            Button(action: {
                globalCameraEventListener?.onShowAddCamera()
          }){
              Image(systemName: "plus.app")
                  .resizable()
                  //.foregroundColor(Color.accentColor)
                  .frame(width: iconSize, height: iconSize)
          }.buttonStyle(PlainButtonStyle()).padding(.leading,2)
                .disabled(model.addEnabled==false)
            
            searchBar
        
            Button(action: {
                globalCameraEventListener?.resetDiscovery()
                
            }){
                Image(systemName: "arrow.triangle.2.circlepath")
                    .resizable()
                    //.foregroundColor(Color.accentColor)
                    .frame(width: iconSize + 4, height: iconSize)
                
            }.buttonStyle(PlainButtonStyle())
                .disabled(model.refreshEnabled==false)
            
            Button(action: {
                //show / hide multicams
                globalCameraEventListener?.onShowMulticams()
            }){
            Image(systemName: "play")//model.isMulticamActive ? "play.slash" : "play")
                    .resizable()
                    
                    .frame(width: iconSize, height: iconSize)
                
            }.buttonStyle(PlainButtonStyle()).padding(.trailing,2)
                .disabled(model.playEnabled==false)
        }.padding(.bottom)
    }
}
