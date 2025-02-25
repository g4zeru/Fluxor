/*
 * FluxorTests
 *  Copyright (c) Morten Bjerg Gregersen 2020
 *  MIT license, see LICENSE file for details
 */

import Combine
@testable import Fluxor
import FluxorTestSupport
import XCTest

// swiftlint:disable force_cast

class StoreTests: XCTestCase {
    private var environment: TestEnvironment!
    private var store: Store<TestState, TestEnvironment>!
    private var reducer: ((TestState, Action) -> TestState)!

    override func setUp() {
        super.setUp()
        environment = TestEnvironment()
        store = Store(initialState: TestState(type: .initial, lastAction: nil), environment: environment)
    }

    /// Does the `Reducer`s get called?
    func testRegisteringReducers() {
        // Given
        let action = TestAction()
        XCTAssertEqual(store.state.type, .initial)
        XCTAssertNil(store.state.lastAction)
        store.register(reducer: Reducer<TestState> { state, action in
            state.type = .modifiedAgain
            state.lastAction = String(describing: action)
        })
        // When
        store.dispatch(action: action)
        // Then
        XCTAssertEqual(store.state.type, .modifiedAgain)
        XCTAssertEqual(store.state.lastAction, String(describing: action))
    }

    /// Does the `Reducer`s for substates get called?
    func testRegisteringSubstateReducers() {
        // Given
        let incrementActionTemplate = ActionTemplate(id: "Increment", payloadType: Int.self)
        let reducer = Reducer<TodosState>(
            id: "Todos Reducer",
            ReduceOn(incrementActionTemplate) { todosState, action in
                todosState.counter += action.payload
        })
        XCTAssertEqual(store.state.todos.counter, 0)
        store.register(reducer: reducer, for: \.todos)
        // When
        store.dispatch(action: incrementActionTemplate.createAction(payload: 42))
        // Then
        XCTAssertEqual(store.state.todos.counter, 42)

        // Given
        store.unregister(reducer: reducer)
        // When
        store.dispatch(action: incrementActionTemplate.createAction(payload: 42))
        // Then
        XCTAssertEqual(store.state.todos.counter, 42)

        // Given
        store.register(reducer: reducer, for: \.todos)
        // When
        store.dispatch(action: incrementActionTemplate.createAction(payload: 42))
        // Then
        XCTAssertEqual(store.state.todos.counter, 84)
    }

    /// Does the `Effect`s get triggered?
    func testRegisteringEffectsType() {
        // Given
        var interceptor = TestInterceptor<TestState>()
        store.register(effects: TestEffects())
        store.register(interceptor: interceptor)
        let firstAction = TestAction()
        // When
        store.dispatch(action: firstAction)
        // Then
        wait(for: [environment.expectation], timeout: 1)
        var dispatchedActions = interceptor.stateChanges.map(\.action)
        XCTAssertEqual(dispatchedActions.count, 4)
        XCTAssertEqual(dispatchedActions[0] as! TestAction, firstAction)
        XCTAssertEqual(dispatchedActions[1] as! AnonymousAction<Void>, environment.responseAction)
        XCTAssertEqual(dispatchedActions[2] as! AnonymousAction<Int>, environment.generateAction)
        XCTAssertEqual(dispatchedActions[3] as! AnonymousAction<Void>, environment.unrelatedAction)
        XCTAssertEqual(environment.lastAction, environment.generateAction)

        // Given
        store.unregisterEffects(ofType: TestEffects.self)
        store.unregisterInterceptors(ofType: TestInterceptor<TestState>.self)
        interceptor = TestInterceptor<TestState>()
        store.register(interceptor: interceptor)
        // When
        store.dispatch(action: firstAction)
        // Then
        XCTAssertThrowsError(try interceptor.waitForActions(expectedNumberOfActions: 3))
        dispatchedActions = interceptor.stateChanges.map(\.action)
        XCTAssertEqual(dispatchedActions.count, 1)
        XCTAssertEqual(dispatchedActions[0] as! TestAction, firstAction)

        // Given
        environment.resetExpectation()
        store.register(effects: TestEffects())
        // When
        store.dispatch(action: firstAction)
        // Then
        wait(for: [environment.expectation], timeout: 1)
        dispatchedActions = interceptor.stateChanges.map(\.action)
        XCTAssertEqual(dispatchedActions.count, 5)
        XCTAssertEqual(dispatchedActions[1] as! TestAction, firstAction)
        XCTAssertEqual(dispatchedActions[2] as! AnonymousAction<Void>, environment.responseAction)
        XCTAssertEqual(dispatchedActions[3] as! AnonymousAction<Int>, environment.generateAction)
        XCTAssertEqual(dispatchedActions[4] as! AnonymousAction<Void>, environment.unrelatedAction)
        XCTAssertEqual(environment.lastAction, environment.generateAction)
    }

