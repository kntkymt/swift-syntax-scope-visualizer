import React

@propertyWrapper
public struct Binding<Value: Equatable>: Hashable {
    public var wrappedValue: Value {
        get { get() }
        nonmutating set { set(newValue) }
    }

    private var get: Function<Value>
    private var set: Function<Void, Value>

    public init(get: Function<Value>, set: Function<Void, Value>) {
        self.get = get
        self.set = set
    }
}

public extension State {
    var binding: Binding<Value> {
        Binding(
            get: Function {
                wrappedValue
            },
            set: Function { newValue in
                wrappedValue = newValue
            }
        )
    }
}
