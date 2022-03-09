//
//  MapView.swift
//  NX-V
//
//  Created by Philip Bishop on 30/12/2021.
//

import SwiftUI
import MapKit
import AVFAudio

protocol MapViewEventListener{
    func cameraMapItemSelected(camera: Camera)
    func cameraMapPropertyChanged(camera: Camera)
    func zoomToCamera(camera: Camera)
    func removeCameraFromMap(camera: Camera)
    func hideMiniMap()
    func doSearch(poi: String)
    func onMapTapped(location: CLLocationCoordinate2D)
}

//

class CameraAnnotation : MKPointAnnotation{
    var camera: Camera
    var isCurrent = false
    var angle = CGFloat(0.0)
    var hasRecentAlerts = false
    var directionEnabled = false
    
    init(camera: Camera){
        self.camera = camera
    }
    
}
class CameraPolygon : MKPolygon{
    var camera: Camera?
    var isSelected = false
    
}
class CameraCircle : MKCircle{
    var camera: Camera?
    var isSelected = false
    var hasRecentAlerts = false
}

class Coordinator: NSObject, MKMapViewDelegate,UIGestureRecognizerDelegate {
    var parent: MapView

    var gRecognizer = UITapGestureRecognizer()
    
    init(_ parent: MapView) {
        self.parent = parent
        super.init()
        self.gRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapHandler))
        self.gRecognizer.delegate = self
        self.parent.mapView.addGestureRecognizer(gRecognizer)
    }

    @objc func tapHandler(_ gesture: UITapGestureRecognizer) {
        // position on the screen, CGPoint
        let location = gRecognizer.location(in: self.parent.mapView)
        // position on the map, CLLocationCoordinate2D
        let coordinate = self.parent.mapView.convert(location, toCoordinateFrom: self.parent.mapView)
        parent.model.mapViewListener?.onMapTapped(location: coordinate)
       }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        
        if overlay is MKPolygon {
            
            let polylineRenderer = MKPolygonRenderer(overlay: overlay)

            var nsc = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 0.25)

            if mapView.mapType != MKMapType.standard && mapView.mapType != MKMapType.mutedStandard{
                nsc = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 0.75)
            }
            polylineRenderer.fillColor =  nsc
            
            return polylineRenderer
        }
        
    
        if let circleOverlay = overlay as? CameraCircle {
            let circleRenderer = MKCircleRenderer(overlay: circleOverlay)
            circleRenderer.fillColor = circleOverlay.hasRecentAlerts ? .red : UIColor.systemBlue
            circleRenderer.alpha = circleOverlay.isSelected ? 1.0 : 0.5

            return circleRenderer
        }
        
        return MKOverlayRenderer(overlay: overlay)
    }
   
    
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        if let anno = view.annotation{
            if anno is CameraAnnotation{
                let camAnno = anno as! CameraAnnotation
                print("Mapview:didSelect",camAnno.camera.getStringUid())
                parent.updateCameraAnnotation(camera: camAnno.camera)
                //globalMapViewListener?.cameraMapItemSelected(camera: camAnno.camera)
                parent.model.mapViewListener?.cameraMapItemSelected(camera: camAnno.camera)
            }
        }else{
            print("Mapview:didSelect",view.annotation?.title)
        }
    }
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        if annotation is CameraAnnotation{
           
            let camAnno = annotation as! CameraAnnotation
            let camera = camAnno.camera
            let resueId = camera.getStringUid()+"_"+String(camera.beamAngle)
            
            //not working as expected
            /*
            if let eview = mapView.dequeueReusableAnnotationView(withIdentifier: resueId){
                eview.annotation = camAnno
                return eview
            }
             */
            
            let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: resueId)
                
            view.canShowCallout = true
            
            var camName = camAnno.camera.getDisplayName()
            if camName.count > 10{
                camName = Helpers.truncateString(inStr: camName, length: 10)
            }
            camAnno.title = camName
            
            let showLabels = parent.model.showLabels
            view.titleVisibility = showLabels ? .visible : .hidden
            view.glyphImage = UIImage(imageLiteralResourceName: "empty_glyph")
            view.glyphTintColor = UIColor.clear
            view.markerTintColor = UIColor.clear
            
           
            return view
        }
        return nil
       
        
        
    }
}

