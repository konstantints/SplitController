//
//  SplitController.swift
//  SplitController
//
//  Created by Konstantin Tsistjakov on 26/01/2017.
//  Copyright © 2017 Chipp Studio. All rights reserved.
//

import UIKit

public enum SplitControllerStateRules {
    case `default`
    case widthBase
    case onlyPad
    case custom(rule: (_ traitCollectio: UITraitCollection, _ viewSize: CGSize, _ mainWidth: CGFloat) -> (Bool))
    
    func stateValue(_ traitCollection: UITraitCollection, viewSize: CGSize, mainWidth: CGFloat) -> Bool {
        switch self {
        case .default:
            return traitCollection.horizontalSizeClass == .regular && viewSize.width >= mainWidth * 2
        case .widthBase:
            return viewSize.width >= mainWidth + 320.0
        case .onlyPad:
            return traitCollection.userInterfaceIdiom == .pad && traitCollection.horizontalSizeClass == .regular && viewSize.width > mainWidth
        case .custom(rule: let rule):
            return rule(traitCollection, viewSize, mainWidth)
        }
    }
}

public enum SplitControllerSideAnimationStyle {
    case none
    case pushRight
    case pushLeft
    case modal
    case fade
}

open class SplitController: UIViewController {
    
    // MARK: - Main view controller
    public fileprivate(set) var mainController: UINavigationController! {
        willSet {
            self.removeChildViewController(mainController)
        }
        didSet {
            self.setupMainViewController(mainController)
        }
    }
    public var mainControllerWidth: CGFloat = 340.0
    
    fileprivate var mainControllerSize: CGSize = CGSize.zero
    
    // MARK: - Side view controller
    
    public fileprivate(set) var sideController: UINavigationController? {
        willSet {
            if sideController != nil && newValue !=  nil {
                if let snapshot = sideController!.view.snapshot() {
                    self.sideControllerSnapshot = snapshot
                    self.view.insertSubview(self.sideControllerSnapshot!, at: 0)
                }
            }
            self.removeChildViewController(sideController)
        }
        didSet {
            self.setupSideViewController(sideController)
        }
    }
    fileprivate var sideControllerSize: CGSize = CGSize.zero
    fileprivate var sideControllerSnapshot: UIView?
    
    // MARK: - Customization
    public var isShowSideCloseButton = true
    public var closeButtonTitle = "Close"
    public var closeButtonImage: UIImage?
    
    // MARK: - Separator
    public var separatorViewColor = UIColor.lightGray
    fileprivate var separatorView: UIView!
    
    // MARK: - Style
    public var animationStyle: SplitControllerSideAnimationStyle = .fade
    
    // MARK: - State
    public var rules: SplitControllerStateRules = .widthBase
    
    // MARK: - Information
    public fileprivate(set) var isSideOpen: Bool = false
    
    // MARK: - Private
    fileprivate var isControllerContaintsSideController: Bool = false
    fileprivate weak var newCollection: UITraitCollection?
    fileprivate var casheViewControllers = [UIViewController]()
    fileprivate var closeSideButton: UIBarButtonItem!
    
    // MARK: - Setup
    override open func viewDidLoad() {
        super.viewDidLoad()
        _ = self.recalculateState(view.bounds.size)
    }
    
    override open func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

// MARK: - UIConttentConteiner
extension SplitController {
    override open func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        self.newCollection = newCollection
        super.willTransition(to: newCollection, with: coordinator)
    }
    
    override open func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        
        if self.sideController != nil {
            self.casheViewControllers = self.sideController!.viewControllers
        } else {
            
        }
        
        if recalculateState(size) {
            changeState(size, withTransitionCoordinator: coordinator)
            return
        }
        
        var rect = mainController.view.frame
        rect.size.height = size.height
        rect.size.width = isControllerContaintsSideController ? mainControllerWidth : size.width
        
        var sideRect = CGRect.zero
        
