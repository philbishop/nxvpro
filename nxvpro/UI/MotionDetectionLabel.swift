//
//  MotionDetectionLable.swift
//  NXV-IOS
//
//  Created by Philip Bishop on 01/05/2022.
//

import SwiftUI
import AVFoundation

struct SoundTag: Identifiable,Hashable {
    let id: Int
    var label: String
    
    init(soundId: Int,name: String){
        id = soundId
        label = name
        
    }
    //MARK: Hashable
    func hash(into hasher: inout Hasher) {
            hasher.combine(id)
    }
}
class MotionDetectionLabelModel : ObservableObject{
    
    var soundLabels = ["No sound","Alarm","Telegraph","News flash","SMS"]
    var soundIds = [0,1304,1033,1028,1010]
    @Published var sounds = [SoundTag]()
    @Published var selectedSound = 0
    @Published var backgroundColor = Color.green
    @Published var motionLabel = "MOTION ON"
    
    init(){
        for i in 0...soundIds.count-1{
            sounds.append(SoundTag(soundId: soundIds[i], name: soundLabels[i]))
        }
        if(UserDefaults.standard.object(forKey: Camera.VMD_AUDIO_KEY) != nil){
            selectedSound = UserDefaults.standard.integer(forKey: Camera.VMD_AUDIO_KEY)
        }
    }
    
   
    
}
struct MotionDetectionLabel: View {
    
    @ObservedObject var model = MotionDetectionLabelModel()
    let edges = EdgeInsets(top: 2, leading: 5, bottom: 2, trailing: 5)

    func setVmdMode(camera: Camera){
        let vmdMode = camera.vmdMode
        if vmdMode == 0{
            model.motionLabel = "MOTION ON"
        }else{
            
            if AppSettings.isAnprEnabled(camera){
                model.motionLabel = "ANPR ON"
            }else{
                model.motionLabel = "BODY ON"
            }
        }
        print("SingleCameraModel:setVmdMode",vmdMode)
    }
    func setActive(isStart: Bool){
        model.backgroundColor = isStart ? Color.red : Color.green
    }
    
    var body: some View {
        Text(model.motionLabel).appFont(.smallCaption)
            .foregroundColor(Color.white)
            .padding(edges)
            .background(model.backgroundColor)
            .cornerRadius(5)
            .contextMenu {
                ForEach(model.sounds, id: \.self){ s in
                    Button {
                        AppLog.write("VMD context menu invoked",s.id,s.label)
                        model.selectedSound = s.id
                        UserDefaults.standard.set(s.id,forKey: Camera.VMD_AUDIO_KEY)
                        if s.id > 0 {
                            DispatchQueue.main.async{
                                AudioServicesPlayAlertSound(SystemSoundID(model.selectedSound))
                            }
                            
                            RemoteLogging.log(item: "Motion detection sound changed " + s.label)
                        }
                    } label: {
                        Label(s.label, systemImage: model.selectedSound == s.id ? "checkmark" : "")
                    }
                }
            }
    }
}

struct MotionDetectionLable_Previews: PreviewProvider {
    static var previews: some View {
        MotionDetectionLabel()
    }
}