struct LocationBounds{
    var latCenter = 0.0;
    var lngCenter = 0.0;
    var latRange = 0.0;
    var lngRange = 0.0;
    
    func getAspectRatio() -> Double{
        return lngRange/latRange
    }
    
}

class ItemLocation{
    var name: String
    var isSelected: Bool
    var location: CLLocationCoordinate2D
    var camera: Camera
    
    static var SELECTED_TAG = "_SELECTED_"
    
    init(camera: Camera,isSelected: Bool,location: CLLocationCoordinate2D){
        self.camera = camera
        self.name = camera.getDisplayName()
        self.isSelected = isSelected
        self.location = location
    }
}
class GpsHelper{
    func coordinates(startingCoordinates: CLLocationCoordinate2D, atDistance: Double, atAngle: Double) -> CLLocationCoordinate2D {
        let distanceRadians = atDistance / 6371
        let bearingRadians = self.degreesToRadians(x: atAngle)
        let fromLatRadians = self.degreesToRadians(x: startingCoordinates.latitude)
        let fromLonRadians = self.degreesToRadians(x: startingCoordinates.longitude)

        let toLatRadians = asin(sin(fromLatRadians) * cos(distanceRadians) + cos(fromLatRadians) * sin(distanceRadians) * cos(bearingRadians))
        var toLonRadians = fromLonRadians + atan2(sin(bearingRadians) * sin(distanceRadians) * cos(fromLatRadians), cos(distanceRadians) - sin(fromLatRadians) * sin(toLatRadians));

        toLonRadians = fmod((toLonRadians + 3 * .pi), (2 * .pi)) - .pi

        let lat = self.radiansToDegrees(x: toLatRadians)
        let lon = self.radiansToDegrees(x: toLonRadians)

        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private func calculateAngleBetweenLocations(currentLocation: CLLocationCoordinate2D, targetLocation: CLLocationCoordinate2D) -> Double {
        let fLat = self.degreesToRadians(x: currentLocation.latitude);
        let fLng = self.degreesToRadians(x: currentLocation.longitude);
        let tLat = self.degreesToRadians(x: targetLocation.latitude);
        let tLng = self.degreesToRadians(x: targetLocation.longitude);
        let deltaLng = tLng - fLng

        let y = sin(deltaLng) * cos(tLat)
        let x = cos(fLat) * sin(tLat) - sin(fLat) * cos(tLat) * cos(deltaLng)

        let bearing = atan2(y, x)

        return self.radiansToDegrees(x: bearing)
    }

    private func degreesToRadians(x: Double) -> Double {
        return .pi * x / 180.0
    }

    private func radiansToDegrees(x: Double) -> Double {
        return x * 180.0 / .pi
    }
}
class MapViewModel : ObservableObject{
    @Published var currentPushPin: MKPointAnnotation?
    @Published var itemLocs = [ItemLocation]()
    @Published var isGroupView = false
    @Published var lastModeFullRegion = false
    @Published var isGlobalMap = false
    @Published var lastMapDelta = [0.0,0.0]
    @Published var ignoreNextDelta = false
    
    var showLabels = true
    var iconSize = 64
    
    var currentLoctionItem: ItemLocation?
    var mapViewListener: MapViewEventListener?
    
    func updateItem(_ item: ItemLocation){
        if itemLocs.count == 0{
            itemLocs.append(item)
            return
        }
        var currentIndex = -1
        for i in 0...itemLocs.count-1{
            let il = itemLocs[i]
            if il.camera.getStringUid() == item.camera.getStringUid(){
                currentIndex = i
                break
            }
        }
        
        if currentIndex != -1{
            itemLocs.remove(at: currentIndex)
        }
        itemLocs.append(item )
    }
    
    func calculateMapBounds() -> LocationBounds{
        var minLat = 0.0;
        var maxLat = 0.0;
        var minLng = 0.0;
        var maxLng = 0.0;
        
        for loc in itemLocs{
            if minLat == 0{
                minLat=loc.location.latitude
                maxLat=loc.location.latitude
                minLng=loc.location.longitude
                maxLng=loc.location.longitude
            }
            
            minLat=Double.minimum(minLat,loc.location.latitude)
            maxLat=Double.maximum(maxLat,loc.location.latitude)
            
            minLng=Double.minimum(minLng,loc.location.longitude)
            maxLng=Double.maximum(maxLng,loc.location.longitude)
            
        }
        
        let margin = 0.0;
        var bounds = LocationBounds()
        bounds.latCenter = (maxLat + minLat) / 2
        bounds.lngCenter = (maxLng + minLng) / 2
        bounds.latRange = (maxLat - minLat) + margin
        bounds.lngRange = (maxLng - minLng) + margin
        
        return bounds
    }
    
