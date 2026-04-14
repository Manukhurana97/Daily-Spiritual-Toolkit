import Flutter
import UIKit
import AVFoundation
import MediaPlayer

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    private var volumeChannel: FlutterMethodChannel?
    private var initialVolume: Float = 0.5

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller = window?.rootViewController as? FlutterViewController
        if let controller = controller {
            volumeChannel = FlutterMethodChannel(
                name: "com.manukhurana.naam_jap/volume",
                binaryMessenger: controller.binaryMessenger
            )
        }

        setupVolumeListener()
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func setupVolumeListener() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setActive(true)
            initialVolume = audioSession.outputVolume
        } catch {}

        audioSession.addObserver(self, forKeyPath: "outputVolume", options: [.new, .old], context: nil)
    }

    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        if keyPath == "outputVolume" {
            guard let newValue = change?[.newKey] as? Float,
                  let oldValue = change?[.oldKey] as? Float else { return }
            if newValue > oldValue {
                volumeChannel?.invokeMethod("volumeUpPressed", arguments: nil)
            }
            // Reset volume to prevent hitting max/min
            let slider = MPVolumeView().subviews.first(where: { $0 is UISlider }) as? UISlider
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                slider?.value = self.initialVolume
            }
        }
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    }
}
