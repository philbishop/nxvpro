//
//  GlobalMapPropertiesPanel.swift
//  NX-V
//
//  Created by Philip Bishop on 15/01/2022.
//

import SwiftUI

class GlobalMapPropertiesModel : ObservableObject{
    var camera: Camera?
    
    @Published var name = ""
    @Published var angle = ""
    @Published var visible = false
    @Published var recodingEvents = [String:[RecordToken]]()
    @Published var recentAlerts = [RecordToken]()
    @Published var playerHidden = true
    @Published var playerWidth = CGFloat(245)
    @Published var playerStatus = "Connecting to camera...."
    
    @Published var cardinalPoints = ["N","NNE","NE","ENE","E","ESE","SE","SSE","S","SSW","SW","WSW","W","WNW","NW","NNW"]
    @Published var cardinalSelected = "N"
    
    @Published var cameraAuthenticated = false
    @Published var isGlobalMap = false
    
    @Published var hasLocation = false
    @Published var locationHelp = ""
    
    @Published var address = ""
    @Published var showPlayerSheet = false
    
    var listener: MapViewEventListener?
    
    func setAddress(addr: String){
        address = addr
        if let cam = camera{
            cam.locationAddress = addr
        }
    }
    
    func setTextForResource(res: String){
        if let filepath = Bundle.main.path(forResource: res, ofType: "txt") {
            do {
                let contents = try String(contentsOfFile: filepath)
                //print(contents)
                locationHelp = contents
                
            } catch {
                print("Location help: \(error)")
            }
        }else{
            print("Location help: Can't find",res)
        }
    }
    
    func setCamera(camera: Camera,isGlobalMap: Bool){
        self.camera = camera
        self.isGlobalMap = isGlobalMap
        visible = true
        address = ""
        setTextForResource(res: "map_set_location")
        hasLocation = camera.location != nil
        cameraAuthenticated = camera.isAuthenticated()
        playerWidth = CGFloat(245)
        playerHidden = true
        address = camera.locationAddress
        
        name = camera.getDisplayName()
        angle = String(camera.beamAngle)
        
        let inc = 22.5 // degrees
        var selPoint = 0
        let dangle = Double(angle)!
        var cangle = 0.0
        for i in 0...cardinalPoints.count-1{
            
            if dangle >= cangle{
                selPoint = i
            }
            
            cangle += inc
        }
        
        cardinalSelected = cardinalPoints[selPoint]
        
    }
    func cardinalChanged(){
        
        let inc = 22.5 // degrees
        var cangle = 0.0
        for i in 0...cardinalPoints.count-1{
            
            if cardinalSelected == cardinalPoints[i]{
                angle = String(cangle)
                setBeamAngle(beam: cangle)
                break
            }
            cangle += inc
        }
    }
    func setBeamAngle(beam: Double){
        camera!.beamAngle = beam
        camera!.saveLocation()
        DispatchQueue.main.async {
            
            self.listener?.cameraMapPropertyChanged(camera: self.camera!)
        }
    }
    
    func handleEvent(camera: Camera,token: RecordToken){
       
        let key = camera.getStringUid()
        if recodingEvents[key] == nil{
            recodingEvents[key] = [RecordToken]()
        }
        var exists = false
        if let items = recodingEvents[key]{
            for item in items{
                if item.Time == token.Time{
                    exists = true
                    break
                }
            }
        }
        if !exists{
            recodingEvents[key]!.insert(token, at: 0)
            
            let ne = recodingEvents[key]!.count
            if ne > 5 {
                
                recodingEvents[key]!.remove(at: ne-1)
            }
        }
    }
    func getRecentEvents() -> [RecordToken]?{
        if camera != nil{
            return recodingEvents[camera!.getStringUid()]
        }
        return nil
    }
}

struct GlobalMapPropertiesPanel : View, VideoPlayerDimissListener{
    
    
    
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var iconModel = AppIconModel()
    
    @ObservedObject var model = GlobalMapPropertiesModel()
    @State var searchText = ""
    
    init(){
        print("GlobalMapPropertiesPanel:init")
    }
    
