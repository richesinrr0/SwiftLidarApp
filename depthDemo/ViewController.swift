//
//  ViewController.swift
//  depthDemo
//
//  Created by Amanda Wagner on 1/19/23.
//  Code originally from https://www.kodeco.com/5999357-video-depth-maps-tutorial-for-ios-getting-started

import UIKit
import AVFoundation
import AudioToolbox


class ViewController: UIViewController {
    
    //This is the ImageView object found in the "Main" Storyboard, yellow logo
    //The variable previewView is connected to that object
    @IBOutlet weak var previewView: UIImageView!
    
    //instantiate the capture session and queue
    let session = AVCaptureSession()

    let dataOutputQueue = DispatchQueue(label: "video data queue",
                                      qos: .userInitiated,
                                      attributes: [],
                                      autoreleaseFrequency: .workItem)
    
    //creating variable to place depth data map in
    var depthMap: CIImage? //depth data map will later be stored inside this CIImage
    
    var rgbValues: (CGFloat, CGFloat, CGFloat)?

    //initiates the streaming of depth data to UIImageView
    override func viewDidLoad() {
        super.viewDidLoad()
        configureCaptureSession()
        session.startRunning()
        //rgbValueLabel.backgroundColor = UIColor(red: rgbValues!.0, green: rgbValues!.1, blue: rgbValues!.2, alpha: 0)
        //print(test(tupleVal: rgbValues!))
    }
}

// MARK: - Setting up Capture Session
extension ViewController {
    //create function to setup the capture session
    func configureCaptureSession() {
        //grab the desired camera, .builtInLiDARDepthCamera (iPhone 12 pro and up) or builtInDualWideCamera (Most iPhones)
        guard let camera = AVCaptureDevice.default(.builtInLiDARDepthCamera, for: .video, position: .unspecified) else {
        fatalError("Camera not available")
    }

    session.sessionPreset = .high //preset to better capture high quality video or photo default value was .photo
        
    //if there is input then add input to session
    do {
      let cameraInput = try AVCaptureDeviceInput(device: camera)
      session.addInput(cameraInput)
    } catch {
      fatalError(error.localizedDescription)
    }
    
    //getting video output, testing connection, and adding to session
    let videoOutput = AVCaptureVideoDataOutput()
    videoOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
    videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]

    session.addOutput(videoOutput)

    let videoConnection = videoOutput.connection(with: .video)
    videoConnection?.videoOrientation = .portrait

    //getting depth output, testing connection, and adding to session
    let depthOutput = AVCaptureDepthDataOutput()
    depthOutput.setDelegate(self, callbackQueue: dataOutputQueue)
    depthOutput.isFilteringEnabled = true
    session.addOutput(depthOutput)

    let depthConnection = depthOutput.connection(with: .depthData)
    depthConnection?.videoOrientation = .portrait
    
       //locking our session setup if we can format the data
    do {
      try camera.lockForConfiguration()

      if let format = camera.activeDepthDataFormat,
        let range = format.videoSupportedFrameRateRanges.first  {
        camera.activeVideoMinFrameDuration = range.minFrameDuration
      }

      camera.unlockForConfiguration()
    } catch {
      fatalError(error.localizedDescription)
    }
  }
}

// MARK: - Capture Depth Data to Stream Delegate

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
  func captureOutput(_ output: AVCaptureOutput,
                     didOutput sampleBuffer: CMSampleBuffer, //An object that contains zero or more media samples of a uniform media type.
                     from connection: AVCaptureConnection) {
    let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) //Returns an image buffer that contains the media data.
    let image = CIImage(cvPixelBuffer: pixelBuffer!) //Initializes an image object from the contents of a Core Video pixel buffer.
      
    //Creating a CIImage to store depth data
    let previewImage: CIImage

    //if there is data in depthMap set it to the CIImage, else its the blank image
    previewImage = depthMap ?? image
    
    //Creating a UIImage out of the preview CIImage
    let displayImage = UIImage(ciImage: previewImage)

      
    //setting the created UIImage into our queue
    DispatchQueue.main.async { [weak self] in
        self?.previewView.image = displayImage
    }
  }
}

