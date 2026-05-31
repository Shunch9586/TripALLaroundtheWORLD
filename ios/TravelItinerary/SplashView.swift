import UIKit

final class TravelSplashView: UIView {
    private let backgroundView = BackgroundView()
    private let contentView = UIView()
    private let bookView = SplashBookView()
    private let trailLayer = CAShapeLayer()
    private let planeLayer = CAShapeLayer()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private var didStartAnimation = false

    static func show(in window: UIWindow) {
        let splashView = TravelSplashView(frame: window.bounds)
        splashView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(splashView)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundView.frame = bounds
        backgroundView.updateLayout()
        layoutTrailAndPlane()

        if !didStartAnimation {
            didStartAnimation = true
            DispatchQueue.main.async { [weak self] in
                self?.runAnimation()
            }
        }
    }

    private func setup() {
        isOpaque = true
        backgroundColor = Palette.backgroundBottom

        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        bookView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(backgroundView)
        addSubview(contentView)
        contentView.addSubview(bookView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)

        trailLayer.fillColor = UIColor.clear.cgColor
        trailLayer.strokeColor = Palette.primary.withAlphaComponent(0.92).cgColor
        trailLayer.lineWidth = 3
        trailLayer.lineCap = .round
        trailLayer.lineJoin = .round
        trailLayer.strokeEnd = 0
        layer.addSublayer(trailLayer)

        planeLayer.path = planePath().cgPath
        planeLayer.fillColor = Palette.primary.cgColor
        planeLayer.strokeColor = Palette.primaryStrong.withAlphaComponent(0.55).cgColor
        planeLayer.lineWidth = 1.2
        planeLayer.shadowColor = Palette.primary.cgColor
        planeLayer.shadowOpacity = 0.7
        planeLayer.shadowRadius = 12
        planeLayer.shadowOffset = .zero
        layer.addSublayer(planeLayer)

        titleLabel.text = "旅遊行程"
        titleLabel.textColor = Palette.text
        titleLabel.textAlignment = .center
        titleLabel.font = .systemFont(ofSize: 24, weight: .black)
        titleLabel.alpha = 0

        subtitleLabel.text = "行程與回憶，隨身保存"
        subtitleLabel.textColor = Palette.muted
        subtitleLabel.textAlignment = .center
        subtitleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        subtitleLabel.alpha = 0

        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentView.centerXAnchor.constraint(equalTo: centerXAnchor),
            contentView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -18),
            contentView.widthAnchor.constraint(equalTo: widthAnchor),
            contentView.heightAnchor.constraint(equalToConstant: 270),

            bookView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            bookView.topAnchor.constraint(equalTo: contentView.topAnchor),
            bookView.widthAnchor.constraint(equalToConstant: 210),
            bookView.heightAnchor.constraint(equalToConstant: 142),

