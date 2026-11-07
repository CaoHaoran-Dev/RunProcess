//
//  RemoteHostsPane.swift
//  RunProcess
//
//  Created by Haoran on 2026/11/7.
//

#if BETA

import SwiftUI
import RemoteLinkKit
import RemoteProcessProtocol
internal import AppKit

struct RemoteHostsPane: View {
    @State private var remoteHosts: [RemoteHost] = RemoteHostStore.shared.hosts
    @State private var pairedClients: [PairedClient] = PairedClientStore.shared.clients
    
    @State private var isPresentingAdd = false
    @State private var allowControl = AppSettings.allowRemoteControl
    
    @State private var showingPairingAlert = false
    @State private var currentPairingCode = ""
    
    var body: some View {
        Section {
            Toggle(NSLocalizedString("settings.remote.allowControl", comment: ""), isOn: $allowControl)
                .font(.system(size: 13))
                .onChange(of: allowControl) {
                    AppSettings.allowRemoteControl = $0
                    if $0 { RemoteServerManager.shared.start() } else { RemoteServerManager.shared.stop() }
                }
            
            Text(NSLocalizedString("settings.remote.allowControl.hint", comment: ""))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        } header: {
            Label(NSLocalizedString("settings.remote.hostMode", comment: ""), systemImage: "macmini")
        }
        
        if allowControl {
            Section {
                if pairedClients.isEmpty {
                    Text(NSLocalizedString("settings.remote.noClients", comment: ""))
                        .foregroundColor(.secondary)
                } else {
                    ForEach(pairedClients) { client in
                        HStack(spacing: 10) {
                            Image(systemName: "laptopcomputer")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(client.deviceName)
                                    .font(.system(size: 13, weight: .medium))
                                Text(NSLocalizedString("settings.remote.paired", comment: ""))
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button {
                                PairedClientStore.shared.remove(id: client.id)
                                reload()
                            } label: {
                                Text(NSLocalizedString("button.remove", comment: ""))
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 2)
                    }
                }
            } header: {
                Label(NSLocalizedString("settings.remote.clients", comment: ""), systemImage: "person.2")
            }
        }
        
        Section {
            if remoteHosts.isEmpty {
                Text(NSLocalizedString("settings.remote.empty", comment: ""))
                    .foregroundColor(.secondary)
            } else {
                ForEach(remoteHosts) { host in
                    HStack(spacing: 10) {
                        Image(systemName: "server.rack")
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(host.name)
                                .font(.system(size: 13, weight: .medium))
                            Text("\(host.host):\(host.port)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button {
                            RemoteHostStore.shared.remove(id: host.id)
                            reload()
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Button(NSLocalizedString("settings.remote.add", comment: "")) {
                isPresentingAdd = true
            }
        } header: {
            Label(NSLocalizedString("settings.remote.devices", comment: ""), systemImage: "desktopcomputer")
        }
        .sheet(isPresented: $isPresentingAdd) {
            AddRemoteHostSheet(
                onSuccess: {
                    reload()
                    isPresentingAdd = false
                },
                onCancel: { isPresentingAdd = false }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowRemotePairingCode"))) { notif in
            if let code = notif.object as? String {
                self.currentPairingCode = code
                self.showingPairingAlert = true
            }
        }
        .alert(isPresented: $showingPairingAlert) {
            Alert(
                title: Text(NSLocalizedString("settings.remote.pairingRequest", comment: "")),
                message: Text("\(NSLocalizedString("settings.remote.pairingCodeIs", comment: "")) \(currentPairingCode)"),
                dismissButton: .default(Text(NSLocalizedString("button.ok", comment: "")))
            )
        }
    }
    
    private func reload() {
        remoteHosts = RemoteHostStore.shared.hosts
        pairedClients = PairedClientStore.shared.clients
    }
}

// MARK: - 重新设计的配对 Sheet

struct AddRemoteHostSheet: View {
    let onSuccess: () -> Void
    let onCancel: () -> Void
    
    @State private var name = ""
    @State private var host = ""
    
    @State private var step: Step = .inputHost
    @State private var pairingCode = ""
    @State private var challengeInfo: PairingHandshake.HelloResponse?
    @State private var errorMessage: String?
    @State private var isProcessing = false
    
    enum Step {
        case inputHost
        case inputCode
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text(step == .inputHost ? NSLocalizedString("settings.remote.add.title", comment: "") : NSLocalizedString("settings.remote.pairingRequest", comment: ""))
                .font(.headline)
            
            if step == .inputHost {
                inputHostView
            } else {
                inputCodeView
            }
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.system(size: 11))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            HStack {
                Button(NSLocalizedString("button.cancel", comment: "")) {
                    onCancel()
                }
                Spacer()
                if step == .inputHost {
                    Button(NSLocalizedString("settings.remote.requestPairing", comment: "")) {
                        requestPairing()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isProcessing || host.isEmpty)
                } else {
                    Button(NSLocalizedString("settings.remote.pair", comment: "")) {
                        verifyPairing()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isProcessing || pairingCode.isEmpty)
                }
            }
        }
        .padding(20)
        .frame(width: 340)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PreFillRemoteHost"))) { notif in
            if let ip = notif.object as? String {
                self.host = ip
            }
        }
    }
    
    private var inputHostView: some View {
        VStack(spacing: 8) {
            TextField(NSLocalizedString("settings.remote.field.name", comment: ""), text: $name)
                .textFieldStyle(.roundedBorder)
            
            TextField(NSLocalizedString("settings.remote.field.host", comment: ""), text: $host)
                .textFieldStyle(.roundedBorder)
            
            Text(NSLocalizedString("settings.remote.portNote", comment: ""))
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var inputCodeView: some View {
        VStack(spacing: 12) {
            Text(NSLocalizedString("settings.remote.codeHint", comment: ""))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            TextField(NSLocalizedString("settings.remote.field.code", comment: ""), text: $pairingCode)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 16, design: .monospaced))
                .multilineTextAlignment(.center)
        }
    }
    
    private func requestPairing() {
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                let config = ConnectionConfig(host: host, port: 52732)
                let client = HTTPPairingClient(config: config)
                let helloData = try await client.hello()
                let hello = try JSONDecoder().decode(PairingHandshake.HelloResponse.self, from: helloData)
                
                DispatchQueue.main.async {
                    self.challengeInfo = hello
                    self.step = .inputCode
                    self.isProcessing = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "\(host):52732 - \(error.localizedDescription)"
                    self.isProcessing = false
                }
            }
        }
    }
    
    private func verifyPairing() {
        guard let hello = challengeInfo else { return }
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                let nonce = Data(hexString: hello.nonce)
                let pairKey = PairingHandshake.derivePairKey(code: pairingCode, serverId: hello.serverId, nonce: nonce)
                let proof = PairingHandshake.computeProof(pairKey: pairKey, nonce: nonce)
                
                let req = PairingHandshake.VerifyRequest(
                    proof: proof.map { String(format: "%02x", $0) }.joined(),
                    cipherId: AESGCMCipher.cipherId,
                    deviceName: Host.current().localizedName ?? "Mac"
                )
                
                let config = ConnectionConfig(host: host, port: 52732)
                let client = HTTPPairingClient(config: config)
                let verifyData = try await client.verify(body: JSONEncoder().encode(req))
                let verifyResp = try JSONDecoder().decode(PairingHandshake.VerifyResponse.self, from: verifyData)
                
                DispatchQueue.main.async {
                    let finalName = name.trimmingCharacters(in: .whitespaces).isEmpty ? host : name
                    let remoteHost = RemoteHost(name: finalName, host: host, port: 52731)
                    KeychainHelper.shared.saveToken(verifyResp.token, for: remoteHost.id)
                    RemoteHostStore.shared.add(remoteHost)
                    onSuccess()
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isProcessing = false
                }
            }
        }
    }
}

#endif
