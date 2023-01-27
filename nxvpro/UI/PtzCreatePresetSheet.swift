//
//  PtzCreatePresetSheet.swift
//  NXV-IOS
//
//  Created by Philip Bishop on 03/01/2022.
//

import SwiftUI

class PtzCreatePresetModel : ObservableObject{
    @Published var camera: Camera?
    @Published var hint = "Create preset at current position"
    //@Published var defaultStatus = ""
    @Published var createStatus = ""
    
    @Published var statusColor = Color.accentColor
    @Published var loginDisabled = true
    
    var listener: PtzPresetEventListener?
    
    let defaultStatus = "Enter name"
    
    init(){
        
    }
}

struct PtzCreatePresetSheet : View{
    
    @ObservedObject var model = PtzCreatePresetModel()
    @State var presetName = ""
    @State var ifr = true
    @State var placeHolder = "Name"
    
    func setCamera(camera: Camera,listener: PtzPresetEventListener?){
        model.listener = listener
        model.camera = camera
        model.statusColor = Color.accentColor
        model.createStatus =  ""
        model.loginDisabled = true
    }
    
    var body: some View {
        List(){
            VStack (alignment: .leading){
                HStack{
                    VStack{
                        Text("New Preset").appFont(.title)
                            .padding()
                    }
                    Spacer()
                    Button(action: {
                        //presentationMode.wrappedValue.dismiss()
                        model.listener?.cancelCreatePreset()
                    })
                    {
                        Image(systemName: "xmark").resizable()
                            .frame(width: 18,height: 18).padding()
                    }.foregroundColor(Color.accentColor)
                }
                //Text(model.hint).fontWeight(.light).appFont(.caption)
            }
            Section(header: Text("Details").appFont(.sectionHeader)){
                /*
                LegacyTextField(placeholder: $placeHolder,text: $presetName,isFirstResponder: $ifr).autocapitalization(.none).appFont(.titleBar)
                    .autocapitalization(.none)
                    .background(Color(UIColor.systemBackground))
                */
                TextField(placeHolder,text: $presetName, onEditingChanged: {
                    AppLog.write("typing",$0)
                    model.loginDisabled = presetName.count > 0
                }, onCommit: {
                    
                })
                
                HStack{
                    Text(model.createStatus).foregroundColor(.red).appFont(.caption)
                    Spacer()
                    Text("Create").foregroundColor(Color.accentColor).appFont(.body)
                        .disabled(model.loginDisabled).onTapGesture {
                            createPreset()
                        }
                }//.padding()
                
                
            }
            Section(header: Text("WARNING").appFont(.sectionHeader)){
                Text("Some cameras will allow you to create presets but they don't actually save or work")
                    .appFont(.body).frame(height: 48)
            }
        }
    }
    func handleCreateResponse(camera: Camera,error: String,ok: Bool){
        model.createStatus = error
        if ok{
            model.listener?.cancelCreatePreset()
        }
    }
    func createPreset(){
        let trimmed = presetName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count<2{
            model.createStatus = " Name too short"
            return
        }
        
        model.createStatus = "Creating...."
        model.listener?.createPtzPresetWithCallback(camera: model.camera!, presetName: trimmed, callback: handleCreateResponse)
    }
}
