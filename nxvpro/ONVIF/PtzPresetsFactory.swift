//
//  PtzPresetsFactory.swift
//  NX-V
//
//  Created by Philip Bishop on 02/01/2022.
//

class PtzPresetsFactory{
    
    /*
     ["tptz:Preset/Preset1/tt:Name/Marked Position 1", "tptz:Preset/tptz:Preset/Preset2/tt:Name/Marked Position 2", "tptz:Preset/tptz:Preset/tptz:Preset/Preset4/tt:Name/MOffice", "tptz:Preset/tptz:Preset/tptz:Preset/tptz:Preset/Preset3/tt:Name/Hall"]
     */
    
    var presets = [PtzPreset]()
    
    func parsePresets(xmlPaths: [String],attribs: [String]){
        for i in 0...xmlPaths.count-1{
            let path = xmlPaths[i]
            let token = attribs[i]
            let parts = path.components(separatedBy: "/")
            if parts.count == 3{
                //tptz:Preset
                //tt:Name
                //Marked Position 1
                let id = presets.count
                let preset = PtzPreset(id: id,token: token,name: parts[2])
                presets.append(preset)
            }
        }
    }
}
