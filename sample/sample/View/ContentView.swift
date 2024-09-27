//
//  ContentView.swift
//  Observation Framework
//
//  Created by Jeet on 03/07/24.
//

import SwiftUI

struct ContentView: View {
    
    @State var contentVM = ContentViewViewModel()
    
    var body: some View {
        ZStack {
            VStack {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Hello, world!")
            }
            .padding()
            
            if contentVM.isShowLoader {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            
                    }
                    .frame(width: 60,height:60)
                    .background(Color.white)
                    .clipShape(.rect(cornerRadius: 8))
                    
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
            }
        }
        .onAppear {
            contentVM.getAllData()
        }
    }
}

#Preview {
    ContentView()
}