            titleLabel.topAnchor.constraint(equalTo: bookView.bottomAnchor, constant: 34),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
        ])

        contentView.alpha = 0
        contentView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95).translatedBy(x: 0, y: 10)
    }

    private func runAnimation() {
        if UIAccessibility.isReduceMotionEnabled {
            runReducedMotionAnimation()
            return
        }

        let flightPath = trailPath()
        trailLayer.path = flightPath.cgPath
        planeLayer.position = flightPath.currentPoint

        UIView.animate(withDuration: 0.34, delay: 0, options: [.curveEaseOut]) {
            self.contentView.alpha = 1
            self.contentView.transform = .identity
        }

        let trailAnimation = CABasicAnimation(keyPath: "strokeEnd")
        trailAnimation.fromValue = 0
        trailAnimation.toValue = 1
        trailAnimation.duration = 0.78
        trailAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        trailLayer.strokeEnd = 1
        trailLayer.add(trailAnimation, forKey: "strokeEnd")

        let planeAnimation = CAKeyframeAnimation(keyPath: "position")
        planeAnimation.path = flightPath.cgPath
        planeAnimation.duration = 0.78
        planeAnimation.calculationMode = .paced
        planeAnimation.rotationMode = .rotateAuto
        planeAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        planeLayer.add(planeAnimation, forKey: "position")
        planeLayer.position = flightPath.currentPoint

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            self.bookView.open()
        }

        UIView.animate(withDuration: 0.34, delay: 0.72, options: [.curveEaseOut]) {
            self.titleLabel.alpha = 1
            self.subtitleLabel.alpha = 1
        }

        UIView.animate(withDuration: 0.34, delay: 1.45, options: [.curveEaseInOut]) {
            self.alpha = 0
            self.contentView.transform = CGAffineTransform(scaleX: 1.06, y: 1.06)
        } completion: { _ in
            self.removeFromSuperview()
        }
    }

    private func runReducedMotionAnimation() {
        UIView.animate(withDuration: 0.28, delay: 0, options: [.curveEaseOut]) {
            self.contentView.alpha = 1
            self.titleLabel.alpha = 1
            self.subtitleLabel.alpha = 1
            self.contentView.transform = .identity
        }

        UIView.animate(withDuration: 0.25, delay: 0.9, options: [.curveEaseInOut]) {
            self.alpha = 0
        } completion: { _ in
            self.removeFromSuperview()
        }
    }

    private func layoutTrailAndPlane() {
        trailLayer.frame = bounds
        planeLayer.bounds = CGRect(x: 0, y: 0, width: 44, height: 44)
        planeLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
    }

    private func trailPath() -> UIBezierPath {
        let center = CGPoint(x: bounds.midX, y: bounds.midY - 58)
        let path = UIBezierPath()
        path.move(to: CGPoint(x: -52, y: center.y + 18))
        path.addCurve(
            to: CGPoint(x: bounds.width + 58, y: center.y - 28),
            controlPoint1: CGPoint(x: bounds.width * 0.18, y: center.y - 38),
            controlPoint2: CGPoint(x: bounds.width * 0.70, y: center.y + 42)
        )
        return path
    }

    private func planePath() -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 34, y: 22))
        path.addLine(to: CGPoint(x: 7, y: 9))
        path.addCurve(to: CGPoint(x: 10, y: 20), controlPoint1: CGPoint(x: 5, y: 13), controlPoint2: CGPoint(x: 6, y: 18))
        path.addLine(to: CGPoint(x: 18, y: 23))
        path.addLine(to: CGPoint(x: 10, y: 32))
        path.addCurve(to: CGPoint(x: 19, y: 30), controlPoint1: CGPoint(x: 13, y: 33), controlPoint2: CGPoint(x: 17, y: 32))
        path.addLine(to: CGPoint(x: 34, y: 24))
        path.addCurve(to: CGPoint(x: 34, y: 22), controlPoint1: CGPoint(x: 36, y: 23), controlPoint2: CGPoint(x: 36, y: 22))
        path.close()
        return path
    }
}

private final class SplashBookView: UIView {
    private let leftPage = UIView()
    private let rightPage = UIView()
    private let spine = UIView()
    private let routeLayer = CAShapeLayer()
    private let leftLineLayer = CAShapeLayer()
    private let rightLineLayer = CAShapeLayer()
    private let pinView = UIView()
    private let dayLabel = UILabel()
    private let shadowView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        shadowView.frame = bounds.insetBy(dx: 9, dy: 12).offsetBy(dx: 0, dy: 16)
        leftPage.frame = CGRect(x: bounds.midX - 82, y: 20, width: 82, height: 112)
        rightPage.frame = CGRect(x: bounds.midX, y: 20, width: 82, height: 112)
        spine.frame = CGRect(x: bounds.midX - 3, y: 18, width: 6, height: 116)
        pinView.frame = CGRect(x: rightPage.frame.midX + 18, y: rightPage.frame.minY + 58, width: 12, height: 12)
        dayLabel.frame = CGRect(x: leftPage.frame.minX + 14, y: leftPage.frame.minY + 16, width: 54, height: 20)

