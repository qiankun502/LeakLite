//
//  MainViewController.swift
//  CompassCompanion
//
//  Created by Rick Smith on 04/07/2016.
//  Copyright © 2016 Rick Smith. All rights reserved.
//

import UIKit
import CoreBluetooth
import Charts
import Foundation

class MainViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {
    var manager:CBCentralManager? = nil
    var mainPeripheral:CBPeripheral? = nil
    var mainCharacteristic:CBCharacteristic? = nil
    var time=0
    var rxState = 0
    var stringAll=""
    var mblreceivedSQ = true
    var dollars = [0]
    var yVals : [ChartDataEntry] = [ChartDataEntry]()
    var mblTesting = false                   //IGLS in testing status
    var mblDeviceConnected = false
    var mIntervalCount = 0
    var mInterval = 1              //command send out interval
    var mblSetupUpload = false

    var PastTime = NSDate().timeIntervalSince1970
    
    @IBOutlet weak var lbltimer: UILabel!
    
    @IBOutlet weak var lblRunningTime: UILabel!
    
    @IBOutlet weak var lblFlowReading: UILabel!
    
    @IBOutlet weak var lblIntPresReading: UILabel!
    @IBOutlet weak var lblExtPresReading: UILabel!
    @IBOutlet weak var lblTempReading: UILabel!
    
    @IBOutlet weak var lblFlowUnit: UILabel!
    @IBOutlet weak var lblPresUnit: UILabel!
    @IBOutlet weak var lblExtPresUnit: UILabel!
    @IBOutlet weak var lblTemperatureUnit: UILabel!

    @IBOutlet weak var lblFlowRange: UILabel!
    @IBOutlet weak var lblPresRange: UILabel!
    @IBOutlet weak var lblExPresRange: UILabel!
    
    @IBOutlet weak var lblStatus: UILabel!
 
    @IBOutlet weak var BtnTT: UIButton!
    
    let BLEService = "49535343-FE7D-4AE5-8FA9-9FAFD205E455"//"DFB0"
    let BLECharacteristic = "49535343-8841-43F4-A8D4-ECBE34729BB3"//DFB1"
     let BLECharacteristicRec = "49535343-1E4D-4BD9-BA61-23C647249616"
     var timer = Timer()
    
    @IBOutlet weak var recievedMessageText: UILabel!
    
