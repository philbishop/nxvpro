//
//  MiniMap.swift
//  NX-V
//
//  Created by Philip Bishop on 24/01/2022.
//

import SwiftUI
import MapKit

class MiniMapModel : ObservableObject{
   
    @Published var name = "Group name"
    @Published var winSize: CGSize?
    
    var listener: MapViewEventListener?
    var group: CameraGroup?
    var winW = CGFloat(350)
    var winH = CGFloat(300)
    var topBounds = CGPoint(x: 195, y: 165)
    var newLocation: CGPoint?
    
    func viewInBounds(newPosition: CGPoint)-> Bool{
        
        newLocation = newPosition
        
        if newPosition.y < topBounds.y{
            return false
        }
        if newPosition.x < topBounds.x{
            return false
        }
        if let ws = winSize{
            if newPosition.x + winW > ws.width{
                //print("MiniMap x out of bounds")
                return false
            }
            if newPosition.y + winH > ws.height{
               // print("MiniMap y out of bounds")
                return false
            }
        }
        
        return true
    }
}

struct MiniMap: View {
    @State var mapView = MapView()
    
    @ObservedObject var model = MiniMapModel()
    
    
    @State private var location: CGPoint = CGPoint(x: 195, y: 165)
    @GestureState private var startLocation: CGPoint? = nil // 1
    @State private var offset = CGSize.zero
    
    var btnSize = CGFloat(20)
    
    init(){
        mapView.showZoomControls()
       
    }
    func setListener(listener: MapViewEventListener){
        mapView.model.mapViewListener = listener
        
    }
    
    
    func windowSizeChanged(newSize: CGSize){
        model.winSize = newSize
        print("MiniMap:windowSizeChanged",newSize)
       
        if let vl = model.newLocation{
            var xDiff = CGFloat(0)
            var yDiff = CGFloat(0)
            if vl.x + model.winW > newSize.width{
                print("MiniMap:windowSizeChanged overflow X")
                location = CGPoint(x: 195, y: 165)
                model.listener?.hideMiniMap()
            }
            
            if vl.y + model.winH > newSize.height{
                print("MiniMap:windowSizeChanged overflow Y")
                
                location = CGPoint(x: 195, y: 165)
                model.listener?.hideMiniMap()
                
            }
            
        }
   
    }
    func refresh(){
        if let grp = model.group{
            setGroup(group: grp)
        }
    }
    func setGroup(group: CameraGroup){
        model.group = group
        model.name = group.name
        
        let camsToUse = group.cameras
        
        var items = [ItemLocation]()
        for cam in camsToUse{
           
            if cam.locationLoaded == false {
                cam.loadLocation()
            }
            if let cloc = cam.location{
                let clloc = CLLocationCoordinate2D(latitude: cloc[0], longitude: cloc[1])
                let itemLoc = ItemLocation(camera: cam,isSelected: false,location: clloc)
                items.append(itemLoc)
            }
        }
        
        
        mapView.setItems(items: items,isGroupView: true)
        if let mapBounds = mapView.goto(location: nil){
            let aspect = mapBounds.getAspectRatio()
            print("MiniMap aspect ratio",aspect)
            print("MiniMap latRange",mapBounds.latRange)
            print("MiniMap lngRange",mapBounds.lngRange)
            
           // mapView.model.iconSize = aspect > 2 ? 128 : 64
            
        }//group view uses bounds
        
        DispatchQueue.main.async {
            mapView.showMuted()
        }
        
    }
    
    var simpleDrag: some Gesture {
            DragGesture()
                .onChanged { value in
                    var newLocation = startLocation ?? location // 3
                    newLocation.x += value.translation.width
                    newLocation.y += value.translation.height
                    if model.viewInBounds(newPosition: newLocation){
                        self.location = newLocation
                    }
                }.updating($startLocation) { (value, startLocation, transaction) in
                    startLocation = startLocation ?? location // 2
                }
        }
    var resizeGesture: some Gesture{
        DragGesture(minimumDistance: 0,coordinateSpace: CoordinateSpace.local).onChanged { value in
            
        }
    }
    /*
    func gotoGroupLocation(){
        let center = model.mapCenter
        let cllco = CLLocationCoordinate2D(latitude: center[0], longitude: center[1])
        mapView.goto(location: cllco)
        
    }
    */
    var body: some View {
        VStack{
            HStack{
                Text(model.name).appFont(.sectionHeader)
                    .foregroundColor(.white).padding(.leading)
                Spacer()
              
                Button(action: {
                    model.listener?.hideMiniMap()
                }){
                    Image(systemName: "xmark")
                        .resizable().foregroundColor(.white).frame(width:btnSize-4,height: btnSize-4)
                }.buttonStyle(PlainButtonStyle()).padding(.trailing)
                
                
            }.padding(.top).frame(alignment: .center)
                
                mapView.padding(2)
        }
        .frame(width: model.winW, height: model.winH)
        .background(Color.gray)
        .position(location)
        .gesture(
            simpleDrag
        ).onAppear{
            mapView.mapView.isScrollEnabled = false
            
        }
        
    }
}

struct MiniMap_Previews: PreviewProvider {
    static var previews: some View {
        MiniMap()
    }
}
