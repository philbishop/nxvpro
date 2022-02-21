//
//  ImportSettingsSheet.swift
//  nxvpro
//
//  Created by Philip Bishop on 19/02/2022.
//

import SwiftUI

class WanImportHandler{
    func parseConfig(config: String,overwriteExisting: Bool) -> String{
        let template = getWanTemplate()
        
        let tmpCamera = Camera(id: 0)
        
        var lineNum = 0
        var importCounted = 0
        let lines = config.components(separatedBy: .newlines)
        for ln in lines{
            if ln.hasPrefix("request.wan"){
                continue
            }
            lineNum += 1
            if ln.isEmpty || ln.hasPrefix("#"){
                continue
            }
            let parts = ln.components(separatedBy: "|")
            if parts.count < 4{
                return "Invalid format in line " + String(lineNum)
    
            }
            
            var ipa = parts[0];
            let ipap = ipa.components(separatedBy: ":")
            if ipap.count != 2 || ipap[0].isValidIpAddressOrHost == false{
                return "Invalid addressin line " + String(lineNum)
                
            }
            let ipp = ipa.components(separatedBy: ":")
            if ipp.count != 2{
                 return "Missing port in " + ipa + " in line " + String(lineNum)
            }
            let user = parts[1]
            let pass = parts[2]
            let camName = parts[3];
            let xAddr = "http://" + ipa + "/onvif/device_service";
            
            var discoTemplate = template.replacingOccurrences(of: "_XADDR_",with: xAddr);
            discoTemplate = discoTemplate.replacingOccurrences(of: "_CAM_NAME_",with: camName);
            
            
            tmpCamera.xAddr = xAddr
            let discoXmlFile = tmpCamera.getBaseFileName() + "_disco.xml"
            let discoXmlFilePath = FileHelper.getStorageRoot().appendingPathComponent(discoXmlFile)
            
            var newCam = Camera(id: 0)
            newCam.xAddr = xAddr
            newCam.name = camName
            newCam.user = user
            newCam.password = pass
            
            do {
                if FileManager.default.fileExists(atPath: discoXmlFilePath.path) == false{
                    
                    try discoTemplate.write(to: discoXmlFilePath, atomically: true, encoding: String.Encoding.utf8)
                    print("Saved import XML file",discoXmlFile)
                    
                    importCounted = importCounted + 1
                    
                    if pass.isEmpty == false{
                        //create json file
                        
                        newCam.save()
                    }
                    
                }else{
                    print("Camera exists",xAddr)
                    //check if json exists if not create creds or update creds
                    if overwriteExisting || !newCam.loadCredentials(){
                        newCam.save()
                        importCounted = importCounted + 1
                        
                    }
                }
            } catch {
                // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
                 return "FAILED TO SAVE IMPORT"
            }
            
        }
        if importCounted > 0{
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0,execute: {
                globalCameraEventListener?.onWanImportComplete()
            })
        }
        return "Number of settings imported " + String(importCounted)
    }
    private func getWanTemplate() -> String{
        let fileName = "wan_disco_template"
        if let filepath = Bundle.main.path(forResource: fileName, ofType: "xml") {
            do {
                let contents = try String(contentsOfFile: filepath)
                return contents
            } catch {
                print("Failed to load XML from bundle",fileName)
            }
        }
        return ""
    }
}

class ImportSettingsModel: ObservableObject, NxvZeroConfigResultsListener{
    @Published var status: String = ""
    @Published var statusColor: Color = Color(UIColor.label)
    @Published var addStatusColor: Color = Color(UIColor.label)
    @Published var mapSyncDisabled = true
    
    @Published var services = [NetworkServiceWrapper]()
    @Published var selectedUuid = UUID()//no match as default
    @Published var overwriteExisting = false
    
    
    let errorColor = Color(UIColor.systemRed)
    let okColor = Color(UIColor.label)
    let accentColor = Color(UIColor.systemBlue)
    
    init(){
       
    }
   
    func refreshServices(){
        services.removeAll()
        for service in syncService.resolvedDevices{
            services.append(NetworkServiceWrapper(service: service))
        }
        mapSyncDisabled = true
        status = "Number of services found: " + String(services.count)
    }
    
    private func showError(msg: String,lineNum: Int,importedCount: Int){
        status = msg + " at line " + String(lineNum) + " imported " + String(importedCount)
    }
    
    func handleResult(strData: String) {
        if strData.hasPrefix("request.map"){
            handleMapImport(strData: strData)
        }else if strData.hasPrefix("request.wan"){
            let wanHandler = WanImportHandler()
            status = wanHandler.parseConfig(config: strData,overwriteExisting: overwriteExisting)
        }
    }
    private func handlWammport(strData: String){
    
    }
    private func handleMapImport(strData: String){
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
        
        globalCameraEventListener?.onLocationsImported(cameraLocs: camLocs,overwriteExisting: overwriteExisting)
       
    }
    
    //MARK: Sync
    private func getSelectedNetService() -> NetService?{
        for service in services{
            if service.id == selectedUuid{
                return service.service
            }
        }
        return nil
    }
    func doMapSync(){
        if let service = getSelectedNetService(){
            status = "Syncing with service...";
            DispatchQueue.main.async{
                syncService.mapSync(service:service, handler: self)
            }
        }else{
            status = "Service not available"
        }
    }
    func doWanSync(){
        status = "Syncing with service...";
        DispatchQueue.main.async{
            //syncService.wanSync(handler: self)
        }
    }
    
}

struct ImportSettingsSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var iconModel = AppIconModel()
    
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
                
                Button(action: {
                    model.doWanSync()
                }){
                    HStack{
                        
                        Image(systemName: "camera.aperture").resizable()
                            .frame(width: 18,height: 18)
                        
                        Text("Import cameras").appFont(.body)
                    }
                }.disabled(model.mapSyncDisabled)
                .foregroundColor(Color.accentColor).appFont(.body)
            
                Toggle("Overwrite existing",isOn: $model.overwriteExisting)
            }
            
            Section(header: Text("NX-V devices").appFont(.sectionHeader)){
                Text(model.status).fontWeight(.light).appFont(.caption)
                VStack{
                    ForEach(model.services, id: \.self) { service in
                        HStack{
                            Image(iconModel.nxvTitleIcon).resizable().frame(width: 16,height: 16)
                            Text(service.displayStr()).appFont(.caption)
                            Spacer()
                        }.padding()
                        .background(model.selectedUuid == service.id ? Color(iconModel.selectedRowColor) : Color(UIColor.clear))
                        .onTapGesture {
                            model.mapSyncDisabled = false
                            model.selectedUuid = service.id
                        }
                            
                    }
                }.listStyle(PlainListStyle())
            }
        }.onAppear{
            iconModel.initIcons(isDark: colorScheme == .dark)
            model.refreshServices()
           
            /*
            if let zs = syncService.currentSession{
                let sd = zs.service.debugDescription
                model.status = "Sync service: " + sd
                model.mapSyncDisabled = false
            }else{
                model.status = "Sync service not found"
                model.mapSyncDisabled = true
            }
             */
        }
    
    }
}

struct ImportSettingsSheet_Previews: PreviewProvider {
    static var previews: some View {
        ImportSettingsSheet()
    }
}