        mainControllerSize = rect.size
        sideControllerSize = sideRect.size
        
        if self.sideController != nil {
            sideRect = sideController!.view.frame
            
            sideRect.size.width = size.width - mainControllerSize.width
            sideRect.size.height = size.height
            
            sideControllerSize = sideRect.size
        }
        
        super.viewWillTransition(to: size, with: coordinator)
        
        self.animation({
            self.mainController.view.frame = rect
            if self.sideController != nil { self.sideController?.view.frame = sideRect }
        }, withTransitionCoordinator: coordinator)
    }
    
    override open func size(forChildContentContainer container: UIContentContainer, withParentContainerSize parentSize: CGSize) -> CGSize {
        if container.isEqual(mainController) {
            return mainControllerSize
        }
        
        if container.isEqual(sideController) {
            return sideControllerSize
        }
        
        return super.size(forChildContentContainer: container, withParentContainerSize: parentSize)
    }
}

//MARK: - UINavigationControllerDelegate
extension SplitController: UINavigationControllerDelegate {
    public func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        if self.casheViewControllers.count != 0 && navigationController == self.mainController {
            if !navigationController.viewControllers.contains(self.casheViewControllers.last!) {
                self.casheViewControllers.removeLast()
            } else {
                if !self.casheViewControllers.contains(viewController) {
                    self.casheViewControllers.append(viewController)
                }
            }
        }
    }
}

// MARK: - State Change
extension SplitController {
    // return yes if need to to cahnge
    fileprivate func recalculateState(_ size: CGSize) -> Bool {
        let traitCollection = newCollection ?? self.traitCollection
        
        let newState = rules.stateValue(traitCollection, viewSize: size, mainWidth: mainControllerWidth)
        
        if newState != isControllerContaintsSideController {
            isControllerContaintsSideController = newState
            return true
        }
        
        return false
    }
    
    fileprivate func changeState(_ size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        let bounds = CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height)
        
        if isControllerContaintsSideController {
            
            self.mainController.delegate = nil
            
            for _ in 0..<self.casheViewControllers.count {
                self.mainController.popViewController(animated: false)
            }
            
            if self.casheViewControllers.count != 0 {
                let navigationController = UINavigationController(rootViewController: self.casheViewControllers[0])
                for index in 1..<self.casheViewControllers.count {
                    navigationController.pushViewController(self.casheViewControllers[index], animated: false)
                }
                self.sideController = navigationController
                self.sideController!.view.translatesAutoresizingMaskIntoConstraints = false
                self.isSideOpen = true
            }
            
            let mainRect = CGRect(x: 0.0, y: 0.0, width: mainControllerWidth, height: size.height)
            let sideRect = self.sideController != nil ? CGRect(x: mainControllerWidth, y: 0.0, width: size.width - mainControllerWidth, height: size.height) : CGRect.zero
            
            mainControllerSize = mainRect.size
            sideControllerSize = sideRect.size
            
            super.viewWillTransition(to: size, with: coordinator)
            
            animation({
                self.mainController.view.frame = mainRect
                self.sideController?.view.frame = sideRect
            }, withTransitionCoordinator: coordinator)
            
            self.addSeparator()
        } else {
            self.removeSideCloseButton()
            
            for c in self.casheViewControllers {
                self.mainController.pushViewController(c, animated: false)
            }
            
            mainControllerSize = bounds.size
            sideControllerSize = CGSize.zero
            
            super.viewWillTransition(to: size, with: coordinator)
            
            animation({
                self.mainController.view.frame = bounds
            }, withTransitionCoordinator: coordinator)
            self.sideController = nil
            self.isSideOpen = false
            
            self.removeSeparator()
            
            self.mainController.delegate = self
        }
    }
}

