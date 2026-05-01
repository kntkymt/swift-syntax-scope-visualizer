import SRTDOM
import React
import Pages

let body = try JSWindow.global.document.body.unwrap("body")
let root = ReactRoot(element: body)
let content = RootView()
root.render(node: content)
