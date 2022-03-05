//
//  ImportSettingsSheet.swift
//  nxvpro
//
//  Created by Philip Bishop on 19/02/2022.
//

import SwiftUI

class WanImportHandler{
    var importCounted = 0
    func parseConfig(config: String,overwriteExisting: Bool) -> String{
        let template = getWanTemplate()
        
        let tmpCamera = Camera(id: 0)
        
        var lineNum = 0
        importCounted = 0
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
            //assume authenticated for first unicast
            if pass.isEmpty == false{
                newCam.authenticated = true
                newCam.profileIndex = 0
            }
            do {
                let discoExists = FileManager.default.fileExists(atPath: discoXmlFilePath.path)
                
                if discoExists == false{
                    
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
    
    //@Published var services = [NetworkServiceWrapper]()
    @Published var selectedUuid = UUID()//no match as default
    @Published var overwriteExisting = false
    
    @Published var isDirty = false
    
    let errorColor = Color(UIColor.systemRed)
    let okColor = Color(UIColor.label)
    let accentColor = Color(UIColor.systemBlue)
    
    init(){
       
    }
   /*
    func refreshServices(){
        services.removeAll()
        for service in syncService.resolvedDevices{
            services.append(NetworkServiceWrapper(service: service))
        }
        mapSyncDisabled = true
        status = "Number of services found: " + String(services.count)
    }
    */
    
    private func showError(msg: String,lineNum: Int,importedCount: Int){
        status = msg + " at line " + String(lineNum) + " imported " + String(importedCount)
    }
    
    func handleResult(strData: String) {
        if strData.hasPrefix("request.map"){
            handleMapImport(strData: strData)
        }else if strData.hasPrefix("request.wan"){
            let wanHandler = WanImportHandler()
            status = wanHandler.parseConfig(config: strData,overwriteExisting: overwriteExisting)
            if !isDirty{
                isDirty = wanHandler.importCounted > 0
            }
        }else if strData.hasPrefix("request.groups"){
            handlGroupImport(strData: strData)
        }else if strData.hasPrefix("request.storage"){
            handleStorageImport(strData: strData)
        }
    }
    private func handleStorageImport(strData: String){
        var importCount = 0
        
        let lines = strData.components(separatedBy: "\n")
        for line in lines{
            if line == "request.storage"{
                continue
            }
            if line.isEmpty{
                continue
            }
            let parts = line.components(separatedBy: "|")
            if parts.count == 2{
                let sfn = parts[0]
                let json = parts[1]
                let sfPath = FileHelper.getPathForFilename(name: sfn)
                do{
                    try json.write(toFile: sfPath.path, atomically: true, encoding: .utf8)
                    importCount += 1
                }catch{
                    print("Sync import failed to save " + sfn)
                }
            }
        }
        status = "Number of storage settings imported is " + String(importCount)
    }
    private func handlGroupImport(strData: String){
        var importCount = 0
        
        let lines = strData.components(separatedBy: "\n")
        for line in lines{
            if line == "request.groups"{
                continue
            }
            if line.isEmpty{
                continue
            }
            //each line is json
            do{
                let group = try JSONDecoder().decode(CameraGroup.self, from: line.data(using: .utf8)!)
                let jfn = String(group.id) + "_grp.json"
                let jpath = FileHelper.getStorageRoot().appendingPathComponent(jfn)
                let exists = FileManager.default.fileExists(atPath: jpath.path)
                if !exists || overwriteExisting{
                    group.save()
                    importCount += 1
                }
            }catch{
                print("Unable to parse group json")
            }
        }
        status = "Number of groups imported is " + String(importCount)
        
        //only change if unset
        if !isDirty{
            //isDirty = importCount > 0
        }
        
        globalCameraEventListener?.onGroupStateChanged(reload: true)
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
        //only change if unset
        if !isDirty{
        //don't need full refresh
            //isDirty = camLocs.count > 0
        }
        status = "Number of locations imported is " + String(camLocs.count)
        
        globalCameraEventListener?.onLocationsImported(cameraLocs: camLocs,overwriteExisting: overwriteExisting)
       
    }
    
    //MARK: Sync
    private func getSelectedNetService() -> NetService?{
        for service in syncService.services{
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
        if let service = getSelectedNetService(){
            status = "Syncing with service...";
            DispatchQueue.main.async{
                syncService.wanSync(service: service, handler: self)
            }
        }else{
            status = "Service not available"
        }
    }
    func doGroupsSync(){
        if let service = getSelectedNetService(){
            status = "Syncing with service...";
            DispatchQueue.main.async{
                syncService.groupsSync(service: service, handler: self)
            }
        }else{
            status = "Service not available"
        }
    }
    func doStorageSync(){
        if let service = getSelectedNetService(){
            status = "Syncing with service...";
            DispatchQueue.main.async{
                syncService.storageSync(service: service, handler: self)
            }
        }else{
            status = "Service not available"
        }
    }
}

struct ImportSettingsSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var iconModel = AppIconModel()
    
    @ObservedObject var model = ImportSettingsModel()
    @ObservedObject var zeroConfig = syncService
    @State var filePicker =  DocumentPicker()
    
    
    
    var body: some View {
        List{
            
            HStack{
                Text("Sync settings").appFont(.title)
                    .padding()
                
                Spacer()
                Button(action: {
                    //force refresh of disco cameras ui
                    if model.isDirty{
                        globalCameraEventListener?.refreshCameras()
                    }
                    presentationMode.wrappedValue.dismiss()
                    
                })
                {
                    Image(systemName: "xmark").resizable()
                        .frame(width: 18,height: 18)
                }
            }
            Section(header: Text("Options").appFont(.sectionHeader)){
               
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
            
                Button(action: {
                    model.doGroupsSync()
                }){
                    HStack{
                        
                        Image(systemName: "rectangle.3.group").resizable()
                            .frame(width: 18,height: 18)
                        
                        Text("Import groups").appFont(.body)
                    }
                }.disabled(model.mapSyncDisabled)
                .foregroundColor(Color.accentColor).appFont(.body)
                
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
                    model.doStorageSync()
                }){
                    HStack{
                        
                        Image(systemName: "folder").resizable()
                            .frame(width: 16,height: 16)
                        
                        Text("Import remote storage settings").appFont(.body)
                    }
                }.disabled(model.mapSyncDisabled)
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(Color.accentColor).appFont(.body)
                
                VStack{
                    Toggle("Overwrite existing",isOn: $model.overwriteExisting).appFont(.helpLabel)
                    
                    if model.overwriteExisting{
                        Text("Locations or camera credentials will be overwritten").appFont(.smallCaption).foregroundColor(.accentColor)
                    }
                }
               
            }
            Text(model.status).foregroundColor(.accentColor)
                .fontWeight(.light).appFont(.caption)
         
            Section(header: Text("NX-V devices").appFont(.sectionHeader)){
                  VStack{
                    ForEach(zeroConfig.services, id: \.self) { service in
                        if zeroConfig.isThisDevice(service: service.service) == false{
                            HStack{
                                Image(iconModel.nxvTitleIcon).resizable().frame(width: 18,height: 18)
                                Text(service.displayStr()).appFont(.caption)
                                Spacer()
                            }.padding(5)
                            .background(model.selectedUuid == service.id ? Color(iconModel.selectedRowColor) : Color(UIColor.clear))
                            .onTapGesture {
                                model.mapSyncDisabled = false
                                model.selectedUuid = service.id
                            }
                        }
                    }
                }.listStyle(PlainListStyle())
            }
        }.onAppear{
            iconModel.initIcons(isDark: colorScheme == .dark)
            model.status = "Select device and options"
            model.isDirty = false
        }
    
    }
}

struct ImportSettingsSheet_Previews: PreviewProvider {
    static var previews: some View {
        ImportSettingsSheet()
    }
}
