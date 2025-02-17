/*
Copyright 2019-2024 New Vector Ltd.

SPDX-License-Identifier: AGPL-3.0-only
Please see LICENSE in the repository root for full details.
 */

import Foundation

extension UIView {
    
    /// Add a subview matching parent view using autolayout
    @objc func vc_addSubViewMatchingParent(_ subView: UIView) {
        self.addSubview(subView)
        subView.translatesAutoresizingMaskIntoConstraints = false
        let views = ["view": subView]
        ["H:|[view]|", "V:|[view]|"].forEach { vfl in
            let constraints = NSLayoutConstraint.constraints(withVisualFormat: vfl,
                                                             options: [],
                                                             metrics: nil,
                                                             views: views)
            constraints.forEach { $0.isActive = true }
        }
    }
    
    /// Add a subview matching the safe area of the parent view using autolayout
    @objc func vc_addSubViewMatchingParentSafeArea(_ subView: UIView) {
        self.addSubview(subView)
        subView.translatesAutoresizingMaskIntoConstraints = false
        subView.leadingAnchor.constraint(equalTo: self.safeAreaLayoutGuide.leadingAnchor).isActive = true
        subView.topAnchor.constraint(equalTo: self.safeAreaLayoutGuide.topAnchor).isActive = true
        subView.trailingAnchor.constraint(equalTo: self.safeAreaLayoutGuide.trailingAnchor).isActive = true
        subView.bottomAnchor.constraint(equalTo: self.safeAreaLayoutGuide.bottomAnchor).isActive = true
    }
    
    /// Add a subview matching parent view with additional insets using autolayout
    @objc func vc_addSubViewMatchingParent(_ subView: UIView, withInsets insets: UIEdgeInsets) {
        self.addSubview(subView)
        subView.translatesAutoresizingMaskIntoConstraints = false
        subView.leadingAnchor.constraint(equalTo: self.safeAreaLayoutGuide.leadingAnchor, constant: insets.left).isActive = true
        subView.topAnchor.constraint(equalTo: self.safeAreaLayoutGuide.topAnchor, constant: insets.top).isActive = true
        subView.trailingAnchor.constraint(equalTo: self.safeAreaLayoutGuide.trailingAnchor, constant: insets.right).isActive = true
        subView.bottomAnchor.constraint(equalTo: self.safeAreaLayoutGuide.bottomAnchor, constant: insets.bottom).isActive = true
    }
    
    @objc func vc_removeAllSubviews() {
        for subView in self.subviews {
            subView.removeFromSuperview()
        }
    }
    
    /// Shake the view to indicate an error
    @objc func vc_shake() {
        let shake = CABasicAnimation(keyPath: "position")
        let xDelta = CGFloat(10)
        shake.duration = 0.07
        shake.repeatCount = 2
        shake.autoreverses = true

        let fromPoint = CGPoint(x: center.x - xDelta, y: center.y)
        let toPoint = CGPoint(x: center.x + xDelta, y: center.y)

        shake.fromValue = NSValue(cgPoint: fromPoint)
        shake.toValue = NSValue(cgPoint: toPoint)
        shake.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(shake, forKey: "position")
    }
    
    @objc func vc_setupAccessibilityTraitsButton(withTitle title: String, hint: String, isEnabled: Bool) {
        self.isAccessibilityElement = true
        self.accessibilityLabel = title
        self.accessibilityHint = hint
        self.accessibilityTraits = .button
        if !isEnabled {
            self.accessibilityTraits.insert(.notEnabled)
        }
    }
    
    @objc func vc_setupAccessibilityTraitsImage(withTitle title: String) {
        self.isAccessibilityElement = false
        self.accessibilityLabel = title
        self.accessibilityHint = nil
        self.accessibilityTraits = .image
    }
    
    @objc func vc_addShadow(withColor color: UIColor, offset: CGSize, radius: CGFloat, opacity: CGFloat) {
        layer.shadowColor = color.cgColor
        layer.shadowOpacity = Float(opacity)
        layer.shadowRadius = radius
        layer.shadowOffset = offset
    }
    
    @objc func vc_removeShadow() {
        layer.shadowColor = UIColor.clear.cgColor
    }
    
    /// Tchap categories
    func tc_mask(withPath path: UIBezierPath, inverse: Bool = false) {
        let path = path
        let maskLayer = CAShapeLayer()
        
        if inverse {
            path.append(UIBezierPath(rect: self.bounds))
            maskLayer.fillRule = CAShapeLayerFillRule.evenOdd
        }
        
        maskLayer.path = path.cgPath
        
        self.layer.mask = maskLayer
    }
    
    func tc_makeCircle() {
        let minDimension = min(self.bounds.size.width, self.bounds.size.height)
        self.layer.cornerRadius = minDimension/2
        self.layer.masksToBounds = true
        self.layer.mask = nil
    }
    
}
