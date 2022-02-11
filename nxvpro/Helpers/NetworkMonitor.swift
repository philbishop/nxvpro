//
//  NetworkMonitor.swift
//  NXV-IOS
//
//  Created by Philip Bishop on 22/08/2021.
//

import SwiftUI
import Network

protocol NetworkStateChangedListener {
    func onNetworkStateChanged(available: Bool)
}

class NetworkMonitor: ObservableObject {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "netMonitor")
    
    var isActive = false
    var isExpensive = false
    var isConstrained = false
    var connectionType = NWInterface.InterfaceType.other
    var listener: NetworkStateChangedListener?
    
    static let shared = NetworkMonitor()
    
    init() {
        monitor.pathUpdateHandler = { path in
            self.isActive = path.status == .satisfied
            self.isExpensive = path.isExpensive
            self.isConstrained = path.isConstrained

            let connectionTypes: [NWInterface.InterfaceType] = [.cellular, .wifi, .wiredEthernet]
            self.connectionType = connectionTypes.first(where: path.usesInterfaceType) ?? .other

            print("NetworkMonitor:pathUpdateHandler",self.connectionType,self.isActive)
            
            DispatchQueue.main.async {
                self.objectWillChange.send()
                self.listener?.onNetworkStateChanged(available: self.isActive)
                
            }
        }
        print("NetworkMonitor:init")
        monitor.start(queue: queue)
    }
}