        routeLayer.frame = bounds
        routeLayer.path = routePath().cgPath
        leftLineLayer.frame = bounds
        leftLineLayer.path = pageLines(in: leftPage.frame.insetBy(dx: 14, dy: 36)).cgPath
        rightLineLayer.frame = bounds
        rightLineLayer.path = pageLines(in: rightPage.frame.insetBy(dx: 14, dy: 28)).cgPath
    }

    func open() {
        routeLayer.strokeEnd = 1
        leftLineLayer.strokeEnd = 1
        rightLineLayer.strokeEnd = 1

        UIView.animate(withDuration: 0.42, delay: 0, usingSpringWithDamping: 0.78, initialSpringVelocity: 0.28, options: [.curveEaseOut]) {
            self.leftPage.transform = CGAffineTransform(scaleX: 1.05, y: 1).translatedBy(x: -16, y: 0)
            self.rightPage.transform = CGAffineTransform(scaleX: 1.05, y: 1).translatedBy(x: 16, y: 0)
            self.spine.alpha = 1
            self.dayLabel.alpha = 1
            self.pinView.alpha = 1
        }

        animateStroke(layer: routeLayer, duration: 0.38, delay: 0.16)
        animateStroke(layer: leftLineLayer, duration: 0.32, delay: 0.18)
        animateStroke(layer: rightLineLayer, duration: 0.32, delay: 0.22)
    }

    private func setup() {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.42
        layer.shadowRadius = 26
        layer.shadowOffset = CGSize(width: 0, height: 18)

        shadowView.backgroundColor = UIColor.black.withAlphaComponent(0.22)
        shadowView.layer.cornerRadius = 34
        shadowView.layer.masksToBounds = true
        addSubview(shadowView)

        [leftPage, rightPage].forEach { page in
            page.backgroundColor = Palette.panelStrong
            page.layer.borderWidth = 1
            page.layer.borderColor = Palette.border.cgColor
            page.layer.cornerRadius = 18
            page.layer.masksToBounds = true
            addSubview(page)
        }

        leftPage.transform = CGAffineTransform(scaleX: 0.52, y: 1).translatedBy(x: 68, y: 0)
        rightPage.transform = CGAffineTransform(scaleX: 0.52, y: 1).translatedBy(x: -68, y: 0)

        spine.backgroundColor = Palette.primary.withAlphaComponent(0.42)
        spine.layer.cornerRadius = 3
        spine.alpha = 0.35
        addSubview(spine)

        routeLayer.fillColor = UIColor.clear.cgColor
        routeLayer.strokeColor = Palette.primary.cgColor
        routeLayer.lineWidth = 2.4
        routeLayer.lineCap = .round
        routeLayer.strokeEnd = 0
        layer.addSublayer(routeLayer)

        [leftLineLayer, rightLineLayer].forEach { layer in
            layer.fillColor = UIColor.clear.cgColor
            layer.strokeColor = Palette.muted.withAlphaComponent(0.46).cgColor
            layer.lineWidth = 2
            layer.lineCap = .round
            layer.strokeEnd = 0
            self.layer.addSublayer(layer)
        }

        pinView.backgroundColor = Palette.accent
        pinView.layer.cornerRadius = 6
        pinView.layer.shadowColor = Palette.accent.cgColor
        pinView.layer.shadowOpacity = 0.72
        pinView.layer.shadowRadius = 10
        pinView.layer.shadowOffset = .zero
        pinView.alpha = 0
        addSubview(pinView)

        dayLabel.text = "DAY"
        dayLabel.textAlignment = .center
        dayLabel.textColor = Palette.primaryStrong
        dayLabel.backgroundColor = Palette.primary
        dayLabel.font = .systemFont(ofSize: 10, weight: .black)
        dayLabel.layer.cornerRadius = 10
        dayLabel.layer.masksToBounds = true
        dayLabel.alpha = 0
        addSubview(dayLabel)
    }

    private func routePath() -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: bounds.midX - 44, y: 93))
        path.addCurve(
            to: CGPoint(x: bounds.midX + 48, y: 84),
            controlPoint1: CGPoint(x: bounds.midX - 16, y: 52),
            controlPoint2: CGPoint(x: bounds.midX + 26, y: 120)
        )
        return path
    }

    private func pageLines(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        for offset in stride(from: CGFloat(0), through: rect.height, by: 18) {
            let y = rect.minY + offset
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return path
    }

    private func animateStroke(layer: CAShapeLayer, duration: CFTimeInterval, delay: CFTimeInterval) {
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = 0
        animation.toValue = 1
        animation.duration = duration
        animation.beginTime = CACurrentMediaTime() + delay
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(animation, forKey: "strokeEnd")
    }
}
