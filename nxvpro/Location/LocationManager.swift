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
    var enabled = false
    
    func startIfRequired(mapView: MapView) -> Bool{
        if self.mapView == nil && self.enabled{
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
        AppLog.write(locations)
        //This is where you can update the MapView when the computer is moved (locations.last!.coordinate)
        
        mapView!.setLocation(location: locations[0])
        manager.stopUpdatingLocation()
   }

   func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        AppLog.write(error)
   }

   func locationManager(_ manager: CLLocationManager,
                 didChangeAuthorization status: CLAuthorizationStatus) {
       AppLog.write("location manager auth status changed to: " )
               switch status {
                   case .restricted:
                        AppLog.write("restricted")
                   case .denied:
                        AppLog.write("denied")
                   case .authorized:
                        AppLog.write("authorized")
                   case .notDetermined:
                        AppLog.write("not yet determined")
                   default:
                        AppLog.write("Unknown")
           }
    }
}
