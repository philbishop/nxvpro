//
//  NxvSlider.swift
//  NXV-IOS
//
//  Created by Philip Bishop on 31/07/2021.
//

import SwiftUI
protocol NxvSliderListener {
    func nxvSliderChanged(percent: Float,source: NxvSlider)
}
class NxvSliderModel : ObservableObject{
    @Published var percentage: Float = 0
    @Published var innerPercentage: Float = 0
    @Published var minValue = CGFloat(5)
    var id = -1
}
struct NxvSlider : View {

    @ObservedObject var model = NxvSliderModel()
    
    var listener: NxvSliderListener?
    
    func setPercentage(pc: Float){
        DispatchQueue.main.async {
            model.percentage = pc
        }
    }
    func setInnerPercentage(pc: Float){
        print("NxvSlider:setInnerPercentage",pc)
        DispatchQueue.main.async {
            model.innerPercentage = pc > 100 ? 95 : pc
        }
    }
    init(minVal: Int = 5){
        self.model.minValue = CGFloat(minVal)
    }
    init(listener: NxvSliderListener){
        self.listener = listener
    }
    
    var leftMargin: CGFloat = 15.0
    
    var body: some View {
        GeometryReader { geometry in
            // TODO: - there might be a need for horizontal and vertical alignments
            let thumbW =  geometry.size.width - leftMargin
            let lineH = geometry.size.height / 4
            // TODO: - there might be a need for horizontal and vertical alignments
            ZStack(alignment: .leading) {
                Rectangle()
                    .foregroundColor(.gray)
                HStack(spacing: 0){
                    Rectangle()
                        .foregroundColor(.accentColor).frame(width: leftMargin)
                    ZStack(alignment: .leading){
                        Rectangle()
                            .foregroundColor(.red).opacity(0.7)
                            .frame(width: thumbW * CGFloat(model.innerPercentage / 100),height: lineH)
                        
                        HStack(spacing: 0){
                        Rectangle()
                            .foregroundColor(.accentColor)
                        
                            Circle().foregroundColor(.white).frame(width: 15)
                            
                        }.frame(width: thumbW * CGFloat(model.percentage / 100))
                       
                        
                    }
                }
            }
            .cornerRadius(12)
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged({ value in
                    var pc = (value.location.x  / thumbW) * 100.0
                    if pc > 100 {
                        pc = 100.0
                    }else if pc < 0 {
                        pc = 5
                    }
                    print("NxvSlider:location.x",value.location.x,pc)
                    model.percentage =  Float(pc)
                    listener?.nxvSliderChanged(percent: model.percentage,source: self)
                }))
            .onAppear(){
                
                //print("NxvSliderLonAppear sens",self.percentage)
            }
        }
    }
}

