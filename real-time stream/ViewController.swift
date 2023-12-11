//
//  ViewController.swift
//  real-time stream
//
//  Created by epmvito on 10.12.2023.
//

import UIKit
import AVFoundation
import Metal
import MetalKit

class ViewController: UIViewController {
    
    //MARK: - Variables and Properties
    
    lazy var renderingView: RenderingView = {
        let view = RenderingView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var recordBtn: UIButton = {
        let button = UIButton()
        button.backgroundColor = .red.withAlphaComponent(0.8)
        button.setTitle("Record", for: .normal)
        button.setTitle("Done", for: .selected)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var vhsBtn: UIButton = {
        let view = UIButton()
        view.setTitle("VHS Effect", for: .normal)
        view.titleLabel?.font = .systemFont(ofSize: 13)
        view.backgroundColor = .white.withAlphaComponent(0.3)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 5
        return view
    }()
    
    private lazy var scalingModeBtn: UIButton = {
        let view = UIButton()
        view.backgroundColor = .white.withAlphaComponent(0.3)
        view.titleLabel?.font = .systemFont(ofSize: 13)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 5
        return view
    }()
    
    private lazy var activityIndicator: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .medium)
        view.hidesWhenStopped = true
        view.translatesAutoresizingMaskIntoConstraints = false
        view.stopAnimating()
        return view
    }()
    
