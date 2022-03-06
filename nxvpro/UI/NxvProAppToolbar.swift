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
        ZStack(alignment: .center){
            HStack{
            
           
                TextField("Filter camera list", text: $model.searchText)
                    .keyboardType(.namePhonePad)
                /*
                Button(action: {
                    DispatchQueue.main.async {
                        model.searchText = String()
                        print("Cleared filter text")
                    }
                    
                   // UIApplication.shared.endEditing()
                }){
                    Image(systemName: "xmark.circle").resizable().opacity(0.8)
                        .frame(width:appToolbarIconSize,height: appToolbarIconSize)
                    
                }.buttonStyle(PlainButtonStyle()).padding(.top,8)
                 */
                Spacer()
                Image(systemName: "xmark.circle").resizable().opacity(0.5).onTapGesture {
                    DispatchQueue.main.async {
                        model.searchText = String()
                        print("Cleared filter text")
                    }
                }.frame(width:appToolbarIconSize,height: appToolbarIconSize)
            }
        }.padding(5)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(UIColor.label), lineWidth: 0.5).opacity(0.75)
        )
    }
}
protocol NxvProAppToolbarListener{
    func toggleMoveMode()
}
class NxvProAppToolbarModel : ObservableObject{
    @Published var playEnabled = false
    @Published var refreshEnabled = false
    @Published var addEnabled = true
    @Published var isMulticamActive = false
    var listener: NxvProAppToolbarListener?
}

struct NxvProAppToolbar :  View{
    
    @ObservedObject var model = NxvProAppToolbarModel()
    
    var iconSize = appToolbarIconSize
    var searchBar = NXSearchbar()

    init(addEnabled: Bool = true){
        model.addEnabled = addEnabled
    }

    func setLocalListener(listener: NxvProAppToolbarListener){
        model.listener = listener
    }
    
    func enableRefresh(enable: Bool){
        model.refreshEnabled = enable
    }
    
    func enableMulticams(enable: Bool){
        model.playEnabled = enable
    }
    func setMulticamActive(active: Bool){
        
        model.isMulticamActive = active
        
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
            
            //searchBar
            Spacer()
           
            Button(action: {
                globalCameraEventListener?.resetDiscovery()
                
            }){
                Image(systemName: "arrow.triangle.2.circlepath")
                    .resizable()
                    //.foregroundColor(Color.accentColor)
                    .frame(width: iconSize + 4, height: iconSize)
                
            }.buttonStyle(PlainButtonStyle())
                .disabled(model.refreshEnabled==false)
        
            Spacer()
            
            Button(action:{
                model.listener?.toggleMoveMode()
                
            }){
                Image(systemName: "arrow.up.arrow.down").resizable()
                    .frame(width: iconSize,height: iconSize)
            }.buttonStyle(PlainButtonStyle())
        
            Spacer()
            
            Button(action: {
                //show / hide multicams
                globalCameraEventListener?.onShowMulticams()
            }){
            Image(systemName: model.isMulticamActive ? "play.slash" : "play")
                    .resizable()
                    
                    .frame(width: iconSize, height: iconSize)
                
            }.buttonStyle(PlainButtonStyle()).padding(.trailing,2)
                .disabled(model.playEnabled==false)
        }.padding(.bottom)
    }
}
