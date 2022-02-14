//
//  LocationManager.swift
//  NX-V
//
//  Created by Philip Bishop on 31/12/2021.
//

import SwiftUI
import MapKit

class LocationManager: NSObject, CLLocationManagerDelegate{
    
    var manager = CLLocationManager()
    var mapView: MapView?
    
    func startIfRequired(mapView: MapView) -> Bool{
        if self.mapView == nil {
            start(mapView: mapView)
            return true
        }
        return false
    }
    
    func start(mapView: MapView){
        self.mapView = mapView
        manager.delegate = self
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if locations.isEmpty{
            return
        }
        print(locations)
        //This is where you can update the MapView when the computer is moved (locations.last!.coordinate)
        
        mapView!.setLocation(location: locations[0])
        manager.stopUpdatingLocation()
   }

   func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error)
   }

   func locationManager(_ manager: CLLocationManager,
                 didChangeAuthorization status: CLAuthorizationStatus) {
       print("location manager auth status changed to: " )
               switch status {
                   case .restricted:
                        print("restricted")
                   case .denied:
                        print("denied")
                   case .authorized:
                        print("authorized")
                   case .notDetermined:
                        print("not yet determined")
                   default:
                        print("Unknown")
           }
    }
}
