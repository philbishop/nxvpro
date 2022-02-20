//
//  ImportSettingsSheet.swift
//  nxvpro
//
//  Created by Philip Bishop on 19/02/2022.
//

import SwiftUI

class ImportSettingsModel: ObservableObject, NxvZeroConfigResultsListener{
    @Published var status: String = ""
    @Published var statusColor: Color = Color(UIColor.label)
    @Published var addStatusColor: Color = Color(UIColor.label)
    @Published var mapSyncDisabled = true
    
    let errorColor = Color(UIColor.systemRed)
    let okColor = Color(UIColor.label)
    let accentColor = Color(UIColor.systemBlue)
    
    init(){
       
    }
   
    private func showError(msg: String,lineNum: Int,importedCount: Int){
        status = msg + " at line " + String(lineNum) + " imported " + String(importedCount)
    }
    
    func handleResult(strData: String) {
        
        var camLocs = [CameraLocation]()
        
        let lines = strData.components(separatedBy: "\n")
        for line in lines{
            if line == "request.map"{
                continue
            }
            if line.isEmpty{
                continue
            }
            let loc = line.components(separatedBy: " ")
            if loc.count > 3{
                let cl = CameraLocation()
                cl.camUid = loc[0]
                if let beam = Double(loc[1]){
                    cl.beam = beam
                    if let lat = Double(loc[2]){
                        if let lng = Double(loc[3]){
                            cl.lat = lat
                            cl.lng = lng
                            camLocs.append(cl)
                        }
                    }
                }
            }
        }
        
        status = "Number of locations imported is " + String(camLocs.count)
        
        globalCameraEventListener?.onLocationsImported(cameraLocs: camLocs)
       
    }
    
    //MARK: Sync
    func doMapSync(){
        status = "Syncing with service...";
        DispatchQueue.main.async{
            syncService.mapSync(handler: self)
        }
    }
    
}

struct ImportSettingsSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @State var showFilePicker = false
    
    @ObservedObject var model = ImportSettingsModel()
    @State var filePicker =  DocumentPicker()
    
    
    
    var body: some View {
        List{
            
            HStack{
                Text("Sync settings").appFont(.title)
                    .padding()
                
                Spacer()
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                })
                {
                    Image(systemName: "xmark").resizable()
                        .frame(width: 18,height: 18)
                }
            }
            Section(header: Text("Options").appFont(.sectionHeader)){
                
                Button(action: {
                    model.doMapSync()
                }){
                    HStack{
                        
                        Image(systemName: "globe").resizable()
                            .frame(width: 18,height: 18)
                        
                        Text("Import camera locations").appFont(.body)
                    }
                }.disabled(model.mapSyncDisabled)
                .foregroundColor(Color.accentColor).appFont(.body)
                    
            }
            
            Section(header: Text("Status").appFont(.sectionHeader)){
                Text(model.status).fontWeight(.light).appFont(.caption)
            }
        }.onAppear{
            if let zs = syncService.currentSession{
                let sd = zs.service.debugDescription
                model.status = "Sync service: " + sd
                model.mapSyncDisabled = false
            }else{
                model.status = "Sync service not found"
                model.mapSyncDisabled = true
            }
        }
    
    }
}

struct ImportSettingsSheet_Previews: PreviewProvider {
    static var previews: some View {
        ImportSettingsSheet()
    }
}