// MARK: - Capture Depth Data Delegate Methods
extension ViewController: AVCaptureDepthDataOutputDelegate {
  func depthDataOutput(_ output: AVCaptureDepthDataOutput,
                       didOutput depthData: AVDepthData,
                       timestamp: CMTime,
                       connection: AVCaptureConnection) {
    
    
    var convertedDepth: AVDepthData
    
    //converting depth data to a disparity float
    let depthDataType = kCVPixelFormatType_DisparityFloat32
    if depthData.depthDataType != depthDataType {
      convertedDepth = depthData.converting(toDepthDataType: depthDataType)
    } else {
      convertedDepth = depthData
    }

    //creating converted depth into pixelBuffer
    let pixelBuffer = convertedDepth.depthDataMap
    //print(pixelBuffer)
    pixelBuffer.clamp()
    //print(pixelBuffer)
    var auxDataType :NSString?
    let auxData = depthData.dictionaryRepresentation(forAuxiliaryDataType: &auxDataType)


    let depthMap = CIImage(cvPixelBuffer: pixelBuffer) //Initializes an image object from the contents of a Core Video pixel buffer.
      


      
      
    //sends depthMap to queue
    DispatchQueue.main.async { [weak self] in
      self?.depthMap = depthMap
    }
      
      //turning ciimage to cgimage
      let context = CIContext(options: nil)

      //printing rgb values from a CGImage
      guard let cgImage = context.createCGImage(depthMap, from: depthMap.extent),
          let data = cgImage.dataProvider?.data,
          let bytes = CFDataGetBytePtr(data) else {
          fatalError("Couldn't access image data")
      }
      assert(cgImage.colorSpace?.model == .rgb)

      let bytesPerPixel = cgImage.bitsPerPixel / cgImage.bitsPerComponent
      let offset = (160 * cgImage.bytesPerRow) + (120 * bytesPerPixel)
      let components = (CGFloat(bytes[offset]), CGFloat(bytes[offset + 1]), CGFloat(bytes[offset + 2]))
      //print("[x:\(120), y:\(160)] \(components)")
      
      //sending values to queue
      //print(components.0)
      if 221...256 ~= components.0 {
          //HapticsManager.shared.vibrate(for: .error)
          //AudioServicesPlayAlertSoundWithCompletion(SystemSoundID(kSystemSoundID_Vibrate)) { }
          let gen = UIImpactFeedbackGenerator(style: .heavy)
          gen.impactOccurred()
      }
      /*
      if 226...245 ~= components.0 {
          //HapticsManager.shared.vibrate(for: .error)
          //AudioServicesPlayAlertSoundWithCompletion(SystemSoundID(kSystemSoundID_Vibrate)) { }
          let gen = UIImpactFeedbackGenerator(style: .medium)
          gen.impactOccurred()
      }
      if 210...225 ~= components.0 {
          //HapticsManager.shared.vibrate(for: .error)
          //AudioServicesPlayAlertSoundWithCompletion(SystemSoundID(kSystemSoundID_Vibrate)) { }
          let gen = UIImpactFeedbackGenerator(style: .light)
          gen.impactOccurred()
      }
       */
  }
}
/*
func dictionaryRepresentation(forAuxiliaryDataType outAuxDataType: kCGImageAuxiliaryDataTypeDepth<NSString?>?) -> [AnyHashable : Any]? {
    unsafeBitCast(CVPixelBufferGetBaseAddress(outAuxDataType["kCGImageAuxiliaryDataInfoData"]), to: UnsafeMutablePointer&amp;amp;lt;Float32&amp;amp;gt;.self)
    return outAuxDataType //.AnyHashable(

}
 */
// MARK: function to get rgb values so uicolor can use
