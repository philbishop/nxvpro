//
//  AppIconModel.swift
//  NX-V
//
//  Created by Philip Bishop on 01/06/2021.
//

import Foundation
import SwiftUI

class AppIconModel : ObservableObject{
    
    @Published var selectedRowColor = UIColor(red: 0.9, green: 0.9, blue: 0.9,alpha: 0.8)
    @Published var mainBackgroundColor = UIColor(red: 64/255, green: 64/255, blue: 64/255,alpha: 0.8)
    @Published var multicamBackgroundColor = UIColor(red: 64/255, green: 64/255, blue: 64/255,alpha: 1.0)
    
    @Published  var iconSize = CGFloat(34)
    @Published  var largeIconSize = CGFloat(42)
    
    @Published var nxvIcon = "nxv_launch_light"
    @Published var nxvTitleIcon = "nxv_titlebar"
    
    @Published var infoIcon = "help_light"
    @Published var closeIcon = "close_light"
    
    @Published var cloudIcon = "cloud_light"
    @Published var cloudOnIcon = "cloud_on_light"
    @Published var activeCloudIcon = "cloud_light"
    
    
    @Published var ptzIcon = "ptz_light"
    @Published var settingsIcon = "settings_light"
    @Published var vmdIcon = "vmd_light"
    @Published var vmdOnIcon = "vmd_on"
    @Published var vmdAlertIcon = "vmd_alert"
    
    @Published var rotateIcon = "rotate_light"
    @Published var volOnIcon = "vol_on_light"
    @Published var volOffIcon = "vol_off_light"
    
    @Published var recordIcon = "start_recording"
    
    @Published var activeVmdIcon = "vmd_light"
    @Published var activeVolumeIcon = "vol_on_light"
     
    //VMD
    @Published var vidOffIcon = "vidoff_light"
    @Published var vidOnIcon = "vidon_light"
    @Published var activeVidIcon = "vidoff_light"
    
    
    //ptz
    @Published var ptzLeft = "ptz_left_light"
    @Published var ptzRight = "ptz_right_light"
    @Published var ptzUp = "ptz_up_light"
    @Published var ptzDown = "ptz_down_light"
    @Published var ptzZoomIn = "ptz_zoom_in_light"
    @Published var ptzZoomOut = "ptz_zoom_out_light"
    @Published var ptzPresets = "ptz_preset_light"
    
    //video cpntrols
    @Published var playIcon: String = "play_light"
    @Published var pauseIcon: String = "pause_light"
    @Published var activePlayIcon: String = "play_light"
    
    //favs
    @Published var favIcon = "fav_light"
    @Published var selectedFavIcon = "fav_selected"
    @Published var activeFavIcon = "fav_selected"
    
    //other
    @Published var shareIcon: String = "share_light"
    @Published var globeIcon: String = "globe_light"
    @Published var exportIcon: String = "export_light"
    @Published var sidebarIcon: String = "sidebar_light"
    @Published var imagingIcon: String = "hsliders_light"
    
    @Published var favIconLookup = [Int: String]()
    
    //camera visibility
    @Published var visibleSystemIcon = "checkmark.diamond.fill"
    @Published var hiddenSystemIcon = "checkmark.diamond"
    
    @Published var visibiltyIconLookup = [Int: String]()
    
   
    