    func saveCurrent(){
        if let cloc = currentLoctionItem{
            var exists = false
            for item in itemLocs{
                if item.camera.getStringUid() == cloc.camera.getStringUid(){
                    item.camera.location = [cloc.location.latitude,cloc.location.longitude]
                    exists = true
                    break
                }
            }
            
        }
        
        
    }
}

struct MapView: UIViewRepresentable {
    var mapView = MKMapView()
    @ObservedObject var model = MapViewModel()
    
    @State var justRendered = false
    
    func setListener(listener: MapViewEventListener){
        model.mapViewListener = listener
    }
    func addBeamOverlay(camera: Camera,isSelected: Bool  = false){
        
        if let cloc = camera.location{

            let sizeFactor = Double(model.iconSize) / 32.0
            let distance  = sizeFactor * 0.0024
            
            let gpsHelper = GpsHelper()
            let location = CLLocationCoordinate2D(latitude: cloc[0], longitude: cloc[1])
            let c0 = location
            let c1 = gpsHelper.coordinates(startingCoordinates: location, atDistance: distance, atAngle: camera.beamAngle)
            let c2 = gpsHelper.coordinates(startingCoordinates: location, atDistance: distance, atAngle: camera.beamAngle - 25)
            let c3 = gpsHelper.coordinates(startingCoordinates: location, atDistance: distance, atAngle: camera.beamAngle + 25)
            let coords = [c0,c2,c1,c3,c0]
            let rpoly=CameraPolygon(coordinates: coords,count: coords.count)
            rpoly.camera = camera
            rpoly.isSelected = isSelected
            mapView.addOverlay(rpoly)
            
            let circle = CameraCircle(center: location, radius: 0.5 * sizeFactor)
            circle.camera = camera
            circle.isSelected = isSelected
            circle.hasRecentAlerts = camera.hasRecentAlerts
            mapView.addOverlay(circle)
        }
    }
    
