//
//  CameraLocationView.swift
//  NX-V
//
//  Created by Philip Bishop on 31/12/2021.
//

import SwiftUI
import MapKit
import AVFAudio



class CameraLocationModel : ObservableObject{
   
    
    //@Published var prompt = "Move the map to the camera's location or search for address or place name. Tap on map to set location"
    @Published var location: [Double]?
   // @Published var promptIndex = 0
    @Published var camera: Camera?
    
    @Published var showPrompt = false
    @Published var iconSizes = ["Small","Medium","Large","Very large"]
  
    @Published var iconSize = "Very large"
    
    @Published var mapTypes = ["Standard","Muted","Hybrid","Satellite"]
    @Published var mapType = "Standard"
    
    
    @Published var rightPaneHidden = true
    @Published var rightToggleColor: Color = .accentColor
    @Published var isGlobalMap = false
    @Published var hasLocation = false
    
    @Published var miniMapHidden = true
    @Published var isPad = false
    
    var isIosOnMac = false
    var rightPanelWidth = CGFloat(220)
    var allCameras = [Camera]()
    
    init(){
        if ProcessInfo.processInfo.isiOSAppOnMac{
            rightPanelWidth = CGFloat(300)
            isIosOnMac = true
        }
        isPad = UIDevice.current.userInterfaceIdiom == .pad
    }
    
    func getIconSizeValue(iconSize: String) -> Int{
        let sizes = [32,38,46,64]
        for i in 0...iconSize.count-1{
            if iconSize == iconSizes[i]{
                return sizes[i]
            }
        }
        return 32
    }
    
    func getSelectedMapType() -> MKMapType{
        let mtypes = [MKMapType.standard,MKMapType.mutedStandard,MKMapType.hybridFlyover,MKMapType.satelliteFlyover]
        for i in 0...mtypes.count-1{
            if mapType == mapTypes[i]{
                return mtypes[i]
            }
        }
        return .standard
    }
    
    var globalMapListener: MapViewEventListener?
    
    
    
    
}

struct CameraLocationView: View, MapViewEventListener,GlobalMapPropertiesListener {
    var mapView = MapView()
    var miniMap = MiniMap()
    
    @Environment(\.colorScheme) var colorScheme
    
    @ObservedObject var model = CameraLocationModel()
    
    var locationManager = LocationManager()
    var rightPanel = GlobalMapPropertiesPanel()
    
    @State var searchText = ""
    @State var saveKey = "icon_size"
    @State var mapSaveKey = "map_type"
    
    @State var showLabels = true
   
    init(){
        AppLog.write("CameraLocationView:init")
       
    }
    func resetMap(){
        mapView.clearMap()
    }
    //MARK: GlobalMapPropertiesListener
    func onPropertiesHidden() {
        rightPanel.hide()
        model.rightPaneHidden = true
    }
    //MARK: MapViewEventListener
    func onMapTapped(location: CLLocationCoordinate2D){
        if model.camera != nil &&  model.hasLocation == false {
            let loc = location
            AppLog.write("Map tap: ",loc)
            model.camera!.location = [loc.latitude,loc.longitude]
            model.camera!.saveLocation()
            model.hasLocation = true
            DispatchQueue.main.async{
                self.mapView.setPushPinLocation(loc: loc,camera: self.model.camera!)
                self.rightPanel.setCamera(camera: self.model.camera!, isGlobalMap: self.model.isGlobalMap,listener: self,closeListener: self)
                self.getAddress(from: loc)
                self.miniMap.refresh()
                
                globalCameraEventListener?.onGroupStateChanged(reload: false)
                
                RemoteLogging.log(item: "CameraLocationView:MapTapped")
            }
        
        }
    }
    func doSearch(poi: String){
        getLocation(from: poi, completion: goto)
        RemoteLogging.log(item: "CameraLocationView:doSearch")
    }
    func hideMiniMap(){
        model.miniMapHidden = true
    }
    func zoomToCamera(camera: Camera) {
        if let loc = camera.location{
            let cloc = CLLocationCoordinate2D(latitude: loc[0], longitude: loc[1])
            mapView.zoomToLocation(loc: cloc)
        }
    }
    func cameraMapItemSelected(camera: Camera) {
        AppLog.write("CameraLocationView:cameraMapItemSelected",camera.getDisplayName())
        AppLog.write("CameraLocationView:isGlobalMap",model.isGlobalMap)
        rightPanel.setCamera(camera: camera,isGlobalMap: model.isGlobalMap,listener:  self,closeListener: self)
        model.camera = camera
        model.location = camera.location
        model.hasLocation = camera.location != nil
        model.rightPaneHidden = false
        if camera.locationAddress.isEmpty{
            getAddressFromCamera(camera: camera)
        }
        
    }
    func cameraMapPropertyChanged(camera: Camera){
        mapView.updateCameraAnnotation(camera: camera)
        miniMap.refresh()
        AppLog.write("CameraLocationView:cameraMapPropertyChanged",camera.getDisplayName())
        AppLog.write("CameraLocationView:isGlobalMap",model.isGlobalMap)
    }
    func removeCameraFromMap(camera: Camera){
        mapView.removeCameraFromMap(camera: camera)
        
        //clear local location
        model.camera = camera
        model.hasLocation = false
        rightPanel.setCamera(camera: camera,isGlobalMap: model.isGlobalMap,listener:  self,closeListener: self)
    }
    
