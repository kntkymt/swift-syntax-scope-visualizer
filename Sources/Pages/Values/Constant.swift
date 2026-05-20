enum Constant {
    static let initialSourceCode = """
        func f() {
            let a = 1
            if let a = Optional(2) {
                print(a)
            }
            guard let a = Optional(3) else {
                print(a)
                return
            }
            print(a)
        }
        """

    static let githubURL = "https://github.com/kntkymt/swift-syntax-scope-visualizer"
}