    private lazy var durationLabel: UILabel = {
        let view = UILabel()
        view.text = "00:00"
        view.textColor = .white
        view.textAlignment = .center
        view.font = .systemFont(ofSize: 13)
        view.backgroundColor = .black.withAlphaComponent(0.4)
        view.layer.cornerRadius = 10
        view.layer.masksToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private var gpuOperator: GPUOperator?
    private var videoRecorder: VideoRecorder?
    private var camera: Camera?
    private var isFiltered: Bool = false
    private var recordingTimer: Timer?
    private var recorderElapsedTime = 0
    
    //MARK: - Class Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureViews()
        configureGpu()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.camera?.requestCameraAccessAndConfigure {
            self.camera?.start()
            self.renderingView.run()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.camera?.stop()
        self.renderingView.stop()
        self.stopTimer()
    }
    
    func configureViews() {
        view.backgroundColor = .black
        setupScalingBtn()
        
        let scaleStack = createStackViewGroup(subView: scalingModeBtn, label: "Scaling Mode")
        
        view.addSubview(self.renderingView)
        view.addSubview(self.recordBtn)
        view.addSubview(self.vhsBtn)
        view.addSubview(scaleStack)
        view.addSubview(activityIndicator)
        view.addSubview(durationLabel)
        
        NSLayoutConstraint.activate([
            renderingView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            renderingView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            renderingView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            renderingView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -150),
            
            recordBtn.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            recordBtn.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            recordBtn.heightAnchor.constraint(equalToConstant: 42),
            recordBtn.widthAnchor.constraint(equalToConstant: 150),
            
            scalingModeBtn.heightAnchor.constraint(equalToConstant: 30),
            scalingModeBtn.widthAnchor.constraint(equalToConstant: 84),
            
            vhsBtn.heightAnchor.constraint(equalToConstant: 30),
            vhsBtn.widthAnchor.constraint(equalToConstant: 84),
            vhsBtn.topAnchor.constraint(equalTo: renderingView.bottomAnchor, constant: 20),
            vhsBtn.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            
            scaleStack.topAnchor.constraint(equalTo: renderingView.bottomAnchor, constant: 20),
            scaleStack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            durationLabel.heightAnchor.constraint(equalToConstant: 30),
            durationLabel.widthAnchor.constraint(equalToConstant: 50),
            durationLabel.bottomAnchor.constraint(equalTo: renderingView.bottomAnchor, constant: -10),
            durationLabel.centerXAnchor.constraint(equalTo: renderingView.centerXAnchor)
        ])
        
        self.durationLabel.isHidden = true
        self.recordBtn.addTarget(self, action: #selector(recordBtnTapped(_:)), for: .touchUpInside)
        self.vhsBtn.addTarget(self, action: #selector(vhsBtnTapped(_:)), for: .touchDown)
        self.vhsBtn.addTarget(self, action: #selector(vhsBtnReleased(_:)), for: .touchUpInside)
        self.vhsBtn.addTarget(self, action: #selector(vhsBtnReleased(_:)), for: .touchUpOutside)
    }
    
    private func configureGpu() {
        self.videoRecorder = VideoRecorder(frameRate: self.camera?.getCurrentFrameDuration() ?? (1/59))
        self.gpuOperator = try? GPUOperator()
        gpuOperator?.videoRecorder = videoRecorder
        self.camera = .init(gpuOperator: gpuOperator)
        renderingView.gpuOperator = gpuOperator
    }
    
    private func setupScalingBtn() {
        let actionClosure = { (action: UIAction) in
            let desiredMode = ScalingMode.allCases.first { mode in
                mode.label == action.title
            }
            self.gpuOperator?.graphicsEncoder.scalingMode = desiredMode!
        }
        
        scalingModeBtn.menu = UIMenu(options: .displayInline, children: ScalingMode.allCases.map({ mode in
            var isSelected = false
            if self.gpuOperator?.graphicsEncoder.scalingMode == mode {
                isSelected = true
            }
            return UIAction(title: mode.label, state: isSelected ? .on : .off, handler: actionClosure)
        }))
        scalingModeBtn.showsMenuAsPrimaryAction = true
        scalingModeBtn.changesSelectionAsPrimaryAction = true
    }
    
    private func createStackViewGroup(subView: UIView, label: String) -> UIStackView {
        let view = UIStackView()
        view.axis = .horizontal
        view.spacing = 10
        view.alignment = .center
        view.translatesAutoresizingMaskIntoConstraints = false
        
        let labelView = UILabel()
        labelView.text = label
        labelView.font = .systemFont(ofSize: 13)
        
        view.addArrangedSubview(labelView)
        view.addArrangedSubview(subView)
        return view
    }
    
    private func startTimer() {
        self.recorderElapsedTime = 0
        self.durationLabel.text = formatTime(self.recorderElapsedTime)
        self.recordingTimer?.invalidate()
        self.recordingTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(timerAction(_:)), userInfo: nil, repeats: true)
        RunLoop.current.add(self.recordingTimer!, forMode: .common)
    }
    
    private func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    private func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    @objc private func recordBtnTapped(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        sender.backgroundColor = sender.isSelected ? .white.withAlphaComponent(0.5) : .red.withAlphaComponent(0.8)
        if (sender.isSelected) {
            self.durationLabel.isHidden = false
            self.durationLabel.text = formatTime(0)
            videoRecorder?.startRecording(size: renderingView.bounds.size) {
                DispatchQueue.main.async {
                    self.startTimer()
                }
            }
        } else {
            activityIndicator.startAnimating()
            stopTimer()
            videoRecorder?.stopRecording {
                DispatchQueue.main.async {
                    self.activityIndicator.stopAnimating()
                    self.durationLabel.isHidden = true
                    guard let url = self.videoRecorder?.fileUrl else {return}
                    let vc2 = VideoViewController()
                    vc2.videoUrl = url
                    self.navigationController?.pushViewController(vc2, animated: true)
                }
            }
        }
    }
    
    @objc private func vhsSwitchChanged(_ sender: UISwitch) {
        gpuOperator?.graphicsEncoder.fragmentFunctionName = sender.isOn ? .vhs : .default
    }
    
    @objc private func vhsBtnTapped(_ sender: UIButton) {
        gpuOperator?.graphicsEncoder.fragmentFunctionName = .vhs
    }
    
    @objc private func vhsBtnReleased(_ sender: UIButton) {
        gpuOperator?.graphicsEncoder.fragmentFunctionName = .default
    }
    
    @objc private func timerAction(_ sender: Any) {
        self.recorderElapsedTime += 1
        durationLabel.text = formatTime(recorderElapsedTime)
    }
}


