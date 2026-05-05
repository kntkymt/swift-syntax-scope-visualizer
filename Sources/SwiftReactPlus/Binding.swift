import React

@propertyWrapper
public struct Binding<Value: Hashable>: Hashable {
    public var wrappedValue: Value {
        get { value }
        nonmutating set { setValue(newValue) }
    }

    private var value: Value
    public let setValue: Function<Void, Value>

    internal init(value: Value, setValue: Function<Void, Value>) {
        self.value = value
        self.setValue = setValue
    }
}