// MARK: - Setup view controllers
extension SplitController {
    fileprivate func setupMainViewController(_ controller: UINavigationController?) {
        guard let controller = controller else {
            return
        }
        
        self.addChildViewController(controller)
        controller.didMove(toParentViewController: self)
        
        controller.view.frame = isControllerContaintsSideController ? CGRect(x: 0, y: 0, width: mainControllerWidth, height: UIScreen.main.bounds.size.height) : CGRect(x: 0.0, y: 0.0, width: UIScreen.main.bounds.size.width, height: UIScreen.main.bounds.size.height)
        
        controller.view.autoresizingMask = UIViewAutoresizing()
        mainControllerSize = controller.view.bounds.size
        self.view.addSubview(controller.view)
        
        self.mainController.delegate = self
        
        if self.isControllerContaintsSideController {
            self.addSeparator()
        }
    }
    
    fileprivate func setupSideViewController(_ controller: UINavigationController?) {
        guard let controller = controller else {
            return
        }
        if isControllerContaintsSideController {
            self.addChildViewController(controller)
            self.didMove(toParentViewController: self)
            controller.view.frame = CGRect(x: mainControllerSize.width, y: 0.0, width: self.view.frame.size.width - mainControllerSize.width, height: UIScreen.main.bounds.size.height)
            
            controller.view.autoresizingMask = UIViewAutoresizing()
            sideControllerSize = controller.view.bounds.size
            
            switch self.animationStyle {
            case .fade: controller.view.alpha = 0.0
            case .modal: var preAnimationFrame = controller.view.frame
            preAnimationFrame.origin.y = self.view.bounds.size.height
            controller.view.frame = preAnimationFrame
            case .pushRight: var preAnimationFrame = controller.view.frame
            preAnimationFrame.origin.x = self.mainControllerSize.width - self.sideControllerSize.width
            controller.view.frame = preAnimationFrame
            case .pushLeft: var preAnimationFrame = controller.view.frame
            preAnimationFrame.origin.x = self.view.frame.size.width
            controller.view.frame = preAnimationFrame
            case .none: break
            }
            
            self.view.insertSubview(controller.view, belowSubview: self.mainController.view)
            
            UIView.animate(withDuration: 0.3, animations: {
                switch self.animationStyle {
                case .fade: controller.view.alpha = 1.0
                case .modal: var postAnimationFrame = controller.view.frame
                postAnimationFrame.origin.y = 0.0
                controller.view.frame = postAnimationFrame
                case .pushRight: var postAnamationFrame = controller.view.frame
                postAnamationFrame.origin.x = self.mainControllerSize.width
                controller.view.frame = postAnamationFrame
                case .pushLeft: var postAnimationFrame = controller.view.frame
                postAnimationFrame.origin.x = self.mainControllerSize.width
                controller.view.frame = postAnimationFrame
                case .none: break
                }
            }, completion: { (done) in
                if let snapshot = self.sideControllerSnapshot {
                    snapshot.removeFromSuperview()
                }
            })
            
            self.addSideCloseButton()
        }
    }
}

// MARK: - Separate actions
extension SplitController {
    fileprivate func addSeparator() {
        addSeparator(self.view.bounds.size)
    }
    
    fileprivate func addSeparator(_ size: CGSize) {
        removeSeparator()
        separatorView = UIView(frame: CGRect(x: mainControllerWidth - 1, y: 0, width: 1, height: size.height))
        separatorView.autoresizingMask = .flexibleHeight
        separatorView.backgroundColor = separatorViewColor
        mainController.view.addSubview(separatorView)
    }
    
    fileprivate func removeSeparator() {
        separatorView?.removeFromSuperview()
    }
}

