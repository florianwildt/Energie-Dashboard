import SwiftUI
import UIKit

struct FlowConnection {
    var from: CGPoint
    var to: CGPoint
    var color: UIColor
    var power: Double?
}

struct FlowConnectionsView: UIViewRepresentable {
    var connections: [FlowConnection]
    var animated: Bool
    var colorScheme: ColorScheme

    func makeUIView(context: Context) -> FlowLinesUIView { FlowLinesUIView() }

    func updateUIView(_ uiView: FlowLinesUIView, context: Context) {
        let span = PerformanceLog.shared.begin("flow.layers.update")
        defer { PerformanceLog.shared.end(span) }
        uiView.update(connections: connections, animated: animated)
    }

    static func dismantleUIView(_ uiView: FlowLinesUIView, coordinator: ()) { uiView.stop() }
}

final class FlowLinesUIView: UIView {
    private var routes: [CAShapeLayer] = []
    private var animationDirections: [Int] = []
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        isAccessibilityElement = false
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func update(connections: [FlowConnection], animated: Bool) {
        while routes.count < connections.count {
            let route = CAShapeLayer()
            route.fillColor = nil
            route.lineCap = .round
            routes.append(route)
            animationDirections.append(0)
            layer.addSublayer(route)
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, connection) in connections.enumerated() {
            let route = routes[index]
            let path = CGMutablePath()
            path.move(to: connection.from)
            path.addLine(to: connection.to)
            route.path = path
            let flowing = connection.power.map { abs($0) > 0.05 } ?? false
            route.lineWidth = flowing ? 2 : 1
            route.strokeColor = (flowing ? connection.color.withAlphaComponent(0.65) : UIColor.secondaryLabel.withAlphaComponent(0.15)).cgColor
            route.lineDashPattern = flowing ? [3, 9] : nil
            let direction = flowing && animated ? ((connection.power ?? 0) < 0 ? 1 : -1) : 0
            if direction != animationDirections[index] || (direction != 0 && route.animation(forKey: "flow") == nil) {
                route.removeAnimation(forKey: "flow")
                if direction != 0 {
                    let animation = CABasicAnimation(keyPath: "lineDashPhase")
                    // One dash cycle only. Never pass an absolute date as a phase.
                    animation.fromValue = 0
                    animation.toValue = Double(direction) * 12
                    animation.duration = 12.0 / 14.0
                    animation.repeatCount = .infinity
                    animation.timingFunction = CAMediaTimingFunction(name: .linear)
                    route.add(animation, forKey: "flow")
                }
                animationDirections[index] = direction
            }
        }
        CATransaction.commit()
    }

    func stop() {
        for route in routes { route.removeAllAnimations() }
        animationDirections = Array(repeating: 0, count: routes.count)
    }
}