    func updateCameraAnnotation(camera: Camera,remove: Bool = false){
        
        var doRenderOverlays = true
        
        var exists = false
        var itemIndex = -1
        if model.itemLocs.count > 0{
            for i in 0...model.itemLocs.count-1{
                let item = model.itemLocs[i]
                if item.camera.getStringUid() ==  camera.getStringUid(){
                    item.camera.beamAngle = camera.beamAngle
                    if let cloc = camera.location{
                        item.location = CLLocationCoordinate2D(latitude: cloc[0], longitude: cloc[1])
                    
                    }
                    item.isSelected = true
                    exists = true
                   itemIndex = i
                }else{
                    item.isSelected = false
                }
            }
        }
        if !exists{
            if let cloc = camera.location{
                let cloc = CLLocationCoordinate2D(latitude: cloc[0], longitude: cloc[1])
                let item = ItemLocation(camera: camera,isSelected: true,location: cloc)
                model.itemLocs.append(item)
            }
            renderItems()
            justRendered = true
        }else{
            //remove and re-add
            if remove && itemIndex != -1{
                model.itemLocs.remove(at: itemIndex)
            }
            
            if doRenderOverlays{
                mapView.removeOverlays(mapView.overlays)
                for item in model.itemLocs{
                    let isSelcted = item.camera.getStringUid() == camera.getStringUid()
                    addBeamOverlay(camera: item.camera,isSelected: isSelcted)
                }
            }else{
                var overlayToUpdate: CameraPolygon?
                var circleToUpdate: CameraCircle?
                
                for ovl in mapView.overlays{
                    if ovl is CameraPolygon{
                        let cpg = ovl as! CameraPolygon
                        if let cam = cpg.camera{
                            if cam.getStringUid() == camera.getStringUid(){
                                overlayToUpdate = cpg
                            }
                        }
                    }else if ovl is CameraCircle{
                        let circle = ovl as! CameraCircle
                        if circle.camera!.getStringUid() == camera.getStringUid(){
                            circleToUpdate = circle
                        }
                    
                    }
                }
                if let ovu = overlayToUpdate{
                    mapView.removeOverlay(ovu)
                    mapView.removeOverlay(circleToUpdate!)
                    if !remove{
                        addBeamOverlay(camera: camera,isSelected: true)
                    }
                }
            
            }
            var annoToUpdate: MKAnnotation?
            
            for anno in mapView.annotations{
                
                if anno is CameraAnnotation{
                    let camAnno  = anno as! CameraAnnotation
                    if camAnno.camera.getStringUid() == camera.getStringUid(){
                        camAnno.angle = camera.beamAngle
                        camAnno.hasRecentAlerts = camera.hasRecentAlerts
                        print("mapView:updateCameraAnnotation",camera.getStringUid())
                        annoToUpdate = camAnno
                        
                        break
                    }
                }
                
            }
            if let an2u = annoToUpdate{
                mapView.removeAnnotation(an2u)
                if !remove{
                    mapView.addAnnotation(an2u)
                    print("mapView:updateCameraAnnotation COMPLETE",camera.getStringUid())
                }
            }
        }
      
    }
    func setItems(items: [ItemLocation],isGroupView: Bool = false){
        print("MapView:setItems")
        
        model.isGroupView = isGroupView
        model.itemLocs.removeAll()
        for item in items{
            model.itemLocs.append(item)
        }
        
        renderItems()
        justRendered = true
    }
    func showFullRegion(){
        if model.itemLocs.count > 1{
          
            let mapBounds = model.calculateMapBounds()
            let spanToUse = MKCoordinateSpan(
                latitudeDelta: mapBounds.latRange + 0.25,
                longitudeDelta: mapBounds.lngRange + 0.25
            )
            let region = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(
                        latitude: mapBounds.latCenter,
                        longitude: mapBounds.lngCenter
                    ),
                    span: spanToUse
                )
            self.mapView.setRegion(region, animated: true)
            
            model.lastModeFullRegion = true
        }
    }
    func renderItems() -> Bool{
        
        print("MapView:renderItems",justRendered)
        if justRendered{
            justRendered = false
            print("MapView:renderItems justRendered, ignored")
            return true
        }
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)
        
        for item in model.itemLocs{
        
            let startLoc = CameraAnnotation(camera: item.camera)
            startLoc.directionEnabled = model.isGlobalMap
            startLoc.coordinate = item.location
            startLoc.isCurrent = item.isSelected
            startLoc.angle = CGFloat(item.camera.beamAngle)
            startLoc.hasRecentAlerts = item.camera.hasRecentAlerts
            
            if item.isSelected{
                model.currentPushPin = startLoc
               // startLoc.title = item.name + ItemLocation.SELECTED_TAG
            }else{
                //startLoc.title = item.name
            }
            
            print("MapView",startLoc.camera.getStringUid(),startLoc.coordinate)
            
            mapView.addAnnotation(startLoc)
            
            addBeamOverlay(camera: item.camera,isSelected: item.isSelected)
            
        }
        
