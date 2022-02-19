//
//  ImportSettingsSheet.swift
//  nxvpro
//
//  Created by Philip Bishop on 19/02/2022.
//

import SwiftUI

class ImportSettingsModel: ObservableObject, DocumentPickerListener{
    @Published var status: String = "No file selected"
    @Published var statusColor: Color = Color(UIColor.label)
    @Published var addStatusColor: Color = Color(UIColor.label)
    
    let errorColor = Color(UIColor.systemRed)
    let okColor = Color(UIColor.label)
    let accentColor = Color(UIColor.systemBlue)
    
    init(){
        documentPickerLister = self
    }
    
    func onDocumentOpened(fileContents: String) -> Bool {
        print("ImportCamerasSheet:onDocumentOpened")
        status = "Processing file..."
        statusColor = accentColor
        
        //parse the files
        return parseConfig(config: fileContents)
    }
    func onError(error: String) {
        status = "Unable to open file"
        statusColor = Color(UIColor.systemRed)
        print("ImportCamerasSheet:OnError")
    }
    private func showError(msg: String,lineNum: Int,importedCount: Int){
        status = msg + " at line " + String(lineNum) + " imported " + String(importedCount)
    }
    private func parseConfig(config: String) -> Bool{
     
        var camLocs = [CameraLocation]()
        
        let lines = config.components(separatedBy: "\n")
        for line in lines{
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
        
        return camLocs.count > 0
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
                Text("Import map settings").appFont(.title)
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
            Section(header: Text("Settings file").appFont(.sectionHeader)){
                //Text("Tap the files button and then select your camera config text file")
                
                Button(action: {
                    showFilePicker = true
                }){
                    HStack{
                        
                        Image(systemName: "doc.text").resizable()
                            .frame(width: 18,height: 18)
                        
                        Text("Select configuration file").appFont(.body)
                    }
                }.foregroundColor(Color.accentColor).appFont(.body)
                    .sheet(isPresented: $showFilePicker, content: {
                    filePicker
                })
            }
            
            Section(header: Text("Status").appFont(.sectionHeader)){
                Text(model.status).fontWeight(.light).appFont(.caption)
            }
        }
    
    }
}

struct ImportSettingsSheet_Previews: PreviewProvider {
    static var previews: some View {
        ImportSettingsSheet()
    }
}
