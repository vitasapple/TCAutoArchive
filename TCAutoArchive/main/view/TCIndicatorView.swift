//
//  TCIndicatorView.swift
//  TCAutoArchive
//
//  Created by apple on 2021/9/8.
//

import Cocoa

class TCIndicatorView: NSViewController {
    @IBOutlet weak var infoLab: NSTextField!
    
    @IBOutlet weak var indicate: NSProgressIndicator!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = NSColor(white: 0, alpha: 0.7).cgColor
        self.view.layer?.cornerRadius = 5
        indicate.startAnimation(nil)
    }
    
}