    @IBOutlet weak var lineChartView: LineChartView!
    override func viewDidLoad() {
        super.viewDidLoad()
        manager = CBCentralManager(delegate: self, queue: nil);
        customiseNavigationBar()
        //self.lineChartView.delegate = self
        self.lineChartView.chartDescription?.textColor = UIColor.white
        self.lineChartView.gridBackgroundColor = UIColor.gray
        
        
        lineChartView.setVisibleXRange(minXRange: 0, maxXRange: 100)
        self.lineChartView.setVisibleXRangeMaximum(50)
        self.lineChartView.backgroundColor = UIColor.yellow
        let xAxis=lineChartView.xAxis
        xAxis.axisMinimum=0
        xAxis.axisMaximum=10
 
        yVals.append(ChartDataEntry(x: Double(0), y: 0))

        //setChartData(months:months)
        setChartData()
        
        timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(MainViewController.sendCommand), userInfo: nil, repeats: true)
        
    }
    ////////////////////////////////////////////////////////////////////////////////////////////////
    func sendCommand()
    {
        if (mainPeripheral != nil)
        {
          //  mInterval = 2
            var Command = "!00SQ1;5\r"
            var dataToSend = Command.data(using: String.Encoding.utf8)
            if (mblDeviceConnected == true)                             //Bluetooth Device is connected
            {
                if  (mblreceivedSQ == true)                             //Last command response is received
                {
                    do{
                        if (mIntervalCount>mInterval)//mInterval is used to adjust the how fast to send out the command
                        {
                            if (mblSetupUpload == true)                     //communication to upload setup
                            {
                                mInterval=0
                   //             mstartbutton disable
                                if (mIntSetupUploadIndex != mInSetupReceiveIndex)
                                {
                                    mInSetupReceiveIndex = mIntSetupUploadIndex
                                    Command = mCommand[mIntSetupUploadIndex]! + "\r"
                                    dataToSend = Command.data(using: String.Encoding.utf8)
                                    mainPeripheral?.writeValue(dataToSend!, for: mainCharacteristic!, type: .withResponse)
                                    print("send out \(Command)!")
                                }
                                
                                let tempi = mIntSetupUploadIndex % 10
                                var tempstr:String = ""
                                for i in 0 ..< tempi
                                {
                                    tempstr = tempstr + "."
                                }
                                lblStatus.text = "Uploading " + tempstr
                                lblStatus.backgroundColor = UIColor(white: 1, alpha: 0)
                                
                            }
                            else
                            {
                                mInterval=2
                                mainPeripheral?.writeValue(dataToSend!, for: mainCharacteristic!, type: .withResponse)
                                mblreceivedSQ = false
                                mIntervalCount = 0
                            }
                        }
                        
                    }
 
                }
                else if (mIntervalCount>(3*mInterval))              // if wait too long time, resend the command again
                {
                    mblreceivedSQ = true
                }
                mIntervalCount = mIntervalCount + 1
                
            }
   
        }
        else
        {
            mblSetupUpload=true
            mIntSetupUploadIndex=1
            mInSetupReceiveIndex=0
            mIntervalCount=0
            mInterval=10 //wait sometime when connect is just established
            
        }
        SetupUpdate()
    }
    ////////////////////////////////////////////////////////////////////
    
    
    @IBAction func StartTest(_ sender: UIButton)
    {
        let Command = "!00SM1;8\r"
        let dataToSend = Command.data(using: String.Encoding.utf8)
        
        if (mainPeripheral != nil) {
            mainPeripheral?.writeValue(dataToSend!, for: mainCharacteristic!, type: .withResponse)
        }
        PastTime = NSDate().timeIntervalSince1970
        yVals=[ChartDataEntry]()
    }
    
    @IBAction func TestTypeSwitch(_ sender: Any)
    {
        let Command = "!00SM1;6\r"
        let dataToSend = Command.data(using: String.Encoding.utf8)
        
        if (mainPeripheral != nil) {
            mainPeripheral?.writeValue(dataToSend!, for: mainCharacteristic!, type: .withResponse)
        }
    }
    
    
    @IBAction func StopTest(_ sender: UIButton)
    {
        let Command = "!00SM1;9\r"
        let dataToSend = Command.data(using: String.Encoding.utf8)
        
        if (mainPeripheral != nil) {
            mainPeripheral?.writeValue(dataToSend!, for: mainCharacteristic!, type: .withResponse)
        }

    }
    
////////////////////////////////////////////////////////////////////////////////////////////////////////////
    @IBAction func CloseAPP(_ sender: UIButton) {
        var messagestr:String
        if (mainPeripheral == nil)
        {
            messagestr = "Are you sure to exit LeakLite APP?"
        }
        else
        {
            messagestr = "Please disconnect bluetooth before close!"
        }
        let refreshAlert = UIAlertController(title: "LeakLite Close Confirmation!", message: messagestr, preferredStyle: UIAlertControllerStyle.alert)
        
        refreshAlert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { (action: UIAlertAction!) in
            print("Handle Ok logic here")
            //mainPeripheral.
            if (self.mainPeripheral == nil)
            {
                exit(0)
            }
        }))
        
        refreshAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (action: UIAlertAction!) in
            print("Handle Cancel Logic here")
        }))
        
        present(refreshAlert, animated: true, completion: nil)
        //exit(0)
    }
