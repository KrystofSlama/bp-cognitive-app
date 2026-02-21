import Foundation
import SwiftUI
internal import Combine

enum AppRoute: Hashable {
    case test1
    case test2
    case test3
    case test4
    case test5
    case test6
    case test7
    case set2Test1
    case set2Test2
    case set2Test3
    case set2Test4
    case set2Test5
    case set2Test6
    case set2Test7
    case set3Test1
    case set3Test2
    case set3Test3
    case set3Test4
    case set3Test5
    case set3Test6
    case set3Test7
    case demoTest1
    case demoTest2
    case demoTest3
    case demoTest4
    case demoTest5
    case demoTest6
    case demoTest7
    case results
}

final class NavigationRouter: ObservableObject {
    @Published var path: [AppRoute] = []

    func goHome() {
        path.removeAll()
    }

    func go(to route: AppRoute) {
        path.append(route)
    }
}
