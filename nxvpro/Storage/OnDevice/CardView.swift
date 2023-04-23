//
//  CardView.swift
//  NX-V PRO
//
//  Created by Philip Bishop on 12/07/2022.
//

import SwiftUI

class EventsModel : ObservableObject{
    @Published var cards: [CardData]
    @Published var rows: [CardRow]
    @Published var selectedCardId: Int
    @Published var itemsPerRow: Int
    
    var listener: RemoteStorageTransferListener?
    
    init(){
        cards = [CardData]()
        rows = [CardRow]()
        selectedCardId = -1
        itemsPerRow = 3
       
    }
    
    func prepareRows(itemsPerRow: Int){
        rows = [CardRow]()
        self.itemsPerRow = itemsPerRow
        rowIndex = 0
        dataExhausted = false
        startAt = 0
        
        AppLog.write("EventsModel nCards",cards.count)
        
        while dataExhausted == false {
            
            let row = getNextRow(itemsPerRow: itemsPerRow)
            //if dataExhausted == false {
                rows.append( CardRow(rowId: rowIndex, rowData: row))
            //}
        }
        
        AppLog.write("EventsModel nRows",rows.count)
    }
    
    
    var rowIndex = 0
    var dataExhausted = false
    var startAt: Int = 0
    func getNextRow(itemsPerRow: Int) -> [CardData]{
        var  rowData = [CardData]()
        
        let endAt = startAt + itemsPerRow
        
        for i in startAt...endAt {
            if i >= cards.count {
                dataExhausted = true
                break
            }
            rowData.append( cards[i] )
        }
        startAt += itemsPerRow + 1
        rowIndex += 1
        return rowData
    }
    func getPrevCard(card: CardData) -> CardData?{
        if cards.count < 2 {
            return nil
        }
        for i in 1...cards.count-1 {
            if cards[i] == card {
                return cards[i-1]
            }
        }
        
        return nil
    }
    func getNextCard(card: CardData) -> CardData?{
        if cards.count == 0 {
            return nil
        }
        var returnNext = false
        
        for c in cards {
            if c == card {
                returnNext = true
                continue
            }
            if returnNext {
                return c
            }
        }
        return nil
    }
}

//MARK: Views
struct Card: View {
    
    var data: CardData
    var cw: CGFloat
    var ch: CGFloat
    
    var selectedCol = Color(uiColor: .systemBlue)
    var normalCol = Color(uiColor: .label)
    
    @ObservedObject var model: EventsModel
    
    
    init(cardData: CardData,width: CGFloat,model: EventsModel){
        self.data = cardData
        self.cw = width - 10
        self.ch = cw * 0.66
        self.model = model
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack{
                
                Text(data.name).appFont(.caption)
                        .foregroundColor(model.selectedCardId == data.id ? selectedCol : normalCol)
                Spacer()
                
                
                Text(data.timeString()).appFont(.smallCaption)
                        .foregroundColor(model.selectedCardId == data.id ? selectedCol : normalCol)
                
                
            }.padding(1)
            
            Button(action: {
                AppLog.write("Card btn click",self.data.name)
                model.selectedCardId = data.id
                //TO DO need to pass in barLevels
                
                let rt = RecordToken()
                rt.card = data
                model.listener?.doPlay(token: rt)
                
            }){
               
                ZStack(alignment: .topTrailing){
                    Image(uiImage: data.getThumb())
                        .resizable()
                        .cornerRadius(5)
                    
                    let iconCol = data.getEventColor()
                    if data.isEvent{
                        Image(systemName: data.getEventIcon()).resizable()
                            .foregroundColor(iconCol)
                            .background(Color.white)
                            .clipShape(Circle())
                            .frame(width: 20, height: 20)
                            .padding(3)
                            
                    }
                    if data.confidence > 0{
                        VStack{
                            Spacer()
                            Text(data.confidenceString()).appFont(.smallFootnote)
                                .foregroundColor(.white)
                                .background(iconCol)
                                .padding()
                        }
                    }
                }
                
            }
            .buttonStyle(PlainButtonStyle())
            
        }
        .frame(width: cw,height: ch)
    }
    
}
struct EventRow : View {
    
    var rowData: [CardData]
    var itemWidth: CGFloat
    @ObservedObject var model: EventsModel
    
    init(rowData: [CardData],itemWidth: CGFloat,model: EventsModel){
        self.rowData = rowData
        self.itemWidth = itemWidth
        self.model = model
    }
    var body: some View {
        HStack{
            ForEach(rowData, id: \.self) { row in
                Card(cardData: row,width: itemWidth,model: model).padding(1)
                
            }
        }
    }
}

struct EventsUIView: View {
    
    @ObservedObject var model = EventsModel()
    
    var body: some View {
        if model.rows.count == 0 {
            Text("No items to display")
        }else{
            GeometryReader { fullView in
                ScrollView(showsIndicators: /*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/){
                VStack(alignment: .leading){
                    ForEach(model.rows, id: \.self) { row in
                        EventRow(rowData: row.rowData,itemWidth: fullView.size.width / CGFloat(model.itemsPerRow+1),model: model)
                    }
                }
            }
         }
        }
    }
    
    func addCard(card: CardData){
        AppLog.write("eventsuiview:addCard")
        model.cards.append(card)
    }
    func setCards(cards: [CardData]){
        
        AppLog.write("eventsuiview:setCards",cards.count)
        
        model.cards = cards
        
        //fixed size items for now
        let nCols = 3 //Int(ctrlWidth / 200)
        model.prepareRows(itemsPerRow: nCols-1)
    }
    
    func reset(){
        AppLog.write("eventsuiview:reset")
        model.cards = [CardData]()
        model.rows.removeAll()
    }
}
