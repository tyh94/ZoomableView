import SwiftUI

public struct BounceZoomableView<Content: View>: View {
    @State private var transform: CGAffineTransform = .identity
    @State private var lastTransform: CGAffineTransform = .identity
    @State private var contentSize: CGSize = .zero
    
    let containerSize: CGSize
    @Binding var focusPoint: CGPoint?
    let content: () -> Content

    let maxOverdrag: CGFloat = 100
    let animationDuration = 0.3
    let doubleTapZoomScale: CGFloat = 2.0

    var minZoom: CGFloat {
        guard contentSize.width > 0 && contentSize.height > 0 else { return 1.0 }
        return min(
            containerSize.width / contentSize.width,
            containerSize.height / contentSize.height
        )
    }
    let maxZoom: CGFloat = 2

    public init(
        containerSize: CGSize,
        focusPoint: Binding<CGPoint?>,
        content: @escaping () -> Content
    ) {
        self.containerSize = containerSize
        _focusPoint = focusPoint
        self.content = content
    }
    
    public var body: some View {
        content()
            .scaledToFit()
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
            .onAppear {
                if contentSize != .zero {
                    // Вычисляем начальный масштаб чтобы вписать изображение
                    let initialScale = min(
                        containerSize.width / contentSize.width,
                        containerSize.height / contentSize.height
                    )
                    
                    transform = CGAffineTransform(scaleX: initialScale, y: initialScale)
                    lastTransform = transform
                }
            }
        //            .onChange(of: focusPoint) { newValue in
        //                if let point = newValue {
        //                    centerOn(point: point)
        //                    focusPoint = nil
        //                }
        //            }
    }
    
    @available(iOS, introduced: 16.0, deprecated: 17.0)
    private var oldMagnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let zoomFactor = 0.5
                let proposedScale = lastTransform.a * value * zoomFactor
                let clampedScale = min(max(proposedScale, minZoom), maxZoom)
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
                
                // Масштабируем относительно точки жеста
                let anchor = value.startAnchor.scaledBy(contentSize)
                let scaleTransform = CGAffineTransform.anchoredScale(
                    scale: scaleChange,
                    anchor: anchor
                )
                
                let newTransform = lastTransform.concatenating(scaleTransform)
                