    func showFullRegion(allCameras: [Camera],zoomTo: Bool = true){
        var camsToUse = [Camera]()
        for cam in allCameras{
            if cam.isNvr(){
                camsToUse.append(contentsOf: cam.getVCams())
            }else{
                camsToUse.append(cam)
            }
        }
        var itemLocs = [ItemLocation]()
        for cam in camsToUse{
            
            if cam.locationLoaded == false {
                cam.loadLocation()
            }
            if let cloc = cam.location{
                let clloc = CLLocationCoordinate2D(latitude: cloc[0], longitude: cloc[1])
                let itemLoc = ItemLocation(camera: cam,isSelected: false,location: clloc)
                itemLocs.append(itemLoc)
                
                
            }
        }
        mapView.setItems(items: itemLocs)
        
        if zoomTo{
            mapView.showFullRegion()
        }
    }
    func showMiniMap(group: CameraGroup){
        miniMap.setGroup(group: group)
        miniMap.model.listener = self
        model.miniMapHidden = false
    }
    
    func setCamera(camera: Camera,allCameras: [Camera],isGlobalMap: Bool){
        
        model.location = camera.location
        model.isGlobalMap = isGlobalMap
        model.allCameras = allCameras
        //first time init must be called
        rightPanel.setCamera(camera: camera,isGlobalMap: isGlobalMap,listener: self,closeListener: self)
        
        changeCamera(camera: camera)
    }
    func changeCamera(camera: Camera){
        
        if camera.locationLoaded == false {
            camera.loadLocation()
        }
        
        rightPanel.changeCamera(camera: camera)
        model.camera = camera
        
        model.hasLocation = camera.hasValidLocation()
        
        if self.rightPanel.model.visible  || model.location == nil{
            model.rightPaneHidden = false
            
        }else{
            self.model.rightPaneHidden = true
        }
        
        
        
        var camsToUse = [Camera]()
        for cam in model.allCameras{
            if cam.isNvr(){
                camsToUse.append(contentsOf: cam.getVCams())
            }else{
                if cam.hasValidLocation() == false && cam.isNetworkStream(){
                    if let loc = eenApi.getLocationIfMatched(camera: cam){
                        
                        debugPrint("Got location from EENApi",cam.getDisplayNameAndAddr())
                        cam.location = [loc.lat,loc.lng]
                        cam.beamAngle = loc.angle
                        cam.saveLocation()
                        
                    }
                }
                camsToUse.append(cam)
            }
        }
        
        var exists = false
        var itemLocs = [ItemLocation]()
        for cam in camsToUse{
            let isCurrentCam = cam.getStringUid() == camera.getStringUid()
            if cam.locationLoaded == false {
                cam.loadLocation()
            }
            if isCurrentCam && cam.hasValidLocation() == false{
                continue
            }
            if let cloc = cam.location{
                let clloc = CLLocationCoordinate2D(latitude: cloc[0], longitude: cloc[1])
                let itemLoc = ItemLocation(camera: cam,isSelected: isCurrentCam,location: clloc)
                itemLocs.append(itemLoc)
                
                if isCurrentCam{
                    exists = true
                    goto(location: clloc)
                    getAddress(from: clloc)
                }
            }
        }
        if !exists || model.isGlobalMap == false{
            mapView.clearMap()
            mapView.setItems(items: itemLocs)
            
        }else{
            mapView.updateCameraAnnotation(camera: camera)
        }
        
        
        
    }
    func gotoCamera(cam: Camera){
        if let cloc = cam.location{
            let clloc = CLLocationCoordinate2D(latitude: cloc[0], longitude: cloc[1])
            DispatchQueue.main.async {
                goto(location: clloc)
                
            }
            
        }
    }
    func goto(location: CLLocationCoordinate2D?){
        if let loc = location{
            mapView.goto(location: loc)
            
        }
    }
    /*
    func doSearch(){
        getLocation(from: searchText, completion: goto)
    }
     */
    func updateMapIcons(){
         mapView.model.iconSize = model.getIconSizeValue(iconSize: model.iconSize)
        
        mapView.renderItems()
    }
    func updateMapType(){
        let mtype = model.getSelectedMapType()
        mapView.mapView.mapType = mtype
        mapView.renderItems()
        
        if mtype == .standard || mtype == .mutedStandard{
            model.rightToggleColor = .accentColor
        }else{
            model.rightToggleColor = .white
        }
    }
    var body: some View {
        
        VStack(spacing: 0){
            HStack{
                ZStack(alignment: .top){
                    mapView
                    miniMap.hidden(model.miniMapHidden)
                    HStack{
                        Spacer()
                        rightPanel
                            .padding(5)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                            .frame(width: model.rightPaneHidden ? 0 : model.rightPanelWidth)
                    }
                }
            }
            HStack(spacing: 5){
                
                Picker("", selection: $model.mapType) {
                    ForEach(model.mapTypes, id: \.self) {
                        Text($0)
                    }
                }.onChange(of: model.mapType) { newMap in
                    UserDefaults.standard.set(newMap,forKey: mapSaveKey)
                    updateMapType()
                }.pickerStyle(SegmentedPickerStyle())
                
            }.padding(10).frame(height: 42)
            
            
        }.background(Color(UIColor.systemGroupedBackground))
        .onAppear{
            
            mapView.setListener(listener: self)
            mapView.setIsDark(isDark: colorScheme ==  .dark)
            miniMap.setListener(listener: self)
             
            model.globalMapListener = self

            mapView.showOtherControls()
            mapView.showZoomControls()
            
            AppLog.write("CameraLocationModel:onAppear")
            if mapView.renderItems() == false{
                
                if locationManager.startIfRequired(mapView: mapView){
                    mapView.showMyLocation()
                }
            }else{
                //zoom to this camera
                mapView.gotoCurrentPushPin()
            }
            
            if UserDefaults.standard.object(forKey: saveKey) != nil {
                let oldSize = UserDefaults.standard.string(forKey: saveKey)!
                if oldSize != model.iconSize{
                    model.iconSize = oldSize
                    updateMapIcons()
                }
            }
            if UserDefaults.standard.object(forKey: mapSaveKey) != nil {
                let oldMap = UserDefaults.standard.string(forKey: mapSaveKey)!
                if model.mapType != oldMap{
                    model.mapType = oldMap
                    updateMapType()
                }
            }
        }
    }
    
