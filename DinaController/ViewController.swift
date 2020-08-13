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
    
    private var isSerialConnected: Bool = false {
        didSet {
            updateView()
        }
    }
    
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
    private var lastSentJoystickCommand: String?
    
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
            
            let angle = Double(report.angle)
            var displacement = Double(report.displacement)
                        
            var leftWheelSpeed: Double = 0
            var rightWheelSpeed: Double = 0
            
            let verticalAngleOffset = 20.0
            
            if angle >= 270 && angle < 360 {
                if angle >= 360 - verticalAngleOffset {
                    leftWheelSpeed = 1
                } else {
                    leftWheelSpeed = self.map(x: angle, in_min: 270, in_max: 360, out_min: 0, out_max: 1)
                }
                rightWheelSpeed = 1
            } else if angle >= 0 && angle <= 90 {
                if angle <= verticalAngleOffset {
                    rightWheelSpeed = 1
                } else {
                    rightWheelSpeed = self.map(x: angle, in_min: 0, in_max: 90, out_min: 1, out_max: 0)
                }
                leftWheelSpeed = 1
            } else if angle > 90 && angle <= 180 {
                if angle >= 180 - verticalAngleOffset {
                    rightWheelSpeed = -1
                } else {
                    rightWheelSpeed = self.map(x: angle, in_min: 90, in_max: 180, out_min: 0, out_max: -1)
                }
                leftWheelSpeed = -1
            } else if angle > 180 && angle <= 270 {
                if angle <= 200 {
                    leftWheelSpeed = -1
                } else {
                    leftWheelSpeed = self.map(x: angle, in_min: 180, in_max: 270, out_min: -1, out_max: 0)
                }
                rightWheelSpeed = -1
            }
            
            if displacement < 0.2 {
                displacement = 0
            } else if displacement > 0.8 {
                displacement = 1
            }
                        
            if leftWheelSpeed > 0.8 {
                leftWheelSpeed = 1
            } else if leftWheelSpeed < -0.8 {
                leftWheelSpeed = -1
            }

            if rightWheelSpeed > 0.8 {
                rightWheelSpeed = 1
            } else if rightWheelSpeed < -0.8 {
                rightWheelSpeed = -1
            }
            
            let lws = Int(round(leftWheelSpeed * displacement * 100))
            let rws = Int(round(rightWheelSpeed * displacement * 100))

            self.currentJoystickCommand = "0,\(lws),\(rws),"
        })
    }
    
    private func map(x: Double, in_min: Double, in_max: Double, out_min: Double, out_max: Double) -> Double {
        (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
    }
    
    private func freeJoystickTimer() {
        joystickTimer?.invalidate()
        joystickTimer = nil
    }
    
    private func startJoystickTimer() {
        joystickTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, self.mode == .joystick, let currentJoystickCommand = self.currentJoystickCommand, currentJoystickCommand != self.lastSentJoystickCommand else { return }
            print(currentJoystickCommand)
            self.serial.sendMessageToDevice(currentJoystickCommand)
            self.lastSentJoystickCommand = currentJoystickCommand
            self.currentJoystickCommand = nil
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
                self.serial.sendMessageToDevice("0,0,0,")
                self.lastSentJoystickCommand = "0,0,0,"
                self.startJoystickTimer()
            } else {
                self.freeJoystickTimer()
                self.serial.sendMessageToDevice("1,")
            }
            self.view.isUserInteractionEnabled = true
        }
    }
    
    private func updateView() {
        updateJoystickVisibility()
        linePathButton.setTitle(mode == .joystick ? "Activate line path mode" : "Activate joystick mode", for: .normal)
    }
    
    private func updateJoystickVisibility() {
        joystick.isHidden = mode != .joystick || !isSerialConnected
    }
    
}

extension ViewController: BluetoothSerialDelegate {
    func serialDidChangeState() {
        if serial.isPoweredOn {
            serial.startScan()
        }
    }
    
    func serialDidDisconnect(_ peripheral: CBPeripheral, error: NSError?) {
        isSerialConnected = false
        serial.startScan()
    }
    
    func serialDidDiscoverPeripheral(_ peripheral: CBPeripheral, RSSI: NSNumber?) {
        serial.connectToPeripheral(peripheral)
    }
    
    func serialIsReady(_ peripheral: CBPeripheral) {
        isSerialConnected = true
    }
}
