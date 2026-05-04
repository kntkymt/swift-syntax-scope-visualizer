import React

@propertyWrapper
public struct BindableState<Value: Equatable>: Hook {
    public init(wrappedValue: Value) {
        _state = State(wrappedValue: wrappedValue)
        _cache = Ref()
    }

    @State private var state: Value
    @Ref private var cache: Binding<Value>?

    public var wrappedValue: Value {
        get { state }
        nonmutating set { state = newValue }
    }

    public var projectedValue: Binding<Value> {
        if let cached = cache { return cached }

        let new = _state.binding
        cache = new
        return new
    }
}