        return mapView.annotations.count > 0
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        
    }
    
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
   
    func makeUIView(context: Context) -> MKMapView {
        mapView.delegate = context.coordinator
        mapView.pointOfInterestFilter = .excludingAll
        return mapView
    }

    func showZoomControls(){
        //mapView.showsZoomControls=true
    }
    func showOtherControls(){
        mapView.showsCompass = true
        mapView.isRotateEnabled = true
        mapView.isScrollEnabled = true
        mapView.isZoomEnabled = true
        mapView.isPitchEnabled = true
       
    }
    func showMuted(){
        mapView.mapType = MKMapType.mutedStandard
    }
    func toggleMapType(){
        let theMap=mapView
        if (theMap.mapType == MKMapType.standard)
        {
            theMap.mapType = MKMapType.hybridFlyover;
        }
        else if (theMap.mapType == MKMapType.hybrid)
        {
            theMap.mapType = MKMapType.satelliteFlyover;
        }
        else
        {
            theMap.mapType = MKMapType.standard;
        }
        renderItems()
    }
    func showMyLocation(){
        mapView.showsUserLocation=true
    }
    func enableDragEvents(enable: Bool){
        mapView.isScrollEnabled = enable
    
    }
    func getLocationAt(point: CGPoint) -> CLLocationCoordinate2D{
       return  mapView.convert(point, toCoordinateFrom: mapView)
    }
    
    func removeCameraFromMap(camera: Camera){
        updateCameraAnnotation(camera: camera, remove: true)
    }
   
    func setPushPinLocation(loc: CLLocationCoordinate2D,camera: Camera){
       
        if model.currentPushPin != nil{
            mapView.removeAnnotation(model.currentPushPin!)
        }
        
        let startLoc = CameraAnnotation(camera: camera)
        startLoc.directionEnabled = model.isGlobalMap
        startLoc.coordinate = loc
        startLoc.title = camera.getDisplayName()
        startLoc.isCurrent = true
        
        let newLoc = ItemLocation(camera: camera,isSelected: false,location: loc)
        model.updateItem(newLoc);
        model.currentLoctionItem = newLoc
        mapView.addAnnotation(startLoc)
        
        model.currentPushPin = startLoc
        
        addBeamOverlay(camera: camera)
        
        renderItems()
        
        print("MapView:setPushPinLocation",loc)
    }
    func saveCurrentPushPin(){
       model.saveCurrent()
        DispatchQueue.main.async{
            renderItems()
        }
    }
    func clearMap(){
        print("MapView:clearMap()")
        self.mapView.removeOverlays(self.mapView.overlays)
        self.mapView.removeAnnotations(self.mapView.annotations)
    }
    
    func setCenter(camera: Camera){
        if let cloc = camera.location{
            let loc = CLLocationCoordinate2D(latitude: cloc[0], longitude: cloc[1])
            mapView.setCenter(loc, animated: true)
        }
    }
    
    func gotoCurrentPushPin(){
        print("MapView:gotoPushPin",model.currentPushPin)
        
        if model.currentPushPin != nil{
            goto(location: model.currentPushPin!.coordinate)
        }
    }
    func zoomToLocation(loc: CLLocationCoordinate2D){
       
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: loc.latitude,
                longitude: loc.longitude
            ),
            span: MKCoordinateSpan(
                latitudeDelta: 0.001,
                longitudeDelta: 0.001
            )
        )
                
        DispatchQueue.main.async {
            self.mapView.setRegion(region, animated: false)
        }
            
    }
    
    func goto(location: CLLocationCoordinate2D?) -> LocationBounds?{
        var spanToUse = mapView.region.span
        
        mapView.showsUserLocation = false
        
        var animate = true
        var useCenter = true
       
        //USE FOR GROUPS
        
        if model.isGroupView && model.itemLocs.count > 1 {
            //calc span for cameras
            let mapBounds = model.calculateMapBounds()
            spanToUse = MKCoordinateSpan(
                latitudeDelta: mapBounds.latRange + 0.0004,
                longitudeDelta: mapBounds.lngRange + 0.0004
            )
            let region = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(
                        latitude: mapBounds.latCenter,
                        longitude: mapBounds.lngCenter
                    ),
                    span: spanToUse
                )
            self.mapView.setRegion(region, animated: true)
            return mapBounds
        }else if model.itemLocs.count == 0 || spanToUse.latitudeDelta > 10 || model.lastModeFullRegion{
            model.lastModeFullRegion = false
            useCenter = false
            spanToUse = MKCoordinateSpan(
                latitudeDelta: 0.005,
                longitudeDelta: 0.005
            )
        }
        
        if let loc = location{
            if useCenter{
                mapView.setCenter(loc, animated: animate)
                return nil
            }
            
            let region = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(
                        latitude: loc.latitude,
                        longitude: loc.longitude
                    ),
                    span: spanToUse
                )
            DispatchQueue.main.async {
                
                self.mapView.setRegion(region, animated: animate)
            }
        }
        return nil
    }
    
    func setLocation(location: CLLocation){
        print("MapView:setLocation()",location.coordinate)
        
        let delta = 0.05
        let region = MKCoordinateRegion(
            center: location.coordinate,span: MKCoordinateSpan(latitudeDelta: CLLocationDegrees(delta), longitudeDelta: CLLocationDegrees(delta)))
    
        self.mapView.setRegion(region, animated: true)
    }
    
    
    
}
