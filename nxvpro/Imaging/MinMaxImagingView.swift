//
//  MinMaxImagingView.swift
//  TestMacUI
//
//  Created by Philip Bishop on 04/01/2022.
//

import SwiftUI

class MinMaxImagingModel : ObservableObject, NxvSliderListener{
    @Published var name = ""
    @Published var valueString =  ""
    @Published var labelColor = Color(UIColor.label)
    
    var initialMode = ""
    
    func flagChanged(){
        labelColor = .accentColor
        
    }
    
    var newValue = 0.0
    
    var iOpt: MinMaxImagingType?
    var listener: ImagingActionListener?
    
    func setImagingType(opt: MinMaxImagingType,listener: ImagingActionListener?){
        self.listener = listener
        self.iOpt = opt
        self.name = opt.name.camelCaseToWords()
        self.valueString = String(opt.value)
        self.labelColor = Color(UIColor.label)
    }
    
    func getSliderValue() -> Float{
        if let opt = iOpt{
            let pcval =  (opt.value/(opt.max-opt.min)) * 100
            return Float(pcval)
        }
        return 0
    }
    func nxvSliderChanged(percent: Float,source: NxvSlider) {
        
        let actual =  iOpt!.min + (Double(percent) * (iOpt!.max-iOpt!.min))/100.0
        newValue = actual
        
        valueString = String(round(actual))
        
        iOpt!.value = round(newValue)
        
        listener?.imagingItemChanged()
        flagChanged()
    }
}

struct MinMaxImagingView: View, RefreshableImagingView{
    
    @ObservedObject var model = MinMaxImagingModel()
    
    @State var slider = NxvSlider()
    
    
    init(opt: MinMaxImagingType,handler: ImagingItemChangeHandler,listener: ImagingActionListener?){
        model.setImagingType(opt: opt,listener: listener)
        slider.setPercentage(pc: model.getSliderValue())
        slider.listener = model
        
        handler.register(optName: opt.name, imagingView: self)
    }
    func updateView(opt: ImagingType) {
        model.setImagingType(opt: opt as! MinMaxImagingType,listener: model.listener)
        slider.setPercentage(pc: model.getSliderValue())
        slider.listener = model
    }
    var body: some View {
        VStack(alignment: .leading){
            HStack{
                Text(model.name).foregroundColor(model.labelColor).appFont(.caption)
                Spacer()
            }
            HStack{
                slider
                Text(model.valueString).foregroundColor(model.labelColor).appFont(.smallCaption).padding(.trailing)
            }.frame(height: 16)
        }.onAppear{
            slider.listener = model
            //print("MinMaxImagingView:onAppear")
        }
    }
}