// MARK: - Close button actions
extension SplitController {
    fileprivate func addSideCloseButton() {
        if !self.isShowSideCloseButton || self.sideController == nil {
            return
        }
        
        if let image = self.closeButtonImage {
            self.closeSideButton = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(closeButtonAction(_: )))
        } else {
            self.closeSideButton = UIBarButtonItem(title: self.closeButtonTitle, style: .plain, target: self, action: #selector(closeButtonAction(_: )))
        }
        if let topItem = self.sideController?.viewControllers.first?.navigationItem {
            topItem.leftBarButtonItem = self.closeSideButton
        }
    }
    fileprivate func removeSideCloseButton() {
        if let topView = self.sideController?.viewControllers.first?.navigationItem {
            topView.leftBarButtonItem = nil
        }
    }
    @objc fileprivate func closeButtonAction(_ sender: UIBarButtonItem) {
        self.popSideViewController(self.animationStyle)
    }

}

// MARK: - Pushing and Poping Controllers
extension SplitController {
    
    public func insertMainViewController(_ controller: UINavigationController) {
        self.mainController = controller
    }
    
    public func pushSideViewController(_ controller: UIViewController, animationStyle: SplitControllerSideAnimationStyle) {
        self.animationStyle = animationStyle
        
        if self.isControllerContaintsSideController {
            self.casheViewControllers.removeAll()
            let navigationController = UINavigationController(rootViewController: controller)
            self.sideController = navigationController
            self.casheViewControllers.append(controller)
        } else {
            let animated = animationStyle == .none ? false : true
            self.mainController.pushViewController(controller, animated: animated)
            self.casheViewControllers.append(controller)
        }
    }
    public func popSideViewController(_ animationStyle: SplitControllerSideAnimationStyle) {
        
        self.animationStyle = animationStyle
        
        if self.isControllerContaintsSideController {
            guard let controller = self.sideController else {
                return
            }
            
            self.casheViewControllers.removeAll()
            
            UIView.animate(withDuration: 0.3, animations: {
                switch self.animationStyle {
                case .fade: controller.view.alpha = 0.0
                case .modal: var postAnamationFrame = controller.view.frame
                postAnamationFrame.origin.y = self.view.bounds.size.height
                controller.view.frame = postAnamationFrame
                case .pushRight: var postAnimationFrame = controller.view.frame
                postAnimationFrame.origin.x = self.mainControllerSize.width - self.sideControllerSize.width
                controller.view.frame = postAnimationFrame
                case .pushLeft: var postAnimationFrame = controller.view.frame
                postAnimationFrame.origin.x = self.view.frame.size.width
                controller.view.frame = postAnimationFrame
                default: print("default")
                }
            }, completion: { (done) in
                self.sideController = nil
            })
        } else {
            let animated = animationStyle == .none ? false : true
            if self.casheViewControllers.count != 0 {
                self.casheViewControllers.removeLast()
            }
            self.mainController.popViewController(animated: animated)
        }
    }
}

// MARK: - Helpers
extension SplitController {
    fileprivate func removeChildViewController(_ viewController: UIViewController?) {
        if let viewController = viewController {
            viewController.willMove(toParentViewController: nil)
            viewController.view.removeFromSuperview()
            viewController.removeFromParentViewController()
        }
    }
    
    fileprivate func animation(_ animation: @escaping () ->(), withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(alongsideTransition: { context in
            animation()
        }, completion: nil)
    }
}

// MARK: - UIViewController
public extension UIViewController {
    var splitController: SplitController? {
        var controller = self.parent
        
        while controller != nil {
            if let universal_Controller = controller as? SplitController {
                return universal_Controller
            }
            controller = controller?.parent
        }
        
        return nil
    }
}

// MARK: - UIView
extension UIView {
    func snapshot() -> UIView? {
        // Make an image from the input view.
        if let context = UIGraphicsGetCurrentContext() {
            UIGraphicsBeginImageContextWithOptions(self.bounds.size, false, 0)
            self.layer.render(in: context)
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            // Create an image view.
            let snapshot = UIImageView(image: image)
            
            snapshot.center = self.center
            
            snapshot.layer.masksToBounds = false
            snapshot.layer.cornerRadius = 0.0
            
            return snapshot
        }
        
        return nil
    }
}
