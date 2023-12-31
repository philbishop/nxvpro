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
            //AppLog.write("searchText",searchText)
            cameraFilterListener?.onFilterCameras(filter: searchText)
            
        }
    }
}
struct NXSearchbar : View{
    @ObservedObject var model = NXSearchbarModel()
    
    var body: some View {
        ZStack(alignment: .center){
            HStack{
            
           
                TextField("Filter", text: $model.searchText, onEditingChanged: { (editingChanged) in
                    
                    globalCameraEventListener?.onSearchFocusChanged(focused: editingChanged)
                })
                    .keyboardType(.namePhonePad)
                
                Spacer()
                Image(systemName: "xmark.circle").resizable().opacity(0.5).onTapGesture {
                    DispatchQueue.main.async {
                        model.searchText = String()
                        AppLog.write("Cleared filter text")
                    }
                }.frame(width:appToolbarIconSize,height: appToolbarIconSize)
            }.padding(.leading,5)
        }.padding(2)
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
    @Published var moveEnabled = false
    
    @Published var showEenSettings = false
    var listener: NxvProAppToolbarListener?
}

struct NxvProAppToolbar :  View{
    
    @ObservedObject var model = NxvProAppToolbarModel()
    
    var iconSize = appToolbarIconSize
    var searchBar = NXSearchbar()
   
    
    init(addEnabled: Bool = true){
        model.addEnabled = addEnabled
        debugPrint("NxvProAppToolbar:init")
    }

    func setLocalListener(listener: NxvProAppToolbarListener){
        model.listener = listener
    }
    func setMoveEnabled(_ enabled: Bool){
        DispatchQueue.main.async{
            model.moveEnabled = enabled
        }
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
    
    func setPlayAndOrderEnabled(_ enable: Bool){
        model.playEnabled = enable
        model.moveEnabled = enable
    }
    
    var body: some View {
        HStack(spacing: 15){
            Button(action: {
                globalCameraEventListener?.onShowAddCamera(mode: .none)
          }){
              Image(systemName: "plus.app")
                  .resizable()
                  //.foregroundColor(Color.accentColor)
                  .frame(width: iconSize, height: iconSize)
          }.buttonStyle(PlainButtonStyle()).padding(.leading,5)
                .disabled(model.addEnabled==false)
           
            //searchBar
            Spacer()
           
            Button(action: {
                globalCameraEventListener?.resetDiscovery()
                
            }){
                Image(systemName: "arrow.triangle.2.circlepath")
                    .resizable()
                    .opacity(model.refreshEnabled ? 1.0 : 0.6)
                    .frame(width: iconSize + 4, height: iconSize)
                
            }.buttonStyle(PlainButtonStyle())
                .disabled(model.refreshEnabled==false)
        
            Spacer()
            
            Button(action:{
                model.listener?.toggleMoveMode()
                
            }){
                Image(systemName: "arrow.up.arrow.down").resizable()
                    .opacity(model.moveEnabled ? 1.0 : 0.6)
                    .frame(width: iconSize,height: iconSize)
            }.buttonStyle(PlainButtonStyle())
                .disabled(model.moveEnabled==false)
        
            Spacer()
            
            Button(action: {
                //show / hide multicams
                DispatchQueue.main.async{
                    globalCameraEventListener?.onShowMulticams()
                }
            }){
            Image(systemName: model.isMulticamActive ? "play.slash" : "play")
                    .resizable()
                    .opacity(model.playEnabled ? 1.0 : 0.6)
                    .frame(width: iconSize, height: iconSize)
                
            }.buttonStyle(PlainButtonStyle()).padding(.trailing,5)
                .disabled(model.playEnabled==false)
        }.padding(5)
            .background(Color(uiColor: UIColor.systemBackground))
    }
}
