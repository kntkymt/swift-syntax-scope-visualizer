import React
import SwiftReactPlus

internal struct LicensesPane: Component {
    @Binding var showLicenses: Bool

    var deps: Deps? {
        [_showLicenses]
    }

    func render() -> Node {
        Pane(
            header: {
                div(
                    style: .init()
                        .display("flex")
                        .flexDirection("row")
                        .alignItems("center")
                        .gap("8px")
                ) {
                    h4(style: .init().margin("0")) { "Licenses" }

                    Button(onClick: Function { showLicenses = false }) {
                        "Back"
                    }
                }
            },
            border: []
        ) {
            pre(
                style: .init()
                    .margin("0")
                    .whiteSpace("pre-wrap")
                    .wordBreak("break-word")
                    .fontSize("13px")
                    .lineHeight("1.5")
            ) {
                licensesMarkdown
            }
        }
    }
}
