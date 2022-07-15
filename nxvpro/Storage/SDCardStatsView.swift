//
//  SDCardStatsView.swift
//  NX-V
//
//  Created by Philip Bishop on 07/01/2022.
//

import SwiftUI

class SDCardStatsViewModel : ObservableObject{
    var camera: Camera?
    var storageType = StorageType.onboard
    @Published var dayBars = [BarRep]()
}

struct SDCardStatsView: View {
    var barChart = SDCardBarChart()
    
    @ObservedObject var model = SDCardStatsViewModel()
    
    func setCamera(camera: Camera,storageType:StorageType = StorageType.onboard){
        print("SDCardStatsView:setCamera")
        model.camera = camera
        model.storageType = storageType
        if camera.recordingProfile != nil || storageType != .onboard{
            refreshStats()
        }
        //reset saved states
        RecordCollectionStateFactory.reset()
    }
    func refreshStatsFrom(tokens: [RecordToken]){
        print("SDCardStatsView:refreshStatsFrom [RecordToken")
        let stats = SDCardStatsFactory()
        stats.analyzeTokens(tokens: tokens)
        handelStats(stats: stats)
    }
    
    func refreshStats(){
        print("SDCardStatsView:refreshStats")
        let stats = SDCardStatsFactory()
        if let camera = model.camera{
            let  camUid = camera.isVirtual ? camera.getBaseFileName() : camera.getStringUid()
            let rp = camera.recordingProfile
            let token = rp == nil ? "" : rp!.recordingToken
            stats.analyzeCache(cameraUid: camUid,profileToken: token,storageType: model.storageType)
            
            handelStats(stats: stats)
        }
        
    }
    private func handelStats(stats: SDCardStatsFactory){
        let dStats = stats.dayStats
        
        var barLevels = [Double]()
        for ds in dStats{
            var dlevel = 24 * (ds.percentOfMax / 100)
            if dlevel.isNaN{
                dlevel = 0.0
            }
            barLevels.append(dlevel)
        }
        
        barChart.reset()
        barChart.model.setBarLevels(levels: barLevels)
        
        model.dayBars.removeAll()
        
        
        var dayBars = [BarRep]()
        for ds in stats.eventDayStats{
            var dlevel = 124 * (ds.percentOfMax / 100)
            if dlevel.isNaN{
                dlevel = 0.1
            }
            let barRep = BarRep(val: dlevel,index: -1)
            barRep.label = ds.label
            barRep.valueLabel = String(ds.count)
            dayBars.append(barRep)
        }
        
        let sortedBars = dayBars.sorted{
            $1.val < $0.val
        }
        for bar in sortedBars{
            model.dayBars.append(bar)
            print("StatsView",bar.label,bar.valueLabel)
        }
    }
    
    var body: some View {
        VStack{
            Text("Daily overview").appFont(.sectionHeader)
            barChart
            Text("Events per hour").appFont(.smallFootnote)
            
            Text("Events per day").appFont(.sectionHeader).padding(.top)
            ScrollView{
                ForEach(model.dayBars) { bar in
                    VBarChartCell(value: bar.val,barColor: .blue,label: bar.label,valueLabel: bar.valueLabel)
                }
            }
        }
    }
}

struct SDCardStatsView_Previews: PreviewProvider {
    static var previews: some View {
        SDCardStatsView()
    }
}