    var isDark = false
    func initIcons(isDark: Bool){
        self.isDark = isDark
        
        if isDark {
            selectedRowColor = UIColor(red: 0.25, green: 0.25, blue: 0.25,alpha: 0.8)
        }else{
           selectedRowColor = UIColor(red: 0.9, green: 0.9, blue: 0.9,alpha: 0.8)
        }
        let tag = getTag()
        
        nxvIcon = "nxv_launch"+tag
        
        infoIcon = "help"+tag
        closeIcon = "close"+tag
        
        cloudIcon = "cloud"+tag
        cloudOnIcon = "cloud_on"+tag
        activeCloudIcon = cloudIcon
        settingsIcon = "settings"+tag
        
        vidOffIcon = "vidoff"+tag
        vidOnIcon = "vidon"+tag
        activeVidIcon = vidOffIcon
        
        ptzIcon = "ptz"+tag
        vmdIcon = "vmd"+tag
        activeVmdIcon = vmdIcon
        rotateIcon = "rotate"+tag
        volOnIcon = "vol_on"+tag
        volOffIcon = "vol_off"+tag
        activeVolumeIcon = volOnIcon
        
        ptzLeft = "ptz_left"+tag
        ptzRight = "ptz_right"+tag
        ptzUp = "ptz_up"+tag
        ptzDown = "ptz_down"+tag
        ptzZoomIn = "ptz_zoom_in"+tag
        ptzZoomOut = "ptz_zoom_out"+tag
        ptzPresets = "ptz_preset"+tag
        
        playIcon = "play"+tag
        pauseIcon = "pause"+tag
        activePlayIcon = playIcon
        
        shareIcon = "share"+tag
        globeIcon =  "globe"+tag
        
        exportIcon = "export"+tag
        sidebarIcon = "sidebar"+tag
        favIcon = "fav"+tag
        
        imagingIcon = "hsliders"+tag
        
        //now added dynamically on camera added/updated
        //add 50 empty cameras
       
        for i in 0...50 {
            favIconLookup[i] = favIcon
            favIconLookup[i+Camera.VCAM_BASE_ID] = favIcon
               
            visibiltyIconLookup[i] = visibleSystemIcon
            visibiltyIconLookup[i+Camera.VCAM_BASE_ID] = visibleSystemIcon
        }
        if #available(iOS 15, *) {
            visibleSystemIcon = "checkmark.diamond.fill"
            hiddenSystemIcon = "checkmark.diamond"
        } else {
            visibleSystemIcon = "checkmark.circle.fill"
            hiddenSystemIcon = "checkmark.circle"
        }
    }
    
    func getTag() -> String{
        var tag = "_light"
        if self.isDark {
            tag = "_dark"
        }
        return tag
    }
    func visibilityStatusChanged(camera: Camera){
        if camera.isNvr(){
            for vcam in camera.vcams{
                visibilityStatusChanged(camera: vcam)
            }
            return
        }
        visibiltyIconLookup[camera.id] = camera.vcamVisible ? visibleSystemIcon : hiddenSystemIcon
    }
    func favStatusChanged(camera: Camera){
        if camera.isNvr(){
            for vcam in camera.vcams{
                favStatusChanged(camera: vcam)
            }
            return
        }
        let isFav = camera.isFavorite
       
        
        if isFav{
            activeFavIcon = selectedFavIcon
        }else{
            activeFavIcon = favIcon
        }
        AppLog.write("AppIconModel:favStatusChanged",camera.name,activeFavIcon)
        favIconLookup[camera.id] = activeFavIcon
    }
    func vidOnStatusChanged(isOn: Bool){
        activeVidIcon = isOn ? vidOnIcon : vidOffIcon
    }
    
    func playStatusChange(playing: Bool){
        
        activePlayIcon = playing ? pauseIcon : playIcon
    }
    
    func volumeStatusChange(on: Bool){
        let tag = getTag()
        if on {
            activeVolumeIcon = "vol_on"+tag
        }else{
            activeVolumeIcon = "vol_off"+tag
        }
    }
    
    func recordingStatusChange(status: Bool){
        if status {
            recordIcon = "stop_recording"
        }else{
            recordIcon = "start_recording"
        }
    }
    
    func cloudStatusChanged(on: Bool){
        let tag = getTag()
        
        let icon = on ? "cloud_on" : "cloud"
        activeCloudIcon = icon+tag
    }
    
    func vmdStatusChange(status: Int){
        switch status{
        case 0:
            activeVmdIcon = vmdIcon
        case 1:
            activeVmdIcon = vmdOnIcon
            break
        case 2:
            activeVmdIcon = vmdAlertIcon
            break
        default:
            var tag = "_light"
            if self.isDark {
                tag = "_dark"
            }
            activeVmdIcon = "vmd"+tag
            break
        }
    }
}
