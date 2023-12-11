import UIKit
import AVFoundation

class VideoViewController: UIViewController {
    
    //MARK: - Variables and Properties
    
    var videoUrl: URL?
    var videoAsset: AVAsset?
    var player: AVPlayer?
    var playerLayer: AVPlayerLayer?
    var duration: Double = 0 {
        didSet {
            durationLabel.text = "\(formatTime(Int(currentTime))) / \(formatTime(Int(duration)))"
        }
    }
    var currentTime: Double = 0 {
        didSet {
            durationLabel.text = "\(formatTime(Int(currentTime))) / \(formatTime(Int(duration)))"
        }
    }
    var timeObserverToken: Any?
    
    lazy var videoView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    lazy var playBtn: UIImageView = {
        let view = UIImageView()
        view.image = UIImage(systemName: "play.fill")
        view.tintColor = .white
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = true
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var durationLabel: UILabel = {
        let view = UILabel()
        view.text = "00:00 / 00:00"
        view.textColor = .white
        view.font = .systemFont(ofSize: 13)
        view.textAlignment = .center
        view.backgroundColor = .white.withAlphaComponent(0.2)
        view.layer.cornerRadius = 5
        view.layer.masksToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    lazy var saveBtn: UIButton = {
        let view = UIButton()
        view.setTitle("Save", for: .normal)
        view.titleLabel?.font = .systemFont(ofSize: 15)
        view.backgroundColor = .white.withAlphaComponent(0.3)
        view.layer.cornerRadius = 5
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    lazy var backBtn: UIImageView = {
        let view = UIImageView()
        view.image = UIImage(systemName: "arrowshape.backward.fill")
        view.tintColor = .white
        view.contentMode = .scaleAspectFit
        view.isUserInteractionEnabled = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    //MARK: - Class Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupPlayer()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        playerLayer?.frame = videoView.bounds
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if (player?.timeControlStatus == .playing) {
            player?.pause()
        }
    }
    
    deinit {
        if let timeObserverToken {
            player?.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
        player?.replaceCurrentItem(with: nil)
        player = nil
        NotificationCenter.default.removeObserver(self)
        if let videoUrl {
            FileUtil.deleteFile(at: videoUrl)
        }
    }
    
    private func setupViews() {
        view.backgroundColor = .black
        view.addSubview(self.videoView)
        view.addSubview(self.playBtn)
        view.addSubview(self.saveBtn)
        view.addSubview(self.durationLabel)
        view.addSubview(self.backBtn)
        
        NSLayoutConstraint.activate([
            playBtn.widthAnchor.constraint(equalToConstant: 26),
            playBtn.heightAnchor.constraint(equalToConstant: 26),
            playBtn.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            playBtn.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            durationLabel.heightAnchor.constraint(equalToConstant: 32),
            durationLabel.widthAnchor.constraint(equalToConstant: 100),
            durationLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            durationLabel.centerYAnchor.constraint(equalTo: playBtn.centerYAnchor),
            saveBtn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            saveBtn.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            saveBtn.heightAnchor.constraint(equalToConstant: 34),
            saveBtn.widthAnchor.constraint(equalToConstant: 60),
            backBtn.heightAnchor.constraint(equalToConstant: 24),
            backBtn.widthAnchor.constraint(equalToConstant: 24),
            backBtn.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            backBtn.centerYAnchor.constraint(equalTo: saveBtn.centerYAnchor),
            videoView.topAnchor.constraint(equalTo: saveBtn.bottomAnchor, constant: 10),
            videoView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 10),
            videoView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -10),
            videoView.bottomAnchor.constraint(equalTo: playBtn.topAnchor, constant: -10)
        ])
        
        backBtn.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(backBtnTapped(_:))))
        playBtn.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(playBtnTapped(_:))))
        saveBtn.addTarget(self, action: #selector(saveBtnTapped(_:)), for: .touchUpInside)
    }
    
    private func setupPlayer() {
        guard let videoUrl = self.videoUrl else {return}
        let videoAsset = AVAsset(url: videoUrl)
        let playerItem = AVPlayerItem(asset: videoAsset)
        player = AVPlayer(playerItem: playerItem)
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.frame = self.videoView.bounds
        videoView.layer.addSublayer(playerLayer!)
        self.duration = videoAsset.duration.seconds
        player?.pause()
        
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: CMTimeMake(value: 1, timescale: CMTimeScale(NSEC_PER_SEC)), queue: .main, using: { time in
            self.currentTime = time.seconds
        })
        NotificationCenter.default.addObserver(self, selector: #selector(self.playerItemDidReachEnd(_:)), name: AVPlayerItem.didPlayToEndTimeNotification, object: nil)
    }
    
    private func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func exportAndSaveVideo(at url: URL) {
        player?.pause()
        playBtn.image = UIImage(systemName: "play.fill")
        let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popOverController = activityViewController.popoverPresentationController {
            popOverController.sourceView = self.view
            popOverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
            popOverController.permittedArrowDirections = []
        }
        self.present(activityViewController, animated: true)
    }
    
    @objc private func playBtnTapped(_ sender: Any) {
        guard let player = player else {return}
        if (player.timeControlStatus == .playing) {
            player.pause()
            playBtn.image = UIImage(systemName: "play.fill")
        } else {
            player.play()
            playBtn.image = UIImage(systemName: "pause.fill")
        }
    }
    
    @objc func playerItemDidReachEnd(_ notification: Notification) {
        if let player = self.player {
            player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
            player.play()
        }
    }
    
    @objc func saveBtnTapped(_ sender: UIButton) {
        guard let videoUrl = self.videoUrl else {return}
        self.exportAndSaveVideo(at: videoUrl)
    }
    
    @objc func backBtnTapped(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
}
