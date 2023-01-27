
import SwiftUI

protocol AddCameraCompleteListener{
    func onCameraAddedOk()
}

class AddCameraModel : ObservableObject{
     
    var listener: AddCameraCompleteListener?
    var cameraEventListener: CameraEventListener?
    
    var okColor = Color(UIColor.label)
    var errorColor = Color(UIColor.systemRed)
    var connectBtnColor: Color
    
    @Published var showAddCamera: Bool = true
    
    @Published var ipColor: Color
    @Published var ipAddress: String = "" {
        didSet{
            validateForm()
        }
    }
    
    @Published var portColor: Color
    @Published var port: String = "" {
        didSet{
            validateForm()
        }
    }
    
    @Published var pathColor: Color
    @Published var path: String = "onvif/device_service"
    
    @Published var user: String = "" {
        didSet{
            validateForm()
        }
    }
    
    @Published var password: String = ""
    
    @Published var statusFontSize: CGFloat = CGFloat(14)
    @Published var statusColor: Color
    @Published var status: String = "Enter camera details"
    
    @Published var connectEnabled: Bool = false
    
    init(){
        ipColor = okColor
        portColor = okColor
        pathColor = okColor
        statusColor = okColor
        connectBtnColor = okColor
        #if DEBUG_TEST
        user = "admin"
        password = "admin123"
        ipAddress = "86.172.177.141"
        port = "8080"
        #endif
    }
    
    func exwcuteTest(){
    
        testConnection(ipa: ipAddress, port: port, path: path, user: user, password: password)
    }
    
    func validateForm(){
        connectEnabled = false
        
        if checkIpAddres(){
            ipColor = okColor
            if checkPort(){
                portColor = okColor
                if user.count > 3{
                    connectEnabled = true
                    connectBtnColor = Color(UIColor.systemBlue)
                    status = "Ready to test"
                }else{
                    connectBtnColor = okColor
                    status = "User name required"
                }
            }else{
                portColor = errorColor
            }
        }else{
            ipColor = errorColor
        }
        
        statusColor = connectEnabled ? okColor : errorColor
    }
    func checkIpAddres() -> Bool{
        
        let parts = ipAddress.components(separatedBy: ".")
        if parts.count == 4{
            for n in parts{
                if let ival = Int(n){
                    if ival > 0 && ival < 256{
                        if String(ival) != n{
                            status = "Error in ip " + n
                            return false
                        }
                    }
                }else{
                    status = "Error in ip " + n
                    return false
                }
            }
            status = "Valid address"
            return true
        }
        status = "Incomplete address"
        return false
    }
    func checkPort() -> Bool{
        let error = "Error in port number"
        if let ival = Int(port){
            if ival > 0 && ival < 65535{
                if String(ival) != port{
                    status = error
                    return false
                }
            }
        }else{
            status = error
            return false
        }
        
        return true
    }
    
