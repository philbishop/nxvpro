//
//  MulticamPlayer.swift
//  nxvpro
//
//  Created by Philip Bishop on 25/05/2023.
//

import SwiftUI

class MulticamPlayerModel : ObservableObject{
    @Published var playerReady = false
    @Published var isRecording = false
    @Published var vmdOn = false
    @Published var vmdActive = false
    @Published var playerReadyStatus = ""
    @Published var motionLabel = ""
    
    func reset(){
        playerReady = false
        isRecording = false
        vmdOn = false
        vmdActive = false
        motionLabel = ""
        playerReadyStatus = ""
    }
}

struct MulticamPlayer: View {
    var player: CameraStreamingView
    @ObservedObject var model = MulticamPlayerModel()
    var camera: Camera
    init(camera: Camera,listener: VLCPlayerReady){
        self.camera = camera
        player = CameraStreamingView(camera: camera, listener: listener)
        
    }
    let edges = EdgeInsets(top: 2, leading: 5, bottom: 2, trailing: 5)
    
    func toggleBodyOn(){
        var cam = camera
        cam.vmdOn = !cam.vmdOn
        cam.vmdMode = cam.vmdOn ? 1 : 0
        cam.save()
        
        setVmdOn(cam.vmdOn)
        
        player.playerView.setVmdEnabled(enabled: cam.vmdOn)
    }
    
    func setVmdOn(_ isOn: Bool){
        DispatchQueue.main.async{
            model.vmdOn = isOn
            
            if isOn{
                if camera.vmdMode == 0{
                    model.motionLabel = "MOTION ON"
                }else{
                    if AppSettings.isAnprEnabled(camera){
                        model.motionLabel = "ANPR ON"
                    }else{
                        model.motionLabel = "BODY ON"
                    }
                }
            }
            
        }
    }
    
    var body: some View {
        ZStack(alignment: .top){
            ZStack{
               player
                Text(model.playerReadyStatus)
                    .appFont(.smallCaption)
                    .foregroundColor(Color.white)
                    .hidden(model.playerReady)
            }
            
            HStack(alignment: .top){
                Text(model.motionLabel).foregroundColor(Color.white)
                    .padding(edges)
                    .background(model.vmdActive ? .red : .green)
                    .appFont(.smallFootnote)
                    .cornerRadius(5)
                    .hidden(model.vmdOn == false)
                
                Spacer()
                
                Text(" RECORDING ").foregroundColor(Color.white).background(Color.red)
                   .appFont(.smallFootnote)
                   .padding(10).hidden(model.isRecording == false)
                
            }.frame(alignment: .top)
        }.padding(0)
    }
    
    func doPlay(){
        DispatchQueue.main.async{
            model.reset()
            model.playerReadyStatus = "Connecting to " + camera.getDisplayName() + "..."
            player.play(camera: camera)
        }
    }
    func playerReady(ready: Bool){
        DispatchQueue.main.async{
            model.playerReady = ready
            //refresh vmd and body status
            if camera.vmdOn{
                setVmdOn(true)
            }
        }
    }
    func updateStatus(_ status: String){
        DispatchQueue.main.async{
            model.playerReadyStatus = status
        }
    }
    func vmdActive(isOn: Bool){
        DispatchQueue.main.async{
            model.vmdActive = isOn
        }
    }
}


