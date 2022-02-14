//
//  GlobalMapAlertsView.swift
//  NX-V
//
//  Created by Philip Bishop on 14/01/2022.
//

import SwiftUI

class CameraEvent : Identifiable, Hashable{
    var id: UUID
    var recordToken: RecordToken
    var camera: Camera
    
    init(cam: Camera,rt: RecordToken){
        self.id = rt.id
        self.recordToken = rt
        self.camera = cam
    }
    
    static func == (lhs: CameraEvent, rhs: CameraEvent) -> Bool {
        return lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(recordToken.Time)
    }
}
class GlobalMapAlertsModel : ObservableObject{
    @Published var recentAlerts = [CameraEvent]()
    var parentModel: GlobalMapModel?
    var mapView: CameraLocationView?
    
    var lock = NSLock()
    @Published var selectedAlert: CameraEvent?
    
    func addEvent(camera: Camera,rt: RecordToken){
        lock.lock()
        if recentAlerts.count > 10{
            recentAlerts.remove(at: recentAlerts.count-1)
        }
        var add = true
        for alert in recentAlerts{
            if alert.recordToken.Time == rt.Time{
                add = false
                break
            }
        }
        if add{
            recentAlerts.insert(CameraEvent(cam: camera,rt: rt), at: 0)
        }
        lock.unlock()
        
        //don't auto show
        //parentModel?.alertsHidden = false
    }
}

struct GlobalMapAlertsView : View{
    
    @Environment(\.colorScheme) var colorScheme
    
    @ObservedObject var iconModel = AppIconModel()
    
    @ObservedObject var model = GlobalMapAlertsModel()
    
    
    
    init(){
        recordingEventMonitor.mapAlertModel = model
    }
    
    var body: some View {
        ZStack(alignment: .top){
           
            VStack(alignment: .leading,spacing: 0){
                //Presets
                Text("Recent alerts").fontWeight(.semibold).appFont(.caption).padding(.bottom)
                
                List{
                    ForEach(model.recentAlerts) {alert in
                        VStack{
                            Text(alert.recordToken.Time)
                            Text(alert.camera.getDisplayName())
                        }.onTapGesture {
                            model.selectedAlert = alert
                            if alert.camera.location != nil{
                                model.mapView?.gotoCamera(cam: alert.camera)
                            }
                        }.listRowBackground(model.selectedAlert == alert ? Color(iconModel.selectedRowColor) : Color(.clear)).padding(0)
                    }
                }.listStyle(PlainListStyle())
                
                Spacer()
                HStack(){
                    Spacer()
                    Button("Close",action:{
                        model.parentModel?.alertsHidden = true
                    })
                }
            }.padding()
        }.cornerRadius(15).frame(width: 250, height: 380)
            .padding(10)
            .onAppear(){
                iconModel.initIcons(isDark: colorScheme == .dark)
        }
    }
}