    //MARK: Test connection
    let disco = OnvifDisco()
    var discoXml: String?
    func testConnection(ipa: String,port: String,path: String,user: String,password: String){
        
        let xipa = "http://" + ipa + ":" + port + "/" + path
        
        let tmpl = getWanTemplate()
        discoXml = tmpl.replacingOccurrences(of: "_XADDR_", with: xipa)
        discoXml = discoXml!.replacingOccurrences(of: "_CAM_NAME_", with: "WAN CAM")
        //AppLog.write(discoXml)
        
        let camera = Camera(id: 0)
        camera.xAddr = xipa
        camera.user = user
        camera.password = password
        camera.name = "WAN CAM"
        
        status = "Connecting to " + ipa
        statusColor = Color(UIColor.systemBlue)
        
        connectEnabled = false
        connectBtnColor = okColor
        
        disco.prepare()
        disco.getSystemTime(camera: camera, callback: handleUnicastGetSystemTime)
    }
    func handleUnicastGetSystemTime(camera: Camera){
        AppLog.write("AddCamera: Handle unicast got systemTime ",camera.name,camera.connectTime)
        
        if camera.timeCheckOk{
            
            //call listener to make the sheet to go away here
            listener?.onCameraAddedOk()
            
            disco.handleGetSystemTime(camera: camera)
            saveUnicastFiles(camera: camera)
            
        }
        
        DispatchQueue.main.async {
            if camera.timeCheckOk {
                //save to /wan discoXml and camera json
                AppLog.write("AddCamera: save to wan");
                
                self.statusColor = Color(UIColor.systemBlue)
                self.statusFontSize = CGFloat(18)
                self.status = "Connection OK"
                self.listener?.onCameraAddedOk()
                //self.showAddCamera = false
            }else{
                self.statusColor = self.errorColor
                self.status = "Connection failed"
                self.connectEnabled = true
            }
        }
        
        
    }
    func saveUnicastFiles(camera: Camera){
        let sroot = FileHelper.getStorageRoot()
        let discoFile = camera.getBaseFileName() + "_disco.xml"
        let discoFilePath = sroot.appendingPathComponent(discoFile)
        
        do {
            try discoXml?.write(toFile: discoFilePath.path, atomically: true, encoding: .ascii)
        }
        catch {
            AppLog.write("Failed to write disco XML data: \(error.localizedDescription)")
        }
        
        camera.authenticated = true
        camera.save()
        
        cameraEventListener?.onImportConfig(camera: camera)
    }
    func getWanTemplate() -> String{
        let fileName = "wan_disco_template"
        if let filepath = Bundle.main.path(forResource: fileName, ofType: "xml") {
            do {
                let contents = try String(contentsOfFile: filepath)
                return contents
            } catch {
                AppLog.write("Failed to load XML from bundle",fileName)
            }
        }
        return ""
    }
}

struct AddCameraSheetView: View, AddCameraCompleteListener {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var model = AddCameraModel()
    
    func onCameraAddedOk() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute:{
            presentationMode.wrappedValue.dismiss()
        })
    }
    func setListener(listener: CameraEventListener){
        model.cameraEventListener = listener
    }
    var body: some View {
        
        List{
            
                HStack{
                    Text("Add camera").appFont(.title)
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
                HStack{
                Text(model.status)
                        .font(.system(size: model.statusFontSize))
                    .fontWeight(.light)
                    .padding()
                    
                    Spacer()
                    
                    Button("Connect"){
                        model.exwcuteTest()
                    }
                    .foregroundColor(model.connectBtnColor)
                    .buttonStyle(.plain)
                    .disabled(model.connectEnabled == false)
                    .hidden(model.showAddCamera == false)
                    
                }
            
            Section(header: Text("Credentials").appFont(.sectionHeader)){
                VStack(spacing: 10){
                    TextField("user",text: $model.user)
                        .autocapitalization(.none)
                        .padding()
                    
                    TextField("password",text: $model.password)
                        .autocapitalization(.none)
                        .padding()
                }
            }.hidden(model.showAddCamera == false)
            Section(header: Text("IP address and port").appFont(.sectionHeader)) {
                HStack{
                    TextField("x.x.x.x",text: $model.ipAddress)
                    .keyboardType(.numbersAndPunctuation)
                    
                    .padding()
                    .foregroundColor(model.ipColor)
                    .border(model.ipColor,width: 1)
                    //.frame(width: 150)
                    
                    Text("Port")
                    TextField("80",text: $model.port)
                    .keyboardType(.numberPad)
                    .padding()
                    .foregroundColor(model.portColor)
                    .border(model.portColor,width: 1)
                    .frame(width: 90)
                }
            }.hidden(model.showAddCamera == false)
            Section(header: Text("ONVIF service path").appFont(.sectionHeader)) {
                TextField("80",text: $model.path,onEditingChanged: { (changed) in
                    model.validateForm()
                }) {
                    AppLog.write("path onCommit")
                    model.validateForm()
                    
                }
                .foregroundColor(model.pathColor)
                .frame(width: 170)
            }.hidden(model.showAddCamera == false)
            
            
            
            
            
           
            
        }
        .listStyle(.plain)
        .frame(alignment: .leading)
        .onAppear(perform: {
            model.listener = self
        })
    }
}

struct AddCameraSheetView_Previews: PreviewProvider {
    static var previews: some View {
        AddCameraSheetView()
    }
}
