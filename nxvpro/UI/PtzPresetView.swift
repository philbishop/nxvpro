//
//  PtzPresetView.swift
//  NXV-IOS
//
//  Created by Philip Bishop on 02/01/2022.
//

//
//  PtzPresetView.swift
//  NX-V
//
//  Created by Philip Bishop on 02/01/2022.
//

import SwiftUI

protocol PtzPresetEventListener{
    func cancelCreatePreset()
    func togglePtzPresets()
    func hidePtzPresets()
    func gotoPtzPreset(camera: Camera,presetToken: String)
    func deletePtzPreset(camera: Camera,presetToken: String)
    func createPtzPreset(camera: Camera, presetName: String)
    func createPtzPresetWithCallback(camera: Camera, presetName: String,callback: @escaping (Camera,String,Bool)->Void)
}

class PtzPresetModel : ObservableObject{
    @Published var presets = [PtzPreset]()
    @Published var camera: Camera?
    @Published var selectedPreset: PtzPreset?
    @Published var error = ""
    @Published var showCreateSheet = false
    
    var listener: PtzPresetEventListener?
    
    var nextId = -1;
    
    func removePreset(){
        if let presetToRemove = selectedPreset{
            var pi = -1
            for i in 0...presets.count-1{
                if presets[i].token == presetToRemove.token{
                    pi = i
                    break
                }
            }
            
            if pi != -1{
                presets.remove(at: pi)
                selectedPreset = nil
            }
            
            pi = -1
            for i in 0...camera!.ptzPresets!.count-1{
                let ps = camera!.ptzPresets![i]
                if ps.name == presetToRemove.name{
                    pi = i
                    
                }
            }
            if pi != -1{
                camera!.ptzPresets!.remove(at: pi)
            }
        }
    }
    func createName() -> String{
        if nextId == -1{
            nextId = presets.count
        }
        
        return "Preset " + String(nextId)
    }
}

struct PtzPresetView : View{
    
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var model = PtzPresetModel()
    @ObservedObject var iconModel = AppIconModel()
    
    @State var bookmarkName = ""
    
    @State var gotoEnabled =  false
    @State var bookmakeEnabled = false
    @State var iconSize = CGFloat(16)
    @State var showDeleteAlert = false
    
    
    var createSheet = PtzCreatePresetSheet()
    
    func cancel() {
        model.showCreateSheet = false
    }
    func reset(){
        model.presets.removeAll()
    }
    func setCamera(camera: Camera,listener: PtzPresetEventListener){
        createSheet.setCamera(camera: camera, listener: listener)
        model.camera = camera
        model.presets.removeAll()
        model.selectedPreset = nil
        
        if let presets = camera.ptzPresets{
            for preset in presets{
                model.presets.append(preset)
            }
        }
    }
    func gotoComplete(ok: Bool,error: String){
        print("PtzPresetView:gotoComplete",ok,error)
        gotoEnabled = true
        if !ok{
            model.error = error
        }
    }
    func createComplete(ok: Bool,error: String){
        print("PtzPresetView:CreateComplete",ok,error)
        if !ok{
            model.error = error
        }
    }
    func deleteComplete(ok: Bool,error: String){
        print("PtzPresetView:deleteComplete",ok,error)
        if ok{
            model.removePreset()
        }else{
            model.error = error
        }
        
    }
    
    func gotoPreset(){
        gotoEnabled = false
        model.error = ""
        model.listener?.gotoPtzPreset(camera: model.camera!, presetToken: model.selectedPreset!.token)
        
    }
    
    var body: some View {
        ZStack(alignment: .top){
            Color(UIColor.secondarySystemBackground)
            VStack(alignment: .leading,spacing: 0){
                //Presets
                Text("PTZ Presets").fontWeight(.semibold).appFont(.titleBar)
                
                List{
                    ForEach(model.presets, id: \.self) { preset in
                        Text(preset.name).appFont(.caption).onTapGesture{
                            model.selectedPreset = preset
                            gotoPreset()
                            print("PtzPreset tap",preset.token,preset.name)
                        }.onLongPressGesture(perform: {
                            model.selectedPreset = preset
                        })
                        .listRowBackground(model.selectedPreset == preset ? Color(iconModel.selectedRowColor) : Color(UIColor.clear)).padding(0)
                    }
                }.listStyle(PlainListStyle())
                
                //Text(model.error).appFont(.caption).foregroundColor(.red)
                Spacer()
                HStack(){
                
                    Button(action:{
                        createSheet.setCamera(camera: model.camera!, listener: model.listener)
                        model.showCreateSheet = true
                    }){
                        Text("New").appFont(.caption)
                    }.buttonStyle(PlainButtonStyle())
                        .sheet(isPresented: $model.showCreateSheet){
                            createSheet
                        }
                    
                    Spacer()
                    Button(action: {
                        showDeleteAlert = true
                    }){
                        Text("Delete").appFont(.caption)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(model.selectedPreset == nil)
                    .alert(isPresented: $showDeleteAlert) {
                        
                        Alert(title: Text("Delete"), message: Text("Delete preset " + model.selectedPreset!.name),
                              primaryButton: .default (Text("Delete")) {
                                showDeleteAlert = false
                                gotoEnabled = false
                                model.error = ""
                            model.listener?.deletePtzPreset(camera: model.camera!, presetToken: model.selectedPreset!.token)
                              },
                              secondaryButton: .cancel() {
                                showDeleteAlert = false
                              }
                        )
                    }
                    Spacer()
                    Button(action:{
                        model.listener?.hidePtzPresets()
                    }){
                        Text("Close").appFont(.caption)
                    }
                    
                }
            }.padding()
        }.cornerRadius(15).frame(width: 190,height: 360).padding(10)
            .onAppear(){
                iconModel.initIcons(isDark: colorScheme == .dark)
        }
    }
}

