//
//  SDCardBarChart.swift
//  NX-V
//
//  Created by Philip Bishop on 06/01/2022.
//

import SwiftUI

struct BarChartCell: View {
                
    private var value: Double = 0
    private var barColor: Color = .gray
    private var cornerRadius = 5.0
    
    init(val: Double,col: Color){
        self.value = val
        self.barColor = col
        
        if val.isNaN || val.isInfinite || val < 0{
            self.value = 0
            barColor = .gray
            cornerRadius = 0.0
        }
    }
    var body: some View {
        VStack(alignment: .leading){
            Spacer()
            
            RoundedRectangle(cornerRadius: cornerRadius)
            .fill(barColor)
            .frame(height: value,alignment: .bottom)
        
        }
    }
}
struct VBarChartCell: View {
                
    var value: Double = 0.0
    var barColor: Color
    var label: String
    var valueLabel: String
    
    var body: some View {
        HStack{
            Text(label).appFont(.sectionHeader)
            VStack(alignment: .leading){
                RoundedRectangle(cornerRadius: 5)
                .fill(barColor)
                .frame(width: (value==Double.nan ? 0 : value),alignment: .bottom)
            }
            Text(String(valueLabel)).appFont(.smallCaption)
            Spacer()
        }.hidden(value==0.0)
            .onAppear{
                print("VBarChartCell",value)
            }
    }
}

class BarRep : Identifiable{
    var id = UUID()
    var val: Double
    var label = ""
    var valueLabel = ""
    var index: Int
    init(val: Double,index: Int){
        self.val = val
        self.index = index
    }
}

class SDCardBarChartModel : ObservableObject{
    @Published var bars = [BarRep]()
    
    init(){
        for i in 0...23{
            let bar = BarRep(val: Double(0),index: i)
            //bar.label = String(i)
            bars.append(bar)
        }
    }
    func reset(){
        bars.removeAll()
        for i in 0...23{
            let bar = BarRep(val: Double(0),index: i)
            bar.label = ""
            bars.append(bar)
        }
    }
    func setBarLevels(levels: [Double]){
        bars.removeAll()
        for i in 0...23{
            let bar = BarRep(val: levels[i],index: i)
            bar.label = String(i)
            bars.append(bar)
            
        }
    }
    func itemRemovedAt(hour: Int){
        //TO DO
    }
}

struct SDCardBarChart: View {
   
    @ObservedObject var model = SDCardBarChartModel()
    
    func setBarLevels(levels: [Double]){
        model.setBarLevels(levels: levels)
    }
    func reset(){
        model.reset()
    }
    var body: some View {
        VStack{
            HStack(spacing: 2){
                ForEach(model.bars) { bar in
                    VStack{
                        BarChartCell(val:bar.val,col: .blue).frame(height: 24)
                        Text(bar.label).appFont(.smallFootnote)
                    }
                }
            }//.frame(height: 24)
        }//.frame(height: 32, alignment: .center)
    }
}

struct SDCardCalendar_Previews: PreviewProvider {
    static var previews: some View {
        SDCardBarChart()
    }
}

