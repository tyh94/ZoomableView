//
//  BounceZoomableView.swift
//  ZoomableView
//
//  Created by Татьяна Макеева on 01.12.2025.
//

import SwiftUI

public extension View {
    @ViewBuilder
    func zoomable(
        containerSize: CGSize,
        focusPoint: Binding<CGPoint?> = .constant(nil),
        minZoomScale: CGFloat = 1,
        maxZoomScale: CGFloat = 3,
        doubleTapZoomScale: CGFloat = 2,
        animationDuration: CGFloat = 0.3,
        logger: Logger? = nil
    ) -> some View {
        modifier(BounceZoomableViewModifier(
            containerSize: containerSize,
            focusPoint: focusPoint,
            minZoomScale: minZoomScale,
            maxZoomScale: maxZoomScale,
            doubleTapZoomScale: doubleTapZoomScale,
            animationDuration: animationDuration,
            logger: logger
        ))
    }
}

struct BounceZoomableViewModifier: ViewModifier {
    @State private var transform: CGAffineTransform = .identity
    @State private var lastTransform: CGAffineTransform = .identity
    @State private var contentSize: CGSize = .zero
    
    @State private var didHapticForScale = false
    @State private var didDoubleTap = false
    
    let containerSize: CGSize
    @Binding var focusPoint: CGPoint?

    let minZoomScale: CGFloat
    let maxZoomScale: CGFloat
    let doubleTapZoomScale: CGFloat
    let animationDuration: CGFloat
    let logger: Logger?
    