    //MARK: VideoPlayerDimissListener
    func dimissPlayer() {
        model.showPlayerSheet = false
    }
    func dismissAndShare(localPath: URL) {
        
    }
    
    func setCamera(camera: Camera,isGlobalMap: Bool,listener: MapViewEventListener){
        model.setCamera(camera: camera,isGlobalMap: isGlobalMap)
        self.model.listener = listener
        
        print("GlobalMapPropertiesPanel:setCamera isGlobal",isGlobalMap)
        
    }
    func hide(){
        model.visible = false
        model.playerHidden = true
        
        //borderlessPlayer.stop()
    }
    var body: some View {
        VStack(alignment: .leading){
            HStack(alignment: .center){
            Text(model.name).appFont(.titleBar)
                Spacer()
                Button(action: {
                    //show streamin view
                    //AppDelegate.Instance.showCameraWindow(camera: model.camera!)
                    model.showPlayerSheet = true
                }){
                    Image(systemName: "play")
                        .resizable()
                        
                        .frame(width: 14, height: 16)
                    
                }.hidden(model.cameraAuthenticated==false || model.isGlobalMap==false)
                    .buttonStyle(PlainButtonStyle())
                    .padding(.trailing)
                
            }.padding(.top)
                .sheet(isPresented: $model.showPlayerSheet) {
                   
                    VideoPlayerSheet(camera: model.camera!,listener: self)
                    
                }

            
            Divider()
         
            if model.hasLocation{
                Text("Properties").fontWeight(.light).appFont(.sectionHeader).frame(alignment: .leading)
                
                HStack{
                    Text("Direction").appFont(.helpLabel)
                    Picker("",selection: $model.cardinalSelected){
                        ForEach(model.cardinalPoints, id: \.self) {
                            Text($0)
                        }
                    }.onChange(of: model.cardinalSelected) { newCardinal in
                        model.cardinalChanged()
                    }.frame(width: 120)
                    
                    Spacer()
                }
                
                if model.address.isEmpty == false{
                    Text("Address").appFont(.smallCaption)
                    HStack{
                        Text(model.address).appFont(.caption)
                        Spacer()
                    }.frame(height: 80,alignment: .leading)
                    
                    Button(action: {
                        model.camera!.location = nil
                        model.camera?.locationAddress = ""
                        model.camera!.saveLocation()
                        model.listener?.removeCameraFromMap(camera: model.camera!)
                    }){
                        Text("Change location").appFont(.caption)
                    }.padding(.bottom)
                    
                    Button(action:{
                        model.listener?.zoomToCamera(camera: model.camera!)
                    }){
                        Text("Zoom location").appFont(.caption)
                    }
                    
                }
                Divider()
                Text("Recent alerts").fontWeight(.light).appFont(.sectionHeader).frame(alignment: .leading)
                
                if let recentEvents = model.getRecentEvents(){
                    ScrollView(.vertical){
                        VStack{
                            ForEach(recentEvents) { alert in
                                Text(alert.Time).appFont(.smallCaption)
                            }
                        }
                    }.frame(height: 150)
                }
                
            }else{
                
                VStack{
                    Text("Find location").appFont(.smallCaption)
                    TextField("Address or POI",text: $searchText){
                        model.listener?.doSearch(poi: searchText)
                    }.appFont(.caption)
                    
                    Button(action: {
                        model.listener?.doSearch(poi: searchText)
                    }){
                        Text("Search").appFont(.helpLabel)
                    }
                    
                    Divider()
                    
                    Text("Set camera location").fontWeight(.semibold).appFont(.sectionHeader)
                        .padding()
                    
                    Text(model.locationHelp)
                        .appFont(.sectionHeader)
                    
                    
                    
                }.padding(3)
                .frame(height: 350,alignment: .leading)
                Spacer()
            }
            
            
        }.hidden(model.visible == false)
            .onAppear{
                recordingEventMonitor.cameraPropsModel = model
                iconModel.initIcons(isDark: colorScheme == .dark )
            }
    }
}

