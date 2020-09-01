//
//  ModelingElementFeaturesApp.swift
//  ModelingElementFeatures
//
//  Created by Damir Stuhec on 01/09/2020.
//

import SwiftUI
import ComposableArchitecture

@main
struct ModelingElementFeaturesApp: App {
    let store = Store(
        initialState: AppState(itemsState: ItemsState(itemStates: [
            ItemState(item: Item(id: UUID(), name: "item 1")),
            ItemState(item: Item(id: UUID(), name: "item 2")),
            ItemState(item: Item(id: UUID(), name: "item 3"))
        ])),
        reducer: appReducer,
        environment: ()
    )

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
    }
}

// MARK: - App

struct AppState: Equatable {
    var itemsState = ItemsState()
}

enum AppAction: Equatable {
    case items(ItemsAction)
}

let appReducer = Reducer<AppState, AppAction, Void>.combine(
    Reducer { state, action, _ in
        switch action {
        case .items:
            return .none
        }
    },
    itemsReducer.pullback(
        state: \.itemsState,
        action: /AppAction.items,
        environment: { () }
    )
)

struct ContentView: View {
    let store: Store<AppState, AppAction>

    var body: some View {
        WithViewStore(store.scope(state: \.itemsState, action: AppAction.items)) { itemsViewStore in
            NavigationView {
                List {
                    ItemsView(store: store.scope(state: \.itemsState, action: AppAction.items))
                }
                .navigationTitle("Items")
                .sheet(
                    isPresented: itemsViewStore.binding(
                        get: \.isShowingEditItemView,
                        send: ItemsAction.editItemDismissed
                    )
                ) {
                    IfLetStore(
                        store.scope(state: \.itemsState.editItemState, action: { AppAction.items(.editItem($0)) }),
                        then: EditItemView.init(store:)
                    )
                }
            }
        }
    }
}

// MARK: - Items

struct ItemsState: Equatable {
    var itemStates = IdentifiedArrayOf<ItemState>()
    // ... other properties
    var editItemState: EditItemState?
    var isShowingEditItemView: Bool {
        editItemState != nil
    }
}

enum ItemsAction: Equatable {
    case showEditItem(ItemState)
    case editItemDismissed
    case item(id: Item.ID, action: ItemAction)
    case editItem(EditItemAction)
}

let itemsReducer = Reducer<ItemsState, ItemsAction, Void>.combine(
    editItemReducer.optional().pullback(
        state: \.editItemState,
        action: /ItemsAction.editItem,
        environment: { () }
    ),
    itemReducer.forEach(
        state: \.itemStates,
        action: /ItemsAction.item(id:action:),
        environment: { () }
    ),
    Reducer { state, action, _ in
        switch action {
        case .showEditItem(let itemState):
            state.editItemState = EditItemState(itemState: itemState)
            return .none
        case .editItemDismissed:
            #warning("We have to manually update the edited item state here as I'm not aware of a way to propagate the changes back up automatically in cases like this.")
            // Update edited item to propagate changes back up
            if let editedItemState = state.editItemState?.itemState {
                state.itemStates[id: editedItemState.id] = editedItemState
            }
            state.editItemState = nil
            return .none
        case .item, .editItem:
            return .none
        }
    }
)

struct ItemsView: View {
    let store: Store<ItemsState, ItemsAction>

    var body: some View {
        WithViewStore(store) { viewStore in
            ForEachStore(store.scope(state: \.itemStates, action: ItemsAction.item(id:action:))) { itemStore in
                WithViewStore(itemStore) { itemViewStore in
                    NavigationLink(destination: ItemDetailsView(store: itemStore)) {
                        ItemView(store: itemStore)
                            .contextMenu {
                                Button("Edit") {
                                    viewStore.send(.showEditItem(itemViewStore.state))
                                }
                            }
                    }
                }
            }
            #warning("There's no way to define edit view sheet here, because sheets cannot be added to a collection-type views such as ForEach.")
        }
    }
}

// MARK: - Item

struct Item: Equatable, Identifiable {
    var id: UUID
    var name: String
}

struct ItemState: Equatable, Identifiable {
    var id: Item.ID { item.id }
    var item: Item
    // ... other properties

    #warning("Cannot define editItemState here because of \"Value type 'ItemState' cannot have a stored property that recursively contains it\"")
//    var editItemState: EditItemState?
}

enum ItemAction: Equatable {}

let itemReducer = Reducer<ItemState, ItemAction, Void> { state, action, _ in
    .none
}

struct ItemView: View {
    let store: Store<ItemState, ItemAction>

    var body: some View {
        WithViewStore(store) { viewStore in
            Text(viewStore.item.name)
        }
    }
}

// MARK: - Item Details

struct ItemDetailsView: View {
    let store: Store<ItemState, ItemAction>

    var body: some View {
        VStack {
            ItemView(store: store)
            Button("Edit") {
                #warning("Not sure how to initiate the edit item flow from this (ItemState) scope, due to the problem described in line 162 warning.")
            }
        }
        .navigationTitle("Item Details")
    }
}

// MARK: - Edit Item

struct EditItemState: Equatable {
    var itemState: ItemState
}

enum EditItemAction: Equatable {
    case setName(String)
}

let editItemReducer = Reducer<EditItemState, EditItemAction, Void> { state, action, _ in
    switch action {
    case .setName(let name):
        state.itemState.item.name = name
        return .none
    }
}

struct EditItemView: View {
    let store: Store<EditItemState, EditItemAction>

    var body: some View {
        WithViewStore(store) { viewStore in
            TextField("Item name", text: viewStore.binding(
                get: \.itemState.item.name,
                send: EditItemAction.setName
            ))
            .navigationTitle("Edit Item")
        }
    }
}