                withAnimation(.interactiveSpring) {
                    transform = newTransform
                }
            }
            .onEnded { value in
                let proposedScale = lastTransform.a * value.magnification
                let clampedScale = min(max(proposedScale, minZoom), maxZoom)
                
                // ПЕРЕСЧИТЫВАЕМ позицию для нового масштаба чтобы сохранить центр
                let scaleRatio = clampedScale / lastTransform.a
                let anchor = value.startAnchor.scaledBy(contentSize)
                let scaleTransform = CGAffineTransform.anchoredScale(
                    scale: scaleRatio,
                    anchor: anchor
                )
                
                let newTransform = lastTransform.concatenating(scaleTransform)
                
                withAnimation(.interactiveSpring) {
                    transform = newTransform
                    lastTransform = transform
                }
                
                onEndGesture()
            }
    }
    
    private var doubleTapGesture: some Gesture {
        SpatialTapGesture(count: 2)
            .onEnded { value in
                let newTransform: CGAffineTransform =
                if abs(transform.a - 1.0) > .ulpOfOne {
                    .anchoredScale(scale: 1.0, anchor: value.location)
                } else {
                    .anchoredScale(scale: doubleTapZoomScale, anchor: value.location)
                }
                
                withAnimation(.linear(duration: 0.15)) {
                    transform = newTransform
                    lastTransform = newTransform
                }
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
    
    private func debugCenters() {
        let scale = transform.a
        let contentCenter = CGPoint(x: contentSize.width / 2, y: contentSize.height / 2)
        let containerCenter = CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
        
        // Правильное центрирование: центр контента должен совпадать с центром контейнера
        let expectedTx = containerCenter.x - contentCenter.x * scale
        let expectedTy = containerCenter.y - contentCenter.y * scale
        
        let limits = offsetLimits(for: scale)
        
        print("=== DEBUG CENTERS ===")
        print("Контейнер: центр в (\(containerCenter.x), \(containerCenter.y))")
        print("Контент: центр в (\(contentCenter.x), \(contentCenter.y))")
        print("Масштаб: \(scale)")
        print("Текущая трансформация: tx=\(transform.tx), ty=\(transform.ty)")
        print("Ожидаемая для центрирования: tx=\(expectedTx), ty=\(expectedTy)")
        print("Ограничения: X=\(limits.minX)...\(limits.maxX), Y=\(limits.minY)...\(limits.maxY)")
        
        // Проверяем, совпадает ли текущая позиция с центрированной
        let isCenteredX = abs(transform.tx - expectedTx) < 0.1
        let isCenteredY = abs(transform.ty - expectedTy) < 0.1
        print("По центру по X: \(isCenteredX), по Y: \(isCenteredY)")
        print("=====================")
    }

    // Вызывайте эту функцию в onEndGesture или где нужно
    
    private func onEndGesture() {
        debugCenters()
        print("🛑 onEndGesture — before clamping")
        print("transform (before): \(transform)")
        
        // Только ограничиваем позицию, масштаб уже ограничен в жестах
        let newTransform = limitedTransform(transform)
        
        print("🟢 onEndGesture — after clamping")
        print("transform (after): \(newTransform)")
        
        withAnimation(.easeOut(duration: animationDuration)) {
            transform = newTransform
            lastTransform = newTransform
        }
    }

    private func centerOn(point: CGPoint) {
        let containerCenter = containerSize.center
        let scale = transform.a
        let contentOrigin = CGPoint(x: containerCenter.x - contentSize.width * scale / 2, y: containerCenter.y - contentSize.height * scale / 2)
        let pointInView = CGPoint(x: contentOrigin.x + point.x * scale, y: contentOrigin.y + point.y * scale)
        let proposedOffset = CGSize(width: containerCenter.x - pointInView.x, height: containerCenter.y - pointInView.y)
        
        withAnimation(.easeInOut) {
            let newTransform = CGAffineTransform(translationX: proposedOffset.width, y: proposedOffset.height)
                .scaledBy(x: scale, y: scale)
            transform = limitedTransform(newTransform)
            lastTransform = transform
        }
    }

    private func limitedTransform(_ proposed: CGAffineTransform) -> CGAffineTransform {
        let scale = proposed.a
        
        // Получаем ограничения для текущего масштаба
        let limits = offsetLimits(for: scale)
        
        print("limitedTransform - current tx: \(proposed.tx), ty: \(proposed.ty)")
        print("limitedTransform - limits: X(\(limits.minX)...\(limits.maxX)), Y(\(limits.minY)...\(limits.maxY))")
        
        let tx: CGFloat
        let ty: CGFloat
        
        // Ограничиваем по X
        if limits.minX == limits.maxX {
            // Фиксируем по центру по X
            tx = limits.minX
            print("limitedTransform - fixed X to center: \(tx)")
        } else {
            // Ограничиваем прокрутку по X
            tx = min(max(proposed.tx, limits.minX), limits.maxX)
            print("limitedTransform - clamped X: \(proposed.tx) -> \(tx)")
        }
        
        // Ограничиваем по Y
        if limits.minY == limits.maxY {
            // Фиксируем по центру по Y
            ty = limits.minY
            print("limitedTransform - fixed Y to center: \(ty)")
        } else {
            // Ограничиваем прокрутку по Y
            ty = min(max(proposed.ty, limits.minY), limits.maxY)
            print("limitedTransform - clamped Y: \(proposed.ty) -> \(ty)")
        }
        
        let result = CGAffineTransform(
            a: proposed.a, b: proposed.b,
            c: proposed.c, d: proposed.d,
            tx: tx, ty: ty
        )
        
        print("limitedTransform - result: tx=\(tx), ty=\(ty)")
        return result
    }
    
    private func offsetLimits(for scale: CGFloat) -> (minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat) {
        let scaledWidth = contentSize.width * scale
        let scaledHeight = contentSize.height * scale
        
        // Вычисляем сколько "лишнего" пространства за границами контейнера
        let horizontalSpace = containerSize.width - scaledWidth
        let verticalSpace = containerSize.height - scaledHeight
        
        print("offsetLimits - scale: \(scale), scaled: \(scaledWidth)x\(scaledHeight)")
        print("offsetLimits - container: \(containerSize), spaces: h=\(horizontalSpace), v=\(verticalSpace)")
        
        if horizontalSpace >= 0 && verticalSpace >= 0 {
            // Изображение меньше контейнера по обоим осям - фиксируем по центру
            print("offsetLimits - full centering mode")
            return (0, 0, 0, 0)
        } else if horizontalSpace >= 0 {
            // Изображение меньше только по ширине - фиксируем по X, разрешаем прокрутку по Y
            print("offsetLimits - width centering mode")
            return (0, 0, verticalSpace, 0)
        } else if verticalSpace >= 0 {
            // Изображение меньше только по высоте - фиксируем по Y, разрешаем прокрутку по X
            print("offsetLimits - height centering mode")
            return (horizontalSpace, 0, 0, 0)
        } else {
            // Изображение больше контейнера по обоим осям - разрешаем прокрутку
            print("offsetLimits - scroll mode")
            return (horizontalSpace, 0, verticalSpace, 0)
        }
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
