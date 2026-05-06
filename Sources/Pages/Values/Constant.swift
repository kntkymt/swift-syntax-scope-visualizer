enum Constant {
    static let initialSourceCode = """
        func f() {
            let a = 1
            if let b = value() {
                let c = 3
            }

            guard let d = value() else {
                let e = 4
            }
            let f = 5
        }
        """

    static let githubURL = "https://github.com/kntkymt/swift-syntax-scope-visualizer"
}