//////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    func customiseNavigationBar () {
        
        self.navigationItem.rightBarButtonItem = nil
        
        let rightButton = UIButton()
        
        if (mainPeripheral == nil) {
            rightButton.setTitle("Scan", for: [])
            mblDeviceConnected = false
            rightButton.setTitleColor(UIColor.blue, for: [])
            rightButton.frame = CGRect(origin: CGPoint(x: 0,y :0), size: CGSize(width: 60, height: 30))
            rightButton.addTarget(self, action: #selector(self.scanButtonPressed), for: .touchUpInside)
        } else {
            rightButton.setTitle("Disconnect", for: [])
            
            rightButton.setTitleColor(UIColor.blue, for: [])
            rightButton.frame = CGRect(origin: CGPoint(x: 0,y :0), size: CGSize(width: 100, height: 30))
            rightButton.addTarget(self, action: #selector(self.disconnectButtonPressed), for: .touchUpInside)
        }
        
        let rightBarButton = UIBarButtonItem()
        rightBarButton.customView = rightButton
        self.navigationItem.rightBarButtonItem = rightBarButton
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if (segue.identifier == "scan-segue") {
            let scanController : ScanTableViewController = segue.destination as! ScanTableViewController
            
            //set the manager's delegate to the scan view so it can call relevant connection methods
            manager?.delegate = scanController
            scanController.manager = manager
            scanController.parentView = self
        }
        
    }
    
    // MARK: Button Methods
    func scanButtonPressed() {
        performSegue(withIdentifier: "scan-segue", sender: nil)
    }
    
    func disconnectButtonPressed() {
        //this will call didDisconnectPeripheral, but if any other apps are using the device it will not immediately disconnect
        manager?.cancelPeripheralConnection(mainPeripheral!)
    }
    
    @IBAction func sendButtonPressed(_ sender: AnyObject) {
        if (mainPeripheral != nil) {
        sendCommand()
        }
            
       // mainPeripheral?.readValue(for: <#T##CBCharacteristic#>)
    }
    

    
    // MARK: - CBCentralManagerDelegate Methods    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        mainPeripheral = nil
        customiseNavigationBar()
        print("Disconnected" + peripheral.name!)
    }
    
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print(central.state)
    }
    
    // MARK: CBPeripheralDelegate Methods
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        for service in peripheral.services! {
            
            print("Service found with UUID: " + service.uuid.uuidString)
            //Bluno Service
            if (service.uuid.uuidString == BLEService) {
                peripheral.discoverCharacteristics(nil, for: service)
            }
            
        }
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?)
    {
 
        if (service.uuid.uuidString == BLEService) {
            
            for characteristic in service.characteristics! {
                if (characteristic.uuid.uuidString == BLECharacteristicRec) {
                    peripheral.readValue(for: characteristic)
                    peripheral.setNotifyValue(true, for: characteristic)
                    //  peripheral.readValueForCharacteristic(for: characteristic)
                    print("Found a Device notify Characteristic")
                    
                }
                    
                if (characteristic.uuid.uuidString == BLECharacteristic) {
                   // peripheral.readValue(for: characteristic)
                    print("Found a Device Manufacturer Name Characteristic")
                    mainCharacteristic=characteristic
                    mblDeviceConnected = true
                    mblSetupUpload = true
                }
                //else if (characteristic.uuid.uuidString == "2A23") {
                    //peripheral.readValue(for: characteristic)
                //    print("Found System ID")
               // }
            }
        }
    }
  
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?)
    {
        if (characteristic.uuid.uuidString == BLECharacteristic)
        {
            //data recieved
            if(characteristic.value != nil)
            {
                let stringValue = String(data: characteristic.value!, encoding: String.Encoding.utf8)!
                recievedMessageText.text = stringValue
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?)
    {
        var stringValue=String()
        
        if (characteristic.uuid.uuidString == BLECharacteristicRec)
        {
            //data recieved
            if(characteristic.value != nil)
            {
               stringValue = String(data: (characteristic.value)!, encoding: String.Encoding.utf8)!
                //stringValue = String(describing: characteristic.value)
                if (stringValue.contains("SQ")) || (stringValue.contains("RU")) || (stringValue.contains("RT"))||(stringValue.contains("RK"))||(stringValue.contains("RV"))||(stringValue.contains("RQ") )||(stringValue.contains("SA"))||(stringValue.contains("RL"))||(stringValue.contains("RS"))
                {
                    stringAll=""
                    rxState=GlobalConstants.RX_START
                }
                if (stringValue.contains("\r"))||(stringValue.contains("\n"))
                {
                    stringAll=stringAll+stringValue
                    rxState=GlobalConstants.RX_DONE
                    recievedMessageText.text = stringAll
                    ParseMessage(Message: stringAll)
                }
                else
                {
                    stringAll=stringAll+stringValue
                }
            }
        }
    }
    
    func readValue(characteristic: CBCharacteristic!) {
        if characteristic != nil {
            mainPeripheral?.readValue(for: characteristic)
            mainPeripheral?.setNotifyValue(true, for: characteristic)
        } else {
            mainPeripheral?.discoverServices(nil)
        }
    }
    ////////////////////////////////////////////////////////////////////////////////////////
    func ParseMessage(Message:String)
    {
        var flow, press, extpres, temp :String
        var datamessageArray, data, subdata : [String]
        var paraNum = 0
        //let CselfFun: SelfDefinedFunction? = nil
        if Message.range(of: GlobalConstants.SQCOMMD) != nil   //if includes !00SQ5
        {
             datamessageArray = Message.components(separatedBy: GlobalConstants.SQCOMMD)
             data=datamessageArray[1].components(separatedBy: ";")
            temp=data[0]
            press=data[1]
            flow=data[2]
            extpres = data[3]
            var statusHex = data[5].components(separatedBy: "\n")
            let start = flow.index(flow.startIndex, offsetBy: 5)
            
            lblFlowReading.text = flow.substring(to: start)
            lblIntPresReading.text=press.substring(to: start)
            lblExtPresReading.text=extpres.substring(to: start)
            lblTempReading.text=temp.substring(to: start)
            lblStatus.text = GetStatusStr(Hexstr: statusHex[0]).statusStr
            mblTesting = GetStatusStr(Hexstr: statusHex[0]).bRunning
            mblreceivedSQ = true
            if (mblTesting){
                setChartData()
            }
        }
        else if (Message.range(of: "RT") != nil)
        {
            do{
                datamessageArray = Message.components(separatedBy: "RT")
                data=datamessageArray[1].components(separatedBy: ";")
                paraNum = STRtoINT(str: data[0])
                subdata = data[1].components(separatedBy: "\n")
                T[CurrentTT][paraNum] = 10//UInt(subdata[0])!
                print("Parse T OK")
            }
//            catch{
//                print("Parse T fail")
//            }
            mIntSetupUploadIndex = mIntSetupUploadIndex + 1
        }
        else if (Message.range(of: "RL") != nil)
        {
            do{
                datamessageArray = Message.components(separatedBy: "RL")
                data=datamessageArray[1].components(separatedBy: ";")
                paraNum = STRtoINT(str: data[0])
                subdata = data[1].components(separatedBy: "\n")
                L[paraNum] = subdata[0]
                print("Parse L OK")
            }
//            catch{
//                print("Parse L fail")
//            }
            if (paraNum<ValveSteps-1)
            {
                mIntSetupUploadIndex = mIntSetupUploadIndex + 1
            }
            else
            {
                mIntSetupUploadIndex = mIntSetupUploadIndex + 15 - paraNum
            }
        }
        else if (Message.range(of: "RK") != nil)
        {
            do{
                datamessageArray = Message.components(separatedBy: "RK")
                data=datamessageArray[1].components(separatedBy: ";")
                paraNum = STRtoINT(str: data[0])
                subdata = data[1].components(separatedBy: "\n")
                K[CurrentTT][paraNum] = Double(subdata[0])!
                print("Parse K Ok")
            }
  //          catch{
   //             print("Parse K fail")
   //         }
            mIntSetupUploadIndex = mIntSetupUploadIndex + 1
        }
        else if (Message.range(of: "RV") != nil)
        {
            do{
                datamessageArray = Message.components(separatedBy: "RV")
                data=datamessageArray[1].components(separatedBy: ";")
                paraNum = STRtoINT(str: data[0])
                subdata = data[1].components(separatedBy: "\n")
                V[CurrentTT][paraNum] = Double(subdata[0])!
                print("Parse V OK")
            }
            catch{
                print("Parse V fail")
            }
            mIntSetupUploadIndex = mIntSetupUploadIndex + 1
        }
        else if (Message.range(of: "RU2") != nil)
        {
            do{
                datamessageArray = Message.components(separatedBy: "RU2;")
                subdata = datamessageArray[1].components(separatedBy: "\n")
               // ValveSteps=GetValveStepNumber(U2str: GetSubstring(FullStr: subdata[1], Start: 3, End: 4))
                ValveSteps=GetValveStepNumber(U2str: subdata[0])
                FourthAI=Check4thAI(U2str: subdata[0])
                if (FourthAI == true)
                {
                    //set 4th AI visible
                }
                print("Parse U2 success \(ValveSteps)")
            }
//            catch{
//                print("Parse U2 fail")
//            }
            mIntSetupUploadIndex = mIntSetupUploadIndex + 1
        }
        else if (Message.range(of: "RU3") != nil)
        {
            do{
                datamessageArray = Message.components(separatedBy: "RU3;")
                mstrTemperatureUnit = GetTempUnit(U3str: datamessageArray[1])
                print("Parse U3 Ok")
            }
//            catch{
//                print("Parse U3 fail")
//            }
            mIntSetupUploadIndex = mIntSetupUploadIndex + 1
        }
        else if (Message.range(of: "RU4") != nil)
        {
            do{
                datamessageArray = Message.components(separatedBy: "RU4;")
                mstrPressureUnit = GetPressureUnit(U4str: datamessageArray[1])
                print("Parse U4 OK")
            }
//            catch{
//                print("Parse U4 fail")
//            }
            mIntSetupUploadIndex = mIntSetupUploadIndex + 1
        }
        else if (Message.range(of: "RU5") != nil)
        {
            do{
                datamessageArray = Message.components(separatedBy: "RU5;")
                mstrFlowUnit = GetFlowUnit(U5str: datamessageArray[1])
                print("Parse U5 OK")
            }
//            catch{
//                print("Parse U5 fail")
//            }
            mIntSetupUploadIndex = mIntSetupUploadIndex + 1
        }
        else if (Message.range(of: "SQ3") != nil)
        {
            do{
                datamessageArray = Message.components(separatedBy: "SQ3;")
                CurrentTT = Int (GetSubstring(FullStr: datamessageArray[1], Start: 0, End: 1) )!
                //mblSetupUpload = false
                print("Parse SQ3 OK")
               // mstrPressureUnit = GetPressureUnit(U4str: datamessageArray[1])
            }
//            catch{
//                print("Parse SQ3 fail")
//            }
            mIntSetupUploadIndex = mIntSetupUploadIndex + 1
        }
        else if (Message.range(of: "RQ3") != nil)
        {
            do{
                datamessageArray = Message.components(separatedBy: "RQ3;")
                CurrentTT = Int (GetSubstring(FullStr: datamessageArray[1], Start: 0, End: 1) )!
                mblSetupUpload = false
                print("Parse RQ3 OK")
            }
//            catch{
//                print("Parse RQ3 fail")
//            }
            mIntSetupUploadIndex = mIntSetupUploadIndex + 1
        }
        else if (Message.range(of: "RA4") != nil)
        {
            do{
                datamessageArray = Message.components(separatedBy: "RA4;")
                subdata = datamessageArray[1].components(separatedBy: "\n")
                A4 = Double (subdata[0])!
            }
//            catch{
//                print("Parse U4 fail")
//            }
            mIntSetupUploadIndex = mIntSetupUploadIndex + 1
        }
        else if (Message.range(of: "RS1") != nil)
        {
            do{
                datamessageArray = Message.components(separatedBy: "RS1;")
                subdata = datamessageArray[1].components(separatedBy: "\n")
                mSerialNumber = subdata[0]
                print("Parse S1 \(mSerialNumber)")
            }
//            catch{
//                print("Parse S1 fail")
//            }
            mIntSetupUploadIndex = mIntSetupUploadIndex + 1
        }
        else if (Message.range(of: "RS2") != nil)
        {
            do{
                datamessageArray = Message.components(separatedBy: "RS2;")
                subdata = datamessageArray[1].components(separatedBy: "\n")
                mVerNumber = subdata[0]
                let SN: Int = Int(mVerNumber)!
                if (SN >= 20315)
                {
                    BtnTT.isHidden = false
                }
                else
                {
                    BtnTT.isHidden = true
                }
                print("Parse S2, \(mVerNumber)")
            }
            catch{
                print("Parse S2 fail")
            }
            mIntSetupUploadIndex = mIntSetupUploadIndex + 1
        }
        
    }
    ////////////////////////////////////////////////////////////////////////////////////////
    
    @objc func setChartData()
    {
        let timediff = NSDate().timeIntervalSince1970 - PastTime
        let timediffstr=String(timediff)
        
        let start = timediffstr.index(timediffstr.startIndex, offsetBy: 3)
        
        lblRunningTime.text = timediffstr.substring(to: start) + " (s)"              //display runing past time
        let tempflow = Double(lblFlowReading.text!)
        yVals.append(ChartDataEntry(x: Double(timediff), y: tempflow!))
        let set2: LineChartDataSet = LineChartDataSet(values: yVals, label: "flow")
        set2.axisDependency = .left // Line will correlate with left axis values
        set2.setColor(UIColor.red.withAlphaComponent(0.5)) // our line's opacity is 50%
        set2.setCircleColor(UIColor.red) // our circle will be dark red
        set2.lineWidth = 2.0
        set2.circleRadius = 1.0 // the radius of the node circle
        set2.fillAlpha = 65 / 255.0
        set2.fillColor = UIColor.red
        set2.highlightColor = UIColor.white
        set2.drawCircleHoleEnabled = true
        //3 - create an array to store our LineChartDataSets
        var dataSets2 : [LineChartDataSet] = [LineChartDataSet]()
        dataSets2.append(set2)
        //4 - pass our months in for our x-axis label value along with our dataSets
        
        let data2: LineChartData = LineChartData(dataSets: dataSets2)
        data2.setValueTextColor(UIColor.white)
        self.lineChartView.data = data2
        //       self.lineChartView.setVisibleXRangeMaximum(50)
        //        let xAxis=lineChartView.xAxis
        //        xAxis.axisMinimum=0
        //        xAxis.axisMaximum=50
        // self.lineChartView.setVisibleXRange(minXRange: 0, maxXRange: 200)
        //6 - add x-axis label
    }
/*
    func setChartData(months : [String])
    {
        datalength=Double(months.count)
        // 1 - creating an array of data entries
        //    var yVals1 : [ChartDataEntry] = [ChartDataEntry]()
        /*
         for i in 0..<months.count {
         yVals1.append(ChartDataEntry(x: Double(i), y: dollars[i]))
         }
         
         // 2 - create a data set with our array
         let set1: LineChartDataSet = LineChartDataSet(values: yVals1, label: "First Set")
         
         set1.axisDependency = .left // Line will correlate with left axis values
         set1.setColor(UIColor.red.withAlphaComponent(0.5)) // our line's opacity is 50%
         set1.setCircleColor(UIColor.red) // our circle will be dark red
         set1.lineWidth = 2.0
         set1.circleRadius = 2.0 // the radius of the node circle
         set1.fillAlpha = 65 / 255.0
         set1.fillColor = UIColor.red
         set1.highlightColor = UIColor.white
         set1.drawCircleHoleEnabled = true
         //3 - create an array to store our LineChartDataSets
         var dataSets : [LineChartDataSet] = [LineChartDataSet]()
         dataSets.append(set1)
         //4 - pass our months in for our x-axis label value along with our dataSets
         //let data: LineChartData = LineChartData(dataSets: dataSets)
         //       data.setValueTextColor(UIColor.white)
         
         ////5 - finally set our data
         //self.lineChartView.data.
         //        self.lineChartView.data = data
         
         */
        
        
        //       for i in 0..<months.count {
        //           yVals2.append(ChartDataEntry(x: Double(i), y: dollars1[i]))
        //       }
        let set2: LineChartDataSet = LineChartDataSet(values: yVals2, label: "Second Set")
        set2.axisDependency = .left // Line will correlate with left axis values
        set2.setColor(UIColor.red.withAlphaComponent(0.5)) // our line's opacity is 50%
        set2.setCircleColor(UIColor.red) // our circle will be dark red
        set2.lineWidth = 2.0
        set2.circleRadius = 2.0 // the radius of the node circle
        set2.fillAlpha = 65 / 255.0
        set2.fillColor = UIColor.red
        set2.highlightColor = UIColor.white
        set2.drawCircleHoleEnabled = true
        //3 - create an array to store our LineChartDataSets
        var dataSets2 : [LineChartDataSet] = [LineChartDataSet]()
        dataSets2.append(set2)
        //4 - pass our months in for our x-axis label value along with our dataSets
        
        let data2: LineChartData = LineChartData(dataSets: dataSets2)
        data2.setValueTextColor(UIColor.white)
        //5 - finally set our data
        //self.lineChartView.data.
        self.lineChartView.data = data2
        
        
        
        
        //6 - add x-axis label
        let xaxis = self.lineChartView.xAxis
        xaxis.valueFormatter = MyXAxisFormatter(months)
    }*/
    
    func SetupChart(lineChartView: LineChartView)
    {
        lineChartView.setVisibleXRange(minXRange: 0, maxXRange: 100)
        self.lineChartView.setVisibleXRangeMaximum(50)
        let xAxis=lineChartView.xAxis
        xAxis.axisMinimum=0
        xAxis.axisMaximum=50
      //  for i in 0..<months.count {
            yVals.append(ChartDataEntry(x: 0, y: 0))
      //  }
        setChartData()
    }
 /////////////////////////////////////////////////////////////////////////////////
    //Update setup when TT changed
    func SetupUpdate()
    {
        
        if (PreviousTT != CurrentTT)
        {
            PreviousTT = CurrentTT
            lblFlowRange.text = "(Min: " + String(V[CurrentTT][1]) + "  Max: " + String(V[CurrentTT][2]) + ")"
            lblPresRange.text = "(Min: " + String(K[CurrentTT][3]) + "  Max: " + String(K[CurrentTT][2]) + ")"
            lblExPresRange.text = "(Min: " + String(K[CurrentTT][9]) + "  Max: " + String(K[CurrentTT][10]) + ")"
        }
    }
 /////////////////////////////////////////////////////////////////////////////////
}


class MyXAxisFormatter: NSObject, IAxisValueFormatter {
    
    let months: [String]
    
    init(_ months: [String]) {
        self.months = months
    }
    
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        return months[Int(value)]
    }
}

