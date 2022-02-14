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
    @Published var isGlobalMap = false
    @Published var hasLocation = false
    
    @Published var miniMapHidden = true
    
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

struct CameraLocationView: View, MapViewEventListener {
    var mapView = MapView()
    var miniMap = MiniMap()
    
    @ObservedObject var model = CameraLocationModel()
    
    var locationManager = LocationManager()
    var rightPanel = GlobalMapPropertiesPanel()
    
    @State var searchText = ""
    @State var saveKey = "icon_size"
    @State var mapSaveKey = "map_type"
    
    @State var showLabels = true
   
    init(){
        print("CameraLocationView:init")
        mapView.setListener(listener: self)
        miniMap.setListener(listener: self)
        model.globalMapListener = self
    }
    
    //MARK: MapViewEventListener
    func doSearch(poi: String){
        getLocation(from: poi, completion: goto)
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
        print("CameraLocationView:cameraMapItemSelected",camera.getDisplayName())
        print("CameraLocationView:isGlobalMap",model.isGlobalMap)
        rightPanel.setCamera(camera: camera,isGlobalMap: model.isGlobalMap,listener:  self)
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
        print("CameraLocationView:cameraMapPropertyChanged",camera.getDisplayName())
        print("CameraLocationView:isGlobalMap",model.isGlobalMap)
    }
    func removeCameraFromMap(camera: Camera){
        mapView.removeCameraFromMap(camera: camera)
        
        //clear local location
        model.camera = camera
        model.hasLocation = false
        rightPanel.setCamera(camera: camera,isGlobalMap: model.isGlobalMap,listener:  self)
    }
    func showFullRegion(allCameras: [Camera]){
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
        
        mapView.showFullRegion()
    }
    func showMiniMap(group: CameraGroup){
        miniMap.setGroup(group: group)
        miniMap.model.listener = self
        model.miniMapHidden = false
    }
    
    func setCamera(camera: Camera,allCameras: [Camera],isGlobalMap: Bool){
        
       
        
        if camera.locationLoaded == false {
            camera.loadLocation()
        }
        
        model.camera = camera
        model.location = camera.location
        model.isGlobalMap = isGlobalMap
        model.hasLocation = camera.hasValidLocation()
        self.rightPanel.setCamera(camera: camera,isGlobalMap: isGlobalMap,listener: self)
        
        if self.rightPanel.model.visible  || model.location == nil{
            model.rightPaneHidden = false
            
        }else{
            self.model.rightPaneHidden = true
        }
        
        
        
        var camsToUse = [Camera]()
        for cam in allCameras{
            if cam.isNvr(){
                camsToUse.append(contentsOf: cam.getVCams())
            }else{
                camsToUse.append(cam)
            }
        }
        
        var exists = false
        var itemLocs = [ItemLocation]()
        for cam in camsToUse{
            let isCurrentCam = cam.id == camera.id
            if cam.locationLoaded == false {
                cam.loadLocation()
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
    }
    var body: some View {
        
        VStack{
            HStack{
                ZStack{
                    mapView.gesture(DragGesture(minimumDistance: 0).onEnded({ (value) in
                        let xDiff = abs(value.location.x - value.startLocation.x)
                        let yDiff = abs(value.location.y - value.startLocation.y)
                        
                        if model.camera != nil{
                            if  model.hasLocation == false && xDiff < 5 && yDiff < 5{
                                let loc=mapView.getLocationAt(point: value.location)
                                print("Map tap: ",loc)
                                model.camera!.location = [loc.latitude,loc.longitude]
                                model.camera!.saveLocation()
                                model.hasLocation = true
                                DispatchQueue.main.async{
                                    self.mapView.setPushPinLocation(loc: loc,camera: self.model.camera!)
                                    self.rightPanel.setCamera(camera: self.model.camera!, isGlobalMap: self.model.isGlobalMap,listener: self)
                                    self.getAddress(from: loc)
                                    self.miniMap.refresh()
                                }
                            }
                        }
                    }))
                    
                    miniMap.hidden(model.miniMapHidden)
                }
                VStack{
                    rightPanel
                    Spacer()
                    
                    HStack{
                        Button(action:{
                            rightPanel.hide()
                            model.rightPaneHidden = true
                        }){
                            Text("Close").appFont(.helpLabel)
                        }.disabled(model.location == nil)
                    }.padding(.bottom)
                        .hidden(model.rightPaneHidden)
                        
                }.frame(width: model.rightPaneHidden ? 0 : 200)
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
            
            
        }.onAppear{
            
            
            mapView.showOtherControls()
            mapView.showZoomControls()
            
            print("CameraLocationModel:onAppear")
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
                print("CameraMapView:reverseGeocodeLocation",error)
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
