//
//  ViewController.swift
//  DinaController
//
//  Created by Luka Gabrić on 02/08/2020.
//  Copyright © 2020 LG. All rights reserved.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController {
    
    private var serial: BluetoothSerial!
    @IBOutlet private weak var joystick: JoyStickView!
    @IBOutlet private weak var linePathButton: UIButton!
    private var joystickTimer: Timer?
    
    enum Mode {
        case path
        case joystick
    }
    
    private var mode: Mode! {
        didSet {
            modeDidChange()
        }
    }
    
    private var currentJoystickCommand: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        serial = BluetoothSerial(delegate: self)

        configureJoystick()
        
        updateView()
        
        mode = .joystick
    }
    
    private func configureJoystick() {
        joystick.monitor = .polar(monitor: { [weak self] report in
            guard let self = self else { return }
            
            let angle = Float(report.angle)
            var displacement = Float(report.displacement)
                        
            var leftWheelSpeed: Float = 0
            var rightWheelSpeed: Float = 0
            
            if angle >= 270 && angle < 360 {
                leftWheelSpeed = self.map(x: angle, in_min: 270, in_max: 360, out_min: 0, out_max: 1)
                rightWheelSpeed = 1
            } else if angle >= 0 && angle <= 90 {
                leftWheelSpeed = 1
                rightWheelSpeed = self.map(x: angle, in_min: 0, in_max: 90, out_min: 1, out_max: 0)
            } else if angle > 90 && angle <= 180 {
                leftWheelSpeed = -1
                rightWheelSpeed = self.map(x: angle, in_min: 90, in_max: 180, out_min: 0, out_max: -1)
            } else if angle > 180 && angle <= 270 {
                leftWheelSpeed = self.map(x: angle, in_min: 180, in_max: 270, out_min: -1, out_max: 0)
                rightWheelSpeed = -1
            }
            
            if displacement < 0.2 {
                displacement = 0
            }
                        
            if leftWheelSpeed > 0.9 {
                leftWheelSpeed = 1
            } else if leftWheelSpeed < -0.9 {
                leftWheelSpeed = -1
            }

            if rightWheelSpeed > 0.9 {
                rightWheelSpeed = 1
            } else if rightWheelSpeed < -0.9 {
                rightWheelSpeed = -1
            }

            self.currentJoystickCommand = "0,\(Int(leftWheelSpeed * displacement * 100)),\(Int(rightWheelSpeed * displacement * 100)),"
        })
    }
    
    private func map(x: Float, in_min: Float, in_max: Float, out_min: Float, out_max: Float) -> Float {
        (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
    }
    
    private func freeJoystickTimer() {
        joystickTimer?.invalidate()
        joystickTimer = nil
    }
    
    private func startJoystickTimer() {
        joystickTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, self.mode == .joystick, let currentJoystickCommand = self.currentJoystickCommand else { return }
            self.serial.sendMessageToDevice(currentJoystickCommand)
        }
    }
        
    @IBAction func linePathModeAction(_ sender: Any) {
        mode = mode == .joystick ? .path : .joystick
    }
    
    private func modeDidChange() {
        view.isUserInteractionEnabled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.updateView()
            if self.mode == .joystick {
                self.startJoystickTimer()
            } else {
                self.freeJoystickTimer()
                self.serial.sendMessageToDevice("1,")
            }
            self.view.isUserInteractionEnabled = true
        }
    }
    
    private func updateView() {
        joystick.isHidden = mode == .path
        linePathButton.setTitle(mode == .joystick ? "Activate line path mode" : "Activate joystick mode", for: .normal)
    }
    
}

extension ViewController: BluetoothSerialDelegate {
    func serialDidChangeState() {
        if serial.isPoweredOn {
            serial.startScan()
        }
    }
    
    func serialDidDisconnect(_ peripheral: CBPeripheral, error: NSError?) {
        joystick.isHidden = true
        serial.startScan()
    }
    
    func serialDidDiscoverPeripheral(_ peripheral: CBPeripheral, RSSI: NSNumber?) {
        serial.connectToPeripheral(peripheral)
    }
    
    func serialIsReady(_ peripheral: CBPeripheral) {
        joystick.isHidden = false
    }
}
