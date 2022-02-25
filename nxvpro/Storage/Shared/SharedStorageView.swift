//
//  SharedStorageView.swift
//  nxvpro
//
//  Created by Philip Bishop on 25/02/2022.
//

import SwiftUI

class SharedStorageModel : ObservableObject{
    @Published var showSetup = true
}

struct SharedStorageView: View {
    
    @ObservedObject var model = SharedStorageModel()
    
    var rangeView = RemoteStorageConfigView()
  
    var statsView = SDCardStatsView()
    var searchView = RemoteStorageSearchView()
    var rightPaneWidth = CGFloat(410.0)
    var barChart = SDCardBarChart()
    
    var body: some View {
        ZStack(){
            GeometryReader { fullView in
                let isLanscape = fullView.size.width - 320 > 600
                HStack{
                    VStack{
                        Text("Shared folder")
                        searchView
                        List{
                            /*
                            ForEach(model.resultsByHour){ rc in
                                RecordCollectionView(rc: rc,camera: searchView.model.camera!,transferListener: self)
                            }
                             */
                        }
                       
                       Spacer()
                       
                        HStack{
                            barChart.frame(height: 24,alignment: .center)
                        }.padding()
                    }
                    Divider()
                    if isLanscape{
                        Divider()
                        VStack{
                            if model.showSetup{
                                Text("Setup").appFont(.smallTitle).padding()
                 //               Text(model.storageHelp).appFont(.sectionHeader).padding()
                            }else{
                                Text("Statistics").appFont(.smallTitle)
                   //             statsView
                            }
                            Spacer()
                            //Text("Settings").appFont(.sectionHeader)
                            //ftpSettings
                        }.frame(width: rightPaneWidth)
                    }
                }
                Text("Shared storage view")
                }
        
        }
    }
}

struct SharedStorageView_Previews: PreviewProvider {
    static var previews: some View {
        SharedStorageView()
    }
}
