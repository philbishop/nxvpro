//
//  SystemLogView.swift
//  NX-V
//
//  Created by Philip Bishop on 05/01/2022.
//

import SwiftUI

class SystemLogViewModel : ObservableObject{
    
    @Published var supportsLogging = false
    @Published var currentLog = [String]()
    @Published var logType = "System"
    @Published var status = "Waiting for logging data..."
    @Published var allProps = CameraProperies()
    
    var camera: Camera?
    let onvif = OnvifDisco()
    
    
    func setCamera(camera: Camera){
        self.camera = camera
        self.supportsLogging = camera.systemLogging
        self.currentLog.removeAll()
        self.allProps.props.removeAll()
    }
    func loadData(){
        if supportsLogging {
            status = "Waiting for logging data..."
        }
        
        
        onvif.prepare()
        onvif.getSystemCapabilites(camera: camera!,callback: handleGetSystenCapabilities)
    }
    func handleGetSystenCapabilities(camera: Camera,xPaths: [String],data: Data?){
        getLog()
        let resp = String(data: data!, encoding: .utf8)
        let xmlParser = XmlAttribsParser(tag: "System")
        xmlParser.parseRespose(xml: data!)
        
        var pid = 0
        for (key,val) in xmlParser.attribs{
            allProps.props.append(CameraProperty(id: pid,name: key,val: val,editable: false))
            pid += 1
        }
        
        print("SystemLogView attributes",xmlParser.attribs.count)
    }
    func getLog(){
        
        onvif.getSystemLog(camera: camera!, logType: logType) { cam, logLines, error, ok in
            print("SystemLogViewModel:getSystemLog",logLines.count,error,ok)
            
            DispatchQueue.main.async{
                self.supportsLogging = true
                self.currentLog.removeAll()
                if ok{
                    for line in logLines{
                        if line.hasPrefix("<"){
                            continue
                        }
                        self.currentLog.append(line)
                    }
                    self.status = ""
                    if self.currentLog.count == 0{
                        self.status = "No logging data returned by device"
                    }
                }else{
                    self.status = error
                }
            }
        }
        
    }
}

struct SystemLogView: View {
    @ObservedObject var model = SystemLogViewModel()
    
    @State var showRebootAlert = false
    
    func setCamera(camera: Camera){
        model.setCamera(camera: camera)
    }
    
    var body: some View {
        ZStack(alignment: .topLeading){
            VStack{
                HStack{
                    VStack{
                        Text("System info").appFont(.titleBar)
                        
                        List(){
                            Section(header: Text("Capabilities")){
                                ForEach(model.allProps.props, id: \.self) { prop in
                                    HStack{
                                        Text(prop.name).fontWeight(prop.val.isEmpty ? .none : /*@START_MENU_TOKEN@*/.bold/*@END_MENU_TOKEN@*/)
                                            .appFont(.caption)
                                            .frame(alignment: .leading)
                                        Spacer()
                                        Text(prop.val).appFont(.caption)
                                            .frame(alignment: .trailing)
                                        
                                    }.frame(alignment: .leading)
                                }
                            }
                        }.listStyle(PlainListStyle())
                    }.frame(width: 360)
                    
                    VStack(alignment: .leading){
                        Text("System log").appFont(.titleBar)
                        if model.supportsLogging == false{
                            Text("Device does not support system logging").appFont(.helpLabel)
                                .padding()
                        }else{
                            Text(model.status).appFont(.sectionHeader).foregroundColor(.accentColor)
                                .appFont(.caption)
                        }
                        ScrollView(.vertical){
                            VStack(alignment: .leading){
                                ForEach(model.currentLog,id: \.self) {line in
                                    HStack{
                                        Text(line).font(.system(.caption, design: .monospaced))
                                          
                                            .frame(alignment: .leading)
                                        Spacer()
                                    }
                                }
                                
                            }
                        }
                    }
                    Spacer()
                }.frame(alignment: .leading)
                HStack(spacing: 5){
                    
                    Button("Reboot",action:{
                        showRebootAlert = true
                    }).alert(isPresented: $showRebootAlert) {
                        
                        Alert(title: Text("REBOOT"), message: Text("Confirm device reboot\n" + "\n" + model.camera!.getDisplayAddr()
                                                                   + "\n" + model.camera!.getDisplayName()),
                              primaryButton: .default (Text("Reboot")) {
                            showRebootAlert = false
                            
                            //globalToolbarListener?.rebootDevice(camera: model.camera!)
                        },
                              secondaryButton: .cancel() {
                            showRebootAlert = false
                        }
                        )
                    }
                    Button("Soft reset",action:{
                        
                    }).disabled(true)
                }.padding()
                
            }
        }.onAppear{
            if model.supportsLogging && model.currentLog.count == 0{
                model.loadData()
            }
        }
    }
}

struct SystemLogView_Previews: PreviewProvider {
    static var previews: some View {
        SystemLogView()
    }
}
