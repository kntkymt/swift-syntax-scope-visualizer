import React

@propertyWrapper
public struct BindableState<Value: Hashable>: Hook {
    public init(wrappedValue: Value) {
        _state = State(wrappedValue: wrappedValue)
        _setState = Callback()
    }

    @State private var state: Value
    @Callback private var setState: Function<Void, Value>

    public var wrappedValue: Value {
        get { state }
        nonmutating set { state = newValue }
    }

    public var projectedValue: Binding<Value> {
        $setState(deps: []) { newValue in state = newValue }
        return Binding(value: state, setValue: setState)
    }
}
