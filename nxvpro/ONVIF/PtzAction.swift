//
//  PtzAction.swift
//  NXV-IOS
//
//  Created by Philip Bishop on 19/06/2021.
//

import Foundation

enum PtzAction{
    case up,down,left,right,zoomin,zoomout,none,help,Presets
}

protocol PtzActionHandler{
    func onActionStart(action: PtzAction)
    func onActionEnd(action: PtzAction)
}
