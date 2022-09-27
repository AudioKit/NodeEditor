// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/Flow/

import SwiftUI

extension GraphicsContext {
    @inlinable @inline(__always)
    func drawDot(in rect: CGRect, with shading: Shading) {
        let dot = Path(ellipseIn: rect.insetBy(dx: rect.size.width / 3, dy: rect.size.height / 3))
        fill(dot, with: shading)
    }

    func drawInputPort(
        node: Node,
        index: Int,
        layout: LayoutConstants,
        offset: CGSize,
        portColor: Color,
        isConnected: Bool,
        textCache: TextCache
    ) {
        let rect = node.inputRect(input: index, layout: layout).offset(by: offset)
        let circle = Path(ellipseIn: rect)
        let port = node.inputs[index]

        fill(circle, with: .color(portColor))

        if !isConnected {
            drawDot(in: rect, with: .color(.black))
        }

        draw(
            textCache.text(string: port.name, caption: true, self),
            at: rect.center + CGSize(width: layout.portSize.width / 2 + layout.portSpacing, height: 0),
            anchor: .leading
        )
    }

    func strokeWire(
        from: CGPoint,
        to: CGPoint,
        gradient: Gradient
    ) {
        let d = 0.4 * abs(to.x - from.x)
        var path = Path()
        path.move(to: from)
        path.addCurve(
            to: to,
            control1: CGPoint(x: from.x + d, y: from.y),
            control2: CGPoint(x: to.x - d, y: to.y)
        )

        stroke(
            path,
            with: .linearGradient(gradient, startPoint: from, endPoint: to),
            style: StrokeStyle(lineWidth: 2.0, lineCap: .round)
        )
    }

    func drawOutputPort(
        node: Node,
        index: Int,
        layout: LayoutConstants,
        offset: CGSize,
        portColor: Color,
        isConnected: Bool,
        textCache: TextCache
    ) {
        let rect = node.outputRect(output: index, layout: layout).offset(by: offset)
        let circle = Path(ellipseIn: rect)
        let port = node.outputs[index]

        fill(circle, with: .color(portColor))

        if !isConnected {
            drawDot(in: rect, with: .color(.black))
        }

        draw(textCache.text(string: port.name, caption: true, self),
             at: rect.center + CGSize(width: -(layout.portSize.width / 2 + layout.portSpacing), height: 0),
             anchor: .trailing)
    }
}

extension NodeEditor {
    @inlinable @inline(__always)
    func color(for type: PortType, isOutput: Bool) -> Color {
        style.color(for: type, isOutput: isOutput) ?? .gray
    }

    /// Draw a node.
    func draw(
        node: Node,
        nodeIndex: NodeIndex,
        cx: GraphicsContext,
        viewport: CGRect,
        connectedInputs: Set<InputID>,
        connectedOutputs: Set<OutputID>,
        selectedShading: GraphicsContext.Shading,
        unselectedShading: GraphicsContext.Shading
    ) {
        let offset = self.offset(for: nodeIndex)
        let rect = node.rect(layout: layout).offset(by: offset)

        guard rect.intersects(viewport) else { return }

        let pos = rect.origin

        let bg = Path(roundedRect: rect, cornerRadius: 5)

        var selected = false
        switch dragInfo {
        case let .selection(rect: selectionRect):
            selected = rect.intersects(selectionRect)
        default:
            selected = selection.contains(nodeIndex)
        }

        cx.fill(bg, with: selected ? selectedShading : unselectedShading)

        cx.draw(textCache.text(string: node.name, caption: false, cx),
                at: pos + CGSize(width: rect.size.width / 2, height: 20),
                anchor: .center)

        for (i, input) in node.inputs.enumerated() {
            let portColor = color(for: input.type, isOutput: false)

            cx.drawInputPort(
                node: node,
                index: i,
                layout: layout,
                offset: offset,
                portColor: portColor,
                isConnected: connectedInputs.contains(InputID(nodeIndex, i)),
                textCache: textCache
            )
        }

        for (i, output) in node.outputs.enumerated() {
            let portColor = color(for: output.type, isOutput: true)

            cx.drawOutputPort(
                node: node,
                index: i,
                layout: layout,
                offset: offset,
                portColor: portColor,
                isConnected: connectedOutputs.contains(OutputID(nodeIndex, i)),
                textCache: textCache
            )
        }
    }

    func drawNodes(cx: GraphicsContext, viewport: CGRect) {

        let connectedInputs = Set( patch.wires.map { wire in wire.input } )
        let connectedOutputs = Set( patch.wires.map { wire in wire.output } )

        let selectedShading = cx.resolve(.color(style.nodeColor.opacity(0.8)))
        let unselectedShading = cx.resolve(.color(style.nodeColor.opacity(0.4)))

        for (idx, node) in patch.nodes.enumerated() {
            draw(node: node,
                 nodeIndex: idx,
                 cx: cx,
                 viewport: viewport,
                 connectedInputs: connectedInputs,
                 connectedOutputs: connectedOutputs,
                 selectedShading: selectedShading,
                 unselectedShading: unselectedShading)
        }
    }

    func drawWires(cx: GraphicsContext, viewport: CGRect) {
        var hideWire: Wire?
        switch dragInfo {
        case let .wire(_, _, hideWire: hw):
            hideWire = hw
        default:
            hideWire = nil
        }
        for wire in patch.wires where wire != hideWire {
            let fromPoint = self.patch.nodes[wire.output.nodeIndex].outputRect(
                output: wire.output.portIndex,
                layout: self.layout
            )
            .offset(by: self.offset(for: wire.output.nodeIndex)).center

            let toPoint = self.patch.nodes[wire.input.nodeIndex].inputRect(
                input: wire.input.portIndex,
                layout: self.layout
            )
            .offset(by: self.offset(for: wire.input.nodeIndex)).center

            let bounds = CGRect(origin: fromPoint, size: toPoint - fromPoint)
            if viewport.intersects(bounds) {
                let gradient = self.gradient(for: wire)
                cx.strokeWire(from: fromPoint, to: toPoint, gradient: gradient)
            }
        }
    }

    func drawDraggedWire(cx: GraphicsContext) {
        if case let .wire(output: output, offset: offset, _) = dragInfo {
            let outputRect = self.patch
                .nodes[output.nodeIndex]
                .outputRect(output: output.portIndex, layout: self.layout)
            let gradient = self.gradient(for: output)
            cx.strokeWire(from: outputRect.center, to: outputRect.center + offset, gradient: gradient)
        }
    }

    func drawSelectionRect(cx: GraphicsContext) {
        if case let .selection(rect: rect) = dragInfo {
            let rectPath = Path(roundedRect: rect, cornerRadius: 0)
            cx.stroke(rectPath, with: .color(.cyan))
        }
    }

    func gradient(for outputID: OutputID) -> Gradient {
        let portType = patch
            .nodes[outputID.nodeIndex]
            .outputs[outputID.portIndex]
            .type
        return style.gradient(for: portType) ?? .init(colors: [.gray])
    }

    func gradient(for wire: Wire) -> Gradient {
        gradient(for: wire.output)
    }
}
