//
//  Keys.swift
//  damus
//
//  Created by William Casarin on 2022-05-21.
//

import Foundation
import secp256k1
import Vault

let PUBKEY_HRP = "npub"
let PRIVKEY_HRP = "nsec"

struct Keypair {
    let pubkey: String
    let privkey: String?
    
    var pubkey_bech32: String {
        return bech32_pubkey(pubkey)!
    }
    
    var privkey_bech32: String? {
        return privkey.flatMap { bech32_privkey($0) }
    }
}

enum Bech32Key {
    case pub(String)
    case sec(String)
}

struct DamusKeychainConfiguration: KeychainConfiguration {
    var serviceName = "damus"
    var accessGroup: String? = nil
    var accountName = "privkey"
}

func decode_bech32_key(_ key: String) -> Bech32Key? {
    guard let decoded = try? bech32_decode(key) else {
        return nil
    }
    
    let hexed = hex_encode(decoded.data)
    if decoded.hrp == "npub" {
        return .pub(hexed)
    } else if decoded.hrp == "nsec" {
        return .sec(hexed)
    }
    
    return nil
}

func bech32_privkey(_ privkey: String) -> String? {
    guard let bytes = hex_decode(privkey) else {
        return nil
    }
    return bech32_encode(hrp: "nsec", bytes)
}

func bech32_pubkey(_ pubkey: String) -> String? {
    guard let bytes = hex_decode(pubkey) else {
        return nil
    }
    return bech32_encode(hrp: "npub", bytes)
}

func bech32_note_id(_ evid: String) -> String? {
    guard let bytes = hex_decode(evid) else {
        return nil
    }
    return bech32_encode(hrp: "note", bytes)
}

func generate_new_keypair() -> Keypair {
    let key = try! secp256k1.Signing.PrivateKey()
    let privkey = hex_encode(key.rawRepresentation)
    let pubkey = hex_encode(Data(key.publicKey.xonly.bytes))
    return Keypair(pubkey: pubkey, privkey: privkey)
}

func privkey_to_pubkey(privkey: String) -> String? {
    guard let sec = hex_decode(privkey) else {
        return nil
    }
    guard let key = try? secp256k1.Signing.PrivateKey(rawRepresentation: sec) else {
        return nil
    }
    return hex_encode(Data(key.publicKey.xonly.bytes))
}

func save_pubkey(pubkey: String) {
    UserDefaults.standard.set(pubkey, forKey: "pubkey")
}

func save_privkey(privkey: String) throws {
    try Vault.savePrivateKey(privkey, keychainConfiguration: DamusKeychainConfiguration())
}

func clear_saved_privkey() throws {
    try Vault.deletePrivateKey(keychainConfiguration: DamusKeychainConfiguration())
}

func clear_saved_pubkey() {
    UserDefaults.standard.removeObject(forKey: "pubkey")
}

func save_keypair(pubkey: String, privkey: String) throws {
    save_pubkey(pubkey: pubkey)
    try save_privkey(privkey: privkey)
}

func clear_keypair() throws {
    try clear_saved_privkey()
    clear_saved_pubkey()
}

func get_saved_keypair() -> Keypair? {
    do {
        try removePrivateKeyFromUserDefaults()
        
        return get_saved_pubkey().flatMap { pubkey in
            let privkey = get_saved_privkey()
            return Keypair(pubkey: pubkey, privkey: privkey)
        }
    } catch {
        return nil
    }
}

func get_saved_pubkey() -> String? {
    return UserDefaults.standard.string(forKey: "pubkey")
}

func get_saved_privkey() -> String? {
    let mkey = try? Vault.getPrivateKey(keychainConfiguration: DamusKeychainConfiguration());
    return mkey.map { $0.trimmingCharacters(in: .whitespaces) }
}

fileprivate func removePrivateKeyFromUserDefaults() throws {
    guard let privKey = UserDefaults.standard.string(forKey: "privkey") else { return }
    try save_privkey(privkey: privKey)
    UserDefaults.standard.removeObject(forKey: "privkey")
}