    /// Does the `Effect`s get triggered?
    func testRegisteringEffectsArray() {
        // Given
        let interceptor = TestInterceptor<TestState>()
        store.register(effects: TestEffects().enabledEffects)
        store.register(interceptor: interceptor)
        let firstAction = TestAction()
        // When
        store.dispatch(action: firstAction)
        // Then
        wait(for: [environment.expectation], timeout: 1)
        let dispatchedActions = interceptor.stateChanges.map(\.action)
        XCTAssertEqual(dispatchedActions.count, 4)
        XCTAssertEqual(dispatchedActions[0] as! TestAction, firstAction)
        XCTAssertEqual(dispatchedActions[1] as! AnonymousAction<Void>, environment.responseAction)
        XCTAssertEqual(dispatchedActions[2] as! AnonymousAction<Int>, environment.generateAction)
        XCTAssertEqual(dispatchedActions[3] as! AnonymousAction<Void>, environment.unrelatedAction)
        XCTAssertEqual(environment.lastAction, environment.generateAction)
    }

    /// Does the `Effect` get triggered?
    func testRegisteringEffect() throws {
        // Given
        environment.expectation.expectedFulfillmentCount = 1
        let interceptor = TestInterceptor<TestState>()
        store.register(effect: TestEffects().anotherTestEffect)
        store.register(interceptor: interceptor)
        // When
        store.dispatch(action: environment.responseAction)
        // Then
        try interceptor.waitForActions(expectedNumberOfActions: 3)
        wait(for: [environment.expectation], timeout: 1)
        let dispatchedActions = interceptor.stateChanges.map(\.action)
        XCTAssertEqual(dispatchedActions[0] as! AnonymousAction<Void>, environment.responseAction)
        XCTAssertEqual(dispatchedActions[1] as! AnonymousAction<Int>, environment.generateAction)
        XCTAssertEqual(dispatchedActions[2] as! AnonymousAction<Void>, environment.unrelatedAction)
    }

    /// Does the `Interceptor` receive the right `Action` and modified `State`?
    func testRegisteringInterceptors() {
        // Given
        let action = TestAction()
        let interceptor = TestInterceptor<TestState>()
        store.register(reducer: testReducer)
        store.register(interceptor: interceptor)
        let oldState = store.state
        XCTAssertEqual(interceptor.stateChanges.count, 0)
        // When
        store.dispatch(action: action)
        // Then
        XCTAssertEqual(interceptor.stateChanges.count, 1)
        XCTAssertEqual(interceptor.stateChanges[0].action as! TestAction, action)
        XCTAssertEqual(interceptor.stateChanges[0].oldState, oldState)
        XCTAssertEqual(interceptor.stateChanges[0].newState, store.state)

        // Given
        store.unregisterInterceptors(ofType: TestInterceptor<TestState>.self)
        // When
        store.dispatch(action: action)
        // Then
        XCTAssertEqual(interceptor.stateChanges.count, 1)

        // Given
        store.register(interceptor: interceptor)
        // When
        store.dispatch(action: action)
        // Then
        XCTAssertEqual(interceptor.stateChanges.count, 2)
    }

    /// Does a change in `State` publish new value for `Selector`?
    func testSelectMapPublisher() {
        // Given
        let selector = Selector(keyPath: \TestState.type)
        let store = Store(initialState: TestState(type: .initial, lastAction: nil),
                          environment: TestEnvironment(),
                          reducers: [testReducer])
        let expectation = XCTestExpectation(description: debugDescription)
        let cancellable = store.select(selector).sink {
            if $0 == .modified {
                expectation.fulfill()
            }
        }
        // When
        store.dispatch(action: TestAction())
        // Then
        wait(for: [expectation], timeout: 1)
        XCTAssertNotNil(cancellable)
    }

    /// Can we select the current value for `Selector`?
    func testSelectMap() {
        // Given
        let selector = Selector(keyPath: \TestState.type)
        let store = Store(initialState: TestState(type: .initial, lastAction: nil),
                          environment: TestEnvironment(),
                          reducers: [testReducer])
        let valueBeforeAction = store.selectCurrent(selector)
        XCTAssertEqual(valueBeforeAction, .initial)
        // When
        store.dispatch(action: TestAction())
        // Then
        let valueAfterAction = store.selectCurrent(selector)
        XCTAssertEqual(valueAfterAction, .modified)
    }

