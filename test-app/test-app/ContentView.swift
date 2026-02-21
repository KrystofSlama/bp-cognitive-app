//
//  ContentView.swift
//  Kacka
//
//  Created by Kryštof Sláma on 20.11.2025.
//

import SwiftUI
import SwiftData
internal import Combine

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var router = NavigationRouter()
    @StateObject private var resultsStore = ResultsStore()
    @State private var showingNamePrompt = false
    @State private var tempName: String = ""
    @State private var selectedTestSet: TestSet = .test1
    @Query(sort: \ParticipantResult.createdAt, order: .reverse) private var savedResults: [ParticipantResult]

    var body: some View {
        NavigationStack(path: $router.path) {
            VStack(spacing: 24) {
                Spacer()
                Text("Cognitive Function Testing")
                    .font(.system(size: 48)).bold()

                Spacer()
                VStack(alignment: .center, spacing: 12) {
                    Button {
                        selectedTestSet = .test1
                        tempName = resultsStore.userName
                        showingNamePrompt = true
                    } label: {
                        Text("Test 1")
                            .font(.title).bold()
                            .padding(.horizontal)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button {
                        selectedTestSet = .test2
                        tempName = resultsStore.userName
                        showingNamePrompt = true
                    } label: {
                        Text("Test 2")
                            .font(.title).bold()
                            .padding(.horizontal)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        selectedTestSet = .test3
                        tempName = resultsStore.userName
                        showingNamePrompt = true
                    } label: {
                        Text("Test 3")
                            .font(.title).bold()
                            .padding(.horizontal)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        selectedTestSet = .testDemo
                        tempName = resultsStore.userName
                        showingNamePrompt = true
                    } label: {
                        Text("Test Demo")
                            .font(.title).bold()
                            .padding(.horizontal)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    
                    NavigationLink(value: AppRoute.results) {
                        Text("Results")
                            .font(.title).bold()
                            .padding(.horizontal)
                    }
                    .buttonStyle(.bordered)
                    .disabled(savedResults.isEmpty)
                    
                }

                Spacer()
                Spacer()
            }
            .padding()
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .test1:
                    Test1View()
                case .test2:
                    Test2View()
                case .test3:
                    Test3View()
                case .test4:
                    Test4View()
                case .test5:
                    Test5View()
                case .test6:
                    Test6View()
                case .test7:
                    Test7View()
                case .set2Test1:
                    Set2Test1View()
                case .set2Test2:
                    Set2Test2View()
                case .set2Test3:
                    Set2Test3View()
                case .set2Test4:
                    Set2Test4View()
                case .set2Test5:
                    Set2Test5View()
                case .set2Test6:
                    Set2Test6View()
                case .set2Test7:
                    Set2Test7View()
                case .set3Test1:
                    Set3Test1View()
                case .set3Test2:
                    Set3Test2View()
                case .set3Test3:
                    Set3Test3View()
                case .set3Test4:
                    Set3Test4View()
                case .set3Test5:
                    Set3Test5View()
                case .set3Test6:
                    Set3Test6View()
                case .set3Test7:
                    Set3Test7View()
                case .demoTest1:
                    DemoTest1View()
                case .demoTest2:
                    DemoTest2View()
                case .demoTest3:
                    DemoTest3View()
                case .demoTest4:
                    DemoTest4View()
                case .demoTest5:
                    DemoTest5View()
                case .demoTest6:
                    DemoTest6View()
                case .demoTest7:
                    DemoTest7View()
                case .results:
                    ResultsView()
                }
            }
        }
        .alert("Enter participant name", isPresented: $showingNamePrompt) {
            TextField("Name", text: $tempName)
            Button("Cancel", role: .cancel) {
                tempName = ""
            }
            Button("Start tests") {
                let trimmed = tempName.trimmingCharacters(in: .whitespacesAndNewlines)
                let baseName = trimmed.isEmpty ? "Unknown" : trimmed
                resultsStore.userName = baseName
                let sessionName = "\(baseName)-\(selectedTestSet.sessionSuffix)"
                resultsStore.beginNewSession(in: modelContext, userName: sessionName)
                router.path = [selectedTestSet.startRoute]
            }
        } message: {
            Text("Please enter your name before beginning the tests.")
        }
        .environmentObject(router)
        .environmentObject(resultsStore)
    }
}

private enum TestSet {
    case test1
    case test2
    case test3
    case testDemo

    var sessionSuffix: String {
        switch self {
        case .test1:
            return "Test1"
        case .test2:
            return "Test2"
        case .test3:
            return "Test3"
        case .testDemo:
            return "TestDemo"
        }
    }

    var startRoute: AppRoute {
        switch self {
        case .test1:
            return .test1
        case .test2:
            return .set2Test5
        case .test3:
            return .set3Test7
        case .testDemo:
            return .demoTest1
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 1000, height: 800)
}