    func body(content: Content) -> some View {
        content
            .aspectRatio(contentMode: .fit)
            .modifier(AnimatableTransformEffect(transform: transform))
            .gesture(dragGesture)
            .modify { view in
                if #available(iOS 17.0, *) {
                    view.gesture(magnificationGesture)
                } else {
                    view.gesture(oldMagnificationGesture)
                }
            }
            .gesture(doubleTapGesture)
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { newValue in
                contentSize = newValue
            }
            .frame(width: containerSize.width, height: containerSize.height)
            .clipped()
            .background(Color.clear)
            .onChange(of: focusPoint) { newValue in
                if let point = newValue {
                    centerOn(point: point)
                    focusPoint = nil
                }
            }
            .modify { view in
                if #available(iOS 17.0, *) {
                    view
                        .sensoryFeedback(.impact(flexibility: .soft), trigger: didHapticForScale)
                        .sensoryFeedback(.selection, trigger: didDoubleTap)
                } else { view }
            }
    }
                
    @available(iOS, introduced: 16.0, deprecated: 17.0)
    private var oldMagnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let zoomFactor = 0.5
                let proposedScale = lastTransform.a * value * zoomFactor
                let clampedScale = min(max(proposedScale, minZoomScale), maxZoomScale)
                let scale = clampedScale / lastTransform.a
                
                transform = lastTransform.scaledBy(x: scale, y: scale)
            }
            .onEnded { _ in
                onEndGesture()
            }
    }

    @available(iOS 17.0, *)
    private var magnificationGesture: some Gesture {
        MagnifyGesture(minimumScaleDelta: 0)
            .onChanged { value in
                let scaleChange = value.magnification
                let proposedScale = lastTransform.a * scaleChange
                let clampedScale = min(max(proposedScale, minZoomScale), maxZoomScale)

                if proposedScale != clampedScale {
                    if didHapticForScale == false {
                        didHapticForScale = true
                    }
                } else {
                    didHapticForScale = false
                }

                let anchor = value.startAnchor.scaledBy(contentSize)
                let newTransform = CGAffineTransform.anchoredScale(
                    scale: scaleChange,
                    anchor: anchor,
                    currentTransform: lastTransform
                )

                withAnimation(.interactiveSpring) {
                    transform = newTransform
                }
            }
            .onEnded { value in
                didHapticForScale = false

                let proposedScale = lastTransform.a * value.magnification
                let clampedScale = min(max(proposedScale, minZoomScale), maxZoomScale)

                let scaleRatio = clampedScale / lastTransform.a
                let anchor = value.startAnchor.scaledBy(contentSize)
                let newTransform = CGAffineTransform.anchoredScale(
                    scale: scaleRatio,
                    anchor: anchor,
                    currentTransform: lastTransform
                )

                withAnimation(.interactiveSpring) {
                    transform = newTransform
                    lastTransform = newTransform
                }

                onEndGesture()
            }
    }
    
    private var doubleTapGesture: some Gesture {
        SpatialTapGesture(count: 2)
            .onEnded { value in
                didDoubleTap = true
                let targetScale: CGFloat = abs(transform.a - 1.0) > .ulpOfOne ? 1.0 : doubleTapZoomScale
                
                let newTransform = CGAffineTransform.anchoredScale(
                    scale: targetScale / transform.a,
                    anchor: value.location,
                    currentTransform: transform
                )
                
                withAnimation(.linear(duration: animationDuration)) {
                    transform = newTransform
                    lastTransform = newTransform
                    didDoubleTap = false
                }
                onEndGesture()
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                withAnimation(.interactiveSpring) {
                    transform = lastTransform.translatedBy(
                        x: value.translation.width / transform.scaleX,
                        y: value.translation.height / transform.scaleY
                    )
                }
            }
            .onEnded { _ in
                onEndGesture()
            }
    }
    
    private func onEndGesture() {
        logger?.debug("content: \(contentSize) container: \(containerSize)")
        logger?.debug("🛑 onEndGesture — before clamping")
        logger?.debug("transform (before): \(transform)")
        
        let newTransform = limitedTransform(transform)
        
        logger?.debug("🟢 onEndGesture — after clamping")
        logger?.debug("transform (after): \(newTransform)")
        
        withAnimation(.easeOut(duration: animationDuration)) {
            transform = newTransform
            lastTransform = newTransform
        }
    }

    private func centerOn(point: CGPoint) {
        let containerCenter = containerSize.center
        let contentOrigin = CGPoint(x: containerCenter.x - contentSize.width / 2, y: containerCenter.y - contentSize.height / 2)
        let pointInView = CGPoint(x: contentOrigin.x + point.x, y: contentOrigin.y + point.y)
        let proposedOffset = CGSize(width: containerCenter.x - pointInView.x, height: containerCenter.y - pointInView.y)
        let newTransform = CGAffineTransform(translationX: proposedOffset.width, y: proposedOffset.height)
        
        withAnimation(.easeInOut) {
            transform = limitedTransform(newTransform)
            lastTransform = transform
        }
    }

    private func limitedTransform(_ proposed: CGAffineTransform) -> CGAffineTransform {
        let scale = proposed.a
        let limits = offsetLimits(for: scale)
        
        var tx = proposed.tx
        var ty = proposed.ty
        
        if abs(limits.minX - limits.maxX) < .ulpOfOne {
            tx = limits.minX
        } else {
            tx = min(max(proposed.tx, limits.minX), limits.maxX)
        }
        
        if abs(limits.minY - limits.maxY) < .ulpOfOne {
            ty = limits.minY
        } else {
            ty = min(max(proposed.ty, limits.minY), limits.maxY)
        }
        
        return CGAffineTransform(
            a: proposed.a, b: proposed.b,
            c: proposed.c, d: proposed.d,
            tx: tx, ty: ty
        )
    }
    
    private func offsetLimits(for scale: CGFloat) -> (minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat) {
        let scaledWidth = contentSize.width * scale
        let scaledHeight = contentSize.height * scale
        
        logger?.debug("=== offsetLimits Debug ===")
        logger?.debug("contentSize: \(contentSize)")
        logger?.debug("containerSize: \(containerSize)")
        logger?.debug("scale: \(scale)")
        
        let minX: CGFloat
        let maxX: CGFloat
        let minY: CGFloat
        let maxY: CGFloat
        
        let initialOffsetX = (containerSize.width - contentSize.width) / 2
        if scaledWidth <= containerSize.width {
            let allowance = (containerSize.width - scaledWidth) / 2
            minX = allowance - initialOffsetX
            maxX = allowance - initialOffsetX
            logger?.debug("Horizontal: Centering, allowance = \(allowance)")
        } else {
            minX = containerSize.width - scaledWidth - initialOffsetX
            maxX = -initialOffsetX
            logger?.debug("Horizontal: Constraining with initial offset, minX = \(minX), maxX = \(maxX)")
        }
        
        let initialOffsetY = (containerSize.height - contentSize.height) / 2
        if scaledHeight <= containerSize.height {
            let allowance = (containerSize.height - scaledHeight) / 2
            minY = allowance - initialOffsetY
            maxY = allowance - initialOffsetY
            logger?.debug("Vertical: Centering, allowance = \(allowance)")
        } else {
            minY = containerSize.height - scaledHeight - initialOffsetY
            maxY = -initialOffsetY
            logger?.debug("Vertical: Constraining with initial offset, minY = \(minY), maxY = \(maxY)")
        }
        
        logger?.debug("Result: minX=\(minX), maxX=\(maxX), minY=\(minY), maxY=\(maxY)")
        logger?.debug("=== End Debug ===")
        
        return (minX, maxX, minY, maxY)
    }
}

