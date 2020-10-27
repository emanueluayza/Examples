//
//  ViewController.swift
//  DelayCameraFeed
//
//  Created by Emanuel Luayza on 27/10/2020.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {

    // MARK: - Properties

    let cameraFeed = CameraFeed()
    let player = AVQueuePlayer()
    var playerLayer: AVPlayerLayer?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()

        cameraFeed.startCamera()

        cameraFeed.didOutputPlayerItem = { item in
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.player.insert(item, after: nil)
                strongSelf.player.play()
            }
        }
    }

    // MARK: - Setup View

    func setupView() {
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.frame = view.frame
        playerLayer?.videoGravity = .resizeAspectFill

        view.layer.addSublayer(playerLayer!)
    }
}

