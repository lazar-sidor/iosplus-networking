//
//  NetworkReachabilityService.swift
//  
//
//  Created by Lazar Sidor on 22.03.2022.
//

import Foundation
import SystemConfiguration
import CoreTelephony

public typealias HttpNetworkReachabilityServiceObserver = ((_ status: HttpNetworkReachabilityMonitor.NetworkConnection) -> Void)?

public class HttpNetworkReachabilityService: NSObject {
    public var status: HttpNetworkReachabilityMonitor.NetworkConnection = .unavailable
    public var currentCellularDataState: CTCellularDataRestrictedState = .restrictedStateUnknown
    private var observerCallback: HttpNetworkReachabilityServiceObserver?

    public override init() {
        super.init()
    }

    public convenience init(observer: HttpNetworkReachabilityServiceObserver) {
        self.init()
        self.observerCallback = observer

        var zeroAddress = sockaddr()
        zeroAddress.sa_len = UInt8(MemoryLayout<sockaddr>.size)
        zeroAddress.sa_family = sa_family_t(AF_INET)
        guard let ref = SCNetworkReachabilityCreateWithAddress(nil, &zeroAddress) else {
            return
        }

        let reachability = HttpNetworkReachabilityMonitor.init(reachabilityRef: ref)
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged(note:)), name: .reachabilityChanged, object: reachability)

        let cellularData = CTCellularData()
        cellularData.cellularDataRestrictionDidUpdateNotifier = { [weak self] (state) in
            self?.currentCellularDataState = state
        }

        do {
            try reachability.startNotifier()
            status = reachability.connection
        } catch {
            print("Could not start reachability notifier")
        }
    }

    public func checkApiReachability(completion: (_ restricted: Bool) -> Void) {
        let isRestricted = status == .unavailable && currentCellularDataState == .restricted

        guard !isRestricted else {
            completion(true)
            return
        }

        completion(false)
    }

    //MARK: - Private

    @objc private func reachabilityChanged(note: Notification) {
        let reachability = note.object as! HttpNetworkReachabilityMonitor
        status = reachability.connection

        if let observerCallback = observerCallback {
            observerCallback!(status)
        }

        switch reachability.connection {
            case .wifi:
                print("Network Reachable via WiFi")
                break
            case .cellular:
               print("Network Reachable via Cellular")
                break
            case .unavailable:
                print("Network not reachable")
                break
            case .none:
                break
        }
    }
}