    /// Does the convenience initializer give a `Void` environment?
    func testEmptyEnvironment() {
        // Given
        VoidTestEffects.envCheck = { XCTAssertEqual(String(describing: $0), "()") }
        let store = Store(initialState: TestState(type: .initial, lastAction: nil))
        store.register(effects: VoidTestEffects())
        // When
        store.dispatch(action: TestAction())
        // Then
        wait(for: [VoidTestEffects.expectation], timeout: 1)
    }

    /// Can we get all state changes in a `MockStore`?
    func testMockStoreStateChanges() {
        // Given
        let mockStore = MockStore(initialState: TestState(type: .initial, lastAction: nil))
        let action = TestAction()
        let modifiedState = TestState(type: .modified, lastAction: "Set State")
        // When
        mockStore.dispatch(action: action)
        mockStore.setState(newState: modifiedState)
        // Then
        XCTAssertEqual(mockStore.stateChanges.count, 2)
        XCTAssertEqual(mockStore.stateChanges[0].action as! TestAction, action)
        let setStateAction = mockStore.stateChanges[1].action as! AnonymousAction<TestState>
        XCTAssertEqual(setStateAction.id, "Set State")
        XCTAssertEqual(mockStore.stateChanges[1].newState, modifiedState)
    }
}

private struct TestAction: Action, Equatable {}

private struct TestState: Equatable {
    var type: TestType
    var lastAction: String?
    var todos = TodosState()
}

private struct TodosState: Equatable {
    var counter: Int = 0
}

private class TestEnvironment: Equatable {
    let id = UUID()
    let responseActionIdentifier = "ResponseAction"
    var responseActionTemplate: ActionTemplate<Void> { ActionTemplate(id: responseActionIdentifier) }
    var responseAction: AnonymousAction<Void> { responseActionTemplate.createAction() }
    var generateActionTemplate: ActionTemplate<Int> { ActionTemplate(id: "GenerateAction", payloadType: Int.self) }
    var generateAction: AnonymousAction<Int> { generateActionTemplate.createAction(payload: 42) }
    var unrelatedActionTemplate: ActionTemplate<Void> { ActionTemplate(id: "UnrelatedAction") }
    var unrelatedAction: AnonymousAction<Void> { unrelatedActionTemplate.createAction() }
    var lastAction: AnonymousAction<Int>?
    var mainThreadCheck = { XCTAssertEqual(Thread.current, Thread.main) }
    var expectation: XCTestExpectation!

    init() {
        resetExpectation()
    }

    func resetExpectation() {
        expectation = XCTestExpectation(description: String(describing: TestEffects.self))
        expectation.expectedFulfillmentCount = 3
    }

    static func == (lhs: TestEnvironment, rhs: TestEnvironment) -> Bool {
        lhs.id == rhs.id
    }
}

private enum TestType: String {
    case initial
    case modified
    case modifiedAgain
}

private let testReducer = Reducer<TestState> { state, action in
    state.type = .modified
    state.lastAction = String(describing: action)
}

private struct TestEffects: Effects {
    typealias Environment = TestEnvironment

    let testEffect = Effect<Environment>.dispatchingOne { actions, environment in
        actions.ofType(TestAction.self)
            .handleEvents(receiveOutput: { _ in environment.expectation.fulfill() })
            .receive(on: DispatchQueue.global(qos: .background))
            .map { _ in environment.responseAction }
            .eraseToAnyPublisher()
    }

    let anotherTestEffect = Effect<Environment>.dispatchingMultiple { actions, environment in
        actions.withIdentifier(environment.responseActionIdentifier)
            .handleEvents(receiveOutput: { _ in
                environment.mainThreadCheck()
                environment.expectation.fulfill()
            })
            .map { _ in [environment.generateAction, environment.unrelatedAction] }
            .eraseToAnyPublisher()
    }

    let yetAnotherTestEffect = Effect<Environment>.nonDispatching { actions, environment in
        actions.wasCreated(from: environment.generateActionTemplate)
            .sink(receiveValue: { action in
                environment.lastAction = action
                environment.expectation.fulfill()
            })
    }
}

private struct VoidTestEffects: Effects {
    typealias Environment = Void
    static let expectation = XCTestExpectation()
    static var envCheck: ((Environment) -> Void)!

    let testEffect = Effect<Environment>.nonDispatching { actions, env in
        actions.sink { _ in
            VoidTestEffects.envCheck(env)
            VoidTestEffects.expectation.fulfill()
        }
    }
}

extension AnonymousAction: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}