    func getLocation(from address: String, completion: @escaping (_ location: CLLocationCoordinate2D?)-> Void) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { (placemarks, error) in
            guard let placemarks = placemarks,
                  let location = placemarks.first?.location?.coordinate else {
                      completion(nil)
                
                      return
                  }
            completion(location)
           
        }
    }
    func getAddress(from: CLLocationCoordinate2D){
        let clloc = CLLocation(latitude: from.latitude, longitude: from.longitude)
        
        let geocoder = CLGeocoder()
        
        geocoder.reverseGeocodeLocation(clloc) { place, error in
            if error != nil{
                AppLog.write("CameraMapView:reverseGeocodeLocation",error)
            }else{
                if let addr = place{
                    if addr.count > 0{
                        let first = addr.first!
                        let addressList = first.addressDictionary?["FormattedAddressLines"] as? [String]
                        
                        let address =  addressList!.joined(separator: "\n")
                        
                        DispatchQueue.main.async{
                            self.rightPanel.model.setAddress(addr: address)
                        }
                        
                    }
                }
            }
        }
        
    }
    func getAddressFromCamera(camera: Camera){
        if let loc = camera.location{
            let clloc = CLLocationCoordinate2D(latitude: loc[0], longitude: loc[1])
            getAddress(from: clloc)
        }
    }
}

struct CameraLocationView_Previews: PreviewProvider {
    static var previews: some View {
        CameraLocationView()
    }
}