extension View {
    @ViewBuilder
    fileprivate func modify(@ViewBuilder _ fn: (Self) -> some View) -> some View {
        fn(self)
    }
}

extension CGSize {
    fileprivate var center: CGPoint {
        CGPoint(x: width / 2.0, y: height / 2.0)
    }
}

extension UnitPoint {
    fileprivate func scaledBy(_ size: CGSize) -> CGPoint {
        CGPoint(
            x: x * size.width,
            y: y * size.height
        )
    }
}

extension CGAffineTransform {
    fileprivate static func anchoredScale(scale: CGFloat, anchor: CGPoint, currentTransform: CGAffineTransform) -> CGAffineTransform {
        // Точка привязки в координатах контента
        let anchorInContent = CGPoint(
            x: (anchor.x - currentTransform.tx) / currentTransform.a,
            y: (anchor.y - currentTransform.ty) / currentTransform.d
        )
        
        // Создаем трансформ масштабирования относительно этой точки
        return CGAffineTransform(translationX: anchorInContent.x, y: anchorInContent.y)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -anchorInContent.x, y: -anchorInContent.y)
            .concatenating(currentTransform)
    }
    
    fileprivate static func anchoredScale(scale: CGFloat, anchor: CGPoint) -> CGAffineTransform {
        CGAffineTransform(translationX: anchor.x, y: anchor.y)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -anchor.x, y: -anchor.y)
    }
    
    fileprivate var scaleX: CGFloat {
        sqrt(a * a + c * c)
    }

    fileprivate var scaleY: CGFloat {
        sqrt(b * b + d * d)
    }
}

struct AnimatableTransformEffect: GeometryEffect {
    var transform: CGAffineTransform
    
    var animatableData: AnimatablePair<
        AnimatablePair<CGFloat, CGFloat>,
        AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>>
    > {
        get {
            AnimatablePair(
                AnimatablePair(transform.a, transform.b),
                AnimatablePair(
                    AnimatablePair(transform.c, transform.d),
                    AnimatablePair(transform.tx, transform.ty)
                )
            )
        }
        set {
            transform = CGAffineTransform(
                a: newValue.first.first,
                b: newValue.first.second,
                c: newValue.second.first.first,
                d: newValue.second.first.second,
                tx: newValue.second.second.first,
                ty: newValue.second.second.second
            )
        }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(transform)
    }
}
