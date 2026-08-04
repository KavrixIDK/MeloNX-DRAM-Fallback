//
//  Pre26TabView.swift
//  MeloNX
//
//  Created by Stossy11 on 3/1/2026.
//

import UIKit
import SwiftUI

struct Pre26TabItem: Identifiable {
    let id = UUID()
    let title: String
    let image: String
    let view: AnyView
    
    init<V: View>(title: String, image: String, @ViewBuilder view: () -> V) {
        self.title = title
        self.image = image
        self.view = AnyView(view())
    }
}


class Pre26TabBarController: UIViewController {
    private var selectedIndex: Tab = .games {
        didSet {
            updateSelectedTab()
        }
    }
    
    private let items: [Pre26TabItem]
    private var contentViewControllers: [UIViewController] = []
    private let containerView = UIView()
    private let tabBarStackView = UIStackView()
    private let tabBarContainer = UIView()
    private var tabBarButtons: [UIButton] = []
    private var tabBarHeightConstraint: NSLayoutConstraint?
    
    var onSelectedIndexChanged: ((Tab) -> Void)?
    
    init(items: [Pre26TabItem], selectedIndex: Tab = .games) {
        self.items = items
        self.selectedIndex = selectedIndex
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupContentViewControllers()
        setupUI()
        updateSelectedTab()
    }
    
    private func setupContentViewControllers() {
        contentViewControllers = items.map { item in
            let hostingController = UIHostingController(rootView: item.view)
            addChild(hostingController)
            hostingController.didMove(toParent: self)
            return hostingController
        }
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        for vc in contentViewControllers {
            vc.view.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(vc.view)
            vc.view.alpha = 0
            
            NSLayoutConstraint.activate([
                vc.view.topAnchor.constraint(equalTo: containerView.topAnchor),
                vc.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                vc.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                vc.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
        }
        
        tabBarContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabBarContainer)
        
        let blurEffect = UIBlurEffect(style: .systemMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        tabBarContainer.addSubview(blurView)
        
        let divider = UIView()
        divider.backgroundColor = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        tabBarContainer.addSubview(divider)
        
        tabBarStackView.axis = .horizontal
        tabBarStackView.distribution = .fillEqually
        tabBarStackView.spacing = 0
        tabBarStackView.translatesAutoresizingMaskIntoConstraints = false
        tabBarContainer.addSubview(tabBarStackView)
        
        for (index, item) in items.enumerated() {
            let button = createTabButton(title: item.title, image: item.image, index: index)
            tabBarButtons.append(button)
            tabBarStackView.addArrangedSubview(button)
        }
        
        let tabBarHeight: CGFloat = AlertHandlers.topWindow().bounds.height / 10
        tabBarHeightConstraint =
            tabBarContainer.heightAnchor.constraint(equalToConstant: tabBarHeight)
        tabBarHeightConstraint?.isActive = true
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            tabBarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBarContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabBarContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
           //  tabBarContainer.heightAnchor.constraint(equalToConstant: tabBarHeight + view.safeAreaInsets.bottom),
            
            blurView.topAnchor.constraint(equalTo: tabBarContainer.topAnchor),
            blurView.leadingAnchor.constraint(equalTo: tabBarContainer.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: tabBarContainer.trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: tabBarContainer.bottomAnchor),
            
            divider.topAnchor.constraint(equalTo: tabBarContainer.topAnchor),
            divider.leadingAnchor.constraint(equalTo: tabBarContainer.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: tabBarContainer.trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 0.5),
            
            tabBarStackView.topAnchor.constraint(equalTo: tabBarContainer.topAnchor),
            tabBarStackView.leadingAnchor.constraint(equalTo: tabBarContainer.leadingAnchor),
            tabBarStackView.trailingAnchor.constraint(equalTo: tabBarContainer.trailingAnchor),
            tabBarStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    private func createTabButton(title: String, image: String, index: Int) -> UIButton {
        let button = UIButton(type: .system)
        
        let imageView = UIImageView(image: UIImage(systemName: image))
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 12)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = UIStackView(arrangedSubviews: [imageView, label])
        stackView.axis = AlertHandlers.topWindow().bounds.height > AlertHandlers.topWindow().bounds.width ? .vertical : .horizontal
        stackView.spacing = 4
        stackView.alignment = .center
        stackView.isUserInteractionEnabled = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        button.addSubview(stackView)

        let imageSize = calculateImageSize(for: image)
        
        NSLayoutConstraint.activate([
            imageView.heightAnchor.constraint(equalToConstant: imageSize.height),
            imageView.widthAnchor.constraint(equalToConstant: imageSize.width),
            
            stackView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: button.centerYAnchor, constant: 2)
        ])
        
        button.tag = index
        button.addTarget(self, action: #selector(tabButtonTapped(_:)), for: .touchUpInside)
        
        return button
    }

    private func calculateImageSize(for imageName: String) -> CGSize {
        guard let image = UIImage(systemName: imageName) else {
            return CGSize(width: 28, height: 28)
        }
        
        let aspectRatio = image.size.width / image.size.height
        
        if aspectRatio > 0.9 && aspectRatio < 1.1 {
            return CGSize(width: 28, height: 28)
        }
        
        else if aspectRatio > 1.1 {
            return CGSize(width: 36, height: 28)
        }
        
        else {
            return CGSize(width: 28, height: 36)
        }
    }
    
    public func updateTabButtonLayouts() {
        let isPortrait = AlertHandlers.topWindow().bounds.height > AlertHandlers.topWindow().bounds.width
        
        let tabBarHeight: CGFloat = AlertHandlers.topWindow().bounds.height / 10
        tabBarHeightConstraint?.constant = tabBarHeight

        for button in tabBarButtons {
            
            guard let stackView = button.subviews.first as? UIStackView else { continue }
            stackView.axis = isPortrait ? .vertical : .horizontal
        }
    }
    
    @objc private func tabButtonTapped(_ sender: UIButton) {
        selectedIndex = sender.tag == 0 ? .games : .settings
        onSelectedIndexChanged?(selectedIndex)
    }
    
    private func updateSelectedTab() {
        for (index, button) in tabBarButtons.enumerated() {
            let isSelected = index == selectedIndex.rawValue
            let color: UIColor = isSelected ? .systemBlue : .systemGray
            
            if let stackView = button.subviews.first as? UIStackView {
                (stackView.arrangedSubviews[0] as? UIImageView)?.tintColor = color
                (stackView.arrangedSubviews[1] as? UILabel)?.textColor = color
            }
        }
        
        for (index, vc) in contentViewControllers.enumerated() {
            UIView.animate(withDuration: 0.2) {
                vc.view.alpha = index == self.selectedIndex.rawValue ? 1 : 0
            }
            vc.view.isHidden = index != selectedIndex.rawValue
        }
    }
    
    func setSelectedIndex(_ index: Tab) {
        selectedIndex = index
    }
}

struct Pre26TabView: UIViewControllerRepresentable {
    @Binding var selectedIndex: Tab
    let items: [Pre26TabItem]
    
    init(selectedIndex: Binding<Tab>, items: [Pre26TabItem]) {
        self._selectedIndex = selectedIndex
        self.items = items
    }
    
    func makeUIViewController(context: Context) -> Pre26TabBarController {
        let controller = Pre26TabBarController(items: items, selectedIndex: selectedIndex)
        controller.onSelectedIndexChanged = { newIndex in
            selectedIndex = newIndex
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: Pre26TabBarController, context: Context) {
        uiViewController.setSelectedIndex(selectedIndex)
        uiViewController.updateTabButtonLayouts()
    }
}



