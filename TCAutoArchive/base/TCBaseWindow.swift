//
//  TCBaseWindow.swift
//  TCAutoArchive
//
//  Created by apple on 2021/9/7.
//

import Cocoa

class TCBaseWindow: NSWindowController {

    lazy var mainViewController: TCMainViewCtr = {
        let mainVc = TCMainViewCtr()
        return mainVc
    }()
    override func windowDidLoad() {
        super.windowDidLoad()
        
        contentViewController = mainViewController
        window?.delegate = self
    }
    override var windowNibName: NSNib.Name? {
        return NSNib.Name("TCBaseWindow")
    }
    
}
extension TCBaseWindow: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        return true;
    }
}
