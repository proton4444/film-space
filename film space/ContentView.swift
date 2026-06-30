//
//  ContentView.swift
//  film space
//

import SwiftUI

struct ContentView: View {
    @State private var sceneState = SceneState()
    @State private var cameraController = OrbitCameraController()
    @State private var didRestore = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Group {
                switch sceneState.mode {
                case .edit:
                    VirtualStudioView(sceneState: sceneState, cameraController: cameraController)
                case .camera:
                    ARCameraView(sceneState: sceneState, cameraController: cameraController)
                }
            }
            .ignoresSafeArea()

            VStack {
                Spacer()
                StudioToolbar(sceneState: sceneState, cameraController: cameraController)
                    .padding(.bottom, 16)
            }
        }
        .onAppear {
            // Restore the saved studio once per launch. Absent/corrupt data
            // simply leaves the default empty scene.
            guard !didRestore else { return }
            didRestore = true
            ProjectStore.load()?.apply(to: sceneState, camera: cameraController)
        }
        .onChange(of: scenePhase) { _, phase in
            // Persist when leaving the foreground so blocking survives relaunch.
            if phase != .active {
                ProjectStore.save(ProjectSnapshot(scene: sceneState, camera: cameraController))
            }
        }
    }
}

#Preview {
    ContentView()
}
