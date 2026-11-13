import Foundation
import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import Security

@MainActor final class SharingService:ObservableObject {
    @Published private(set) var email = ""
    @Published private(set) var verified = false
    @Published private(set) var busy = false
    @Published private(set) var status = "Solo su questo iPhone"
    @Published private(set) var invitation = ""
    @Published private(set) var memberCount = 1
    @Published var message:String?
    weak var store:WeddingStore?
    private var firestore:Firestore?
    private var recordsListener:ListenerRegistration?
    private var roomListener:ListenerRegistration?
    private var authListener:AuthStateDidChangeListenerHandle?
    private var syncing = false
    private var active = true
    private var retry:Task<Void,Never>?
    private var generation = 0
    init(store:WeddingStore) {self.store = store}
    var account:User? {FirebaseApp.app() == nil ? nil:Auth.auth().currentUser}
    var configured:Bool {FirebaseApp.app() != nil}
    var pendingCount:Int {store?.db.cloud?.pending.count ?? 0}
    var conflicts:[CloudConflict] {store?.db.cloud?.conflicts ?? []}
    var isOwner:Bool {store?.db.cloud?.ownerID == account?.uid && account != nil}
    var connected:Bool {store?.db.cloud != nil}
    func start() {
        guard !ProcessInfo.processInfo.arguments.contains("--ui-testing") else {return}
        if FirebaseApp.app() == nil {
            guard let path = Bundle.main.path(forResource:"GoogleService-Info",ofType:"plist"),let options = FirebaseOptions(contentsOfFile:path) else {status = "Firebase non configurato";return}
            options.bundleID = Bundle.main.bundleIdentifier
            FirebaseApp.configure(options:options)
        }
        if firestore == nil {
            let db = Firestore.firestore();let settings = db.settings
            // Durable JSON + outbox are the offline source of truth. Avoid a second disk cache
            // that could retain another account's data after sign-out on a shared phone.
            settings.cacheSettings = MemoryCacheSettings();db.settings = settings;firestore = db
            Auth.auth().languageCode = "it"
            authListener = Auth.auth().addStateDidChangeListener { [weak self] _,user in
                Task {@MainActor in self?.email = user?.email ?? "";self?.verified = user?.isEmailVerified ?? false}
            }
        }
        Task {await resume()}
        retry?.cancel();retry = Task {[weak self] in
            while !Task.isCancelled {try? await Task.sleep(nanoseconds:30_000_000_000);guard !Task.isCancelled else {break};if let self,self.active {await self.flush()}}
        }
    }
    func setActive(_ value:Bool) {active = value;if value {Task {await resume()}}}
    func signIn(email:String,password:String,register:Bool) async {
        guard configured,!busy else {return};busy = true;defer {busy = false}
        do {
            let normalized = email.trimmingCharacters(in:.whitespacesAndNewlines).lowercased()
            if register {
                guard password.count >= 12 else {throw WeddingError.invalid("Scegli una password di almeno 12 caratteri.")}
                let result = try await Auth.auth().createUser(withEmail:normalized,password:password)
                try await result.user.sendEmailVerification();message = "Email di verifica inviata. Apri il link e poi premi Ho verificato."
            } else {_ = try await Auth.auth().signIn(withEmail:normalized,password:password)}
            self.email = account?.email ?? "";verified = account?.isEmailVerified ?? false
            await resume()
        } catch {message = friendly(error)}
    }
    func verifyAgain() async {
        do {guard let user = account else {return};try await user.reload();_ = try await user.getIDToken(forcingRefresh:true);verified = user.isEmailVerified;await resume()} catch {message = friendly(error)}
    }
    func resendVerification() async {do {try await account?.sendEmailVerification();message = "Email di verifica inviata."} catch {message = friendly(error)}}
    func resetPassword(_ email:String) async {guard configured else {return};do {try await Auth.auth().sendPasswordReset(withEmail:email.trimmingCharacters(in:.whitespacesAndNewlines));message = "Se l’indirizzo è registrato, riceverà le istruzioni di recupero."} catch {message = friendly(error)}}
    private func requireAccount() throws -> (Firestore,User) {
        guard let firestore,let user = account,user.isEmailVerified else {throw WeddingError.invalid("Accedi e verifica il tuo indirizzo email.")}
        return (firestore,user)
    }
    func createWedding() async {
        guard !busy,!connected else {return};busy = true;defer {busy = false}
        do {
            let (db,user) = try requireAccount()
            let existing = try await db.collection("profiles").document(user.uid).getDocument(source:.server)
            guard existing.data()?["weddingID"] == nil else {await resume();return}
            let state = CloudState(accountID:user.uid,weddingID:UUID().uuidString,ownerID:user.uid)
            try store?.connect(state,uploadLocal:true)
            try await ensureRoom(state)
            await flush()
        } catch {message = friendly(error)}
    }
    private func ensureRoom(_ state:CloudState) async throws {
        let (db,user) = try requireAccount()
        guard state.accountID == user.uid,state.ownerID == user.uid else {throw WeddingError.invalid("Account diverso dal proprietario dell’archivio locale.")}
        let room = db.collection("weddings").document(state.weddingID)
        let snapshot = try await room.getDocument(source:.server)
        if !snapshot.exists {try await room.setData(["ownerID":user.uid,"members":[user.uid],"ready":false,"inviteID":"","createdAt":FieldValue.serverTimestamp()])}
        try await db.collection("profiles").document(user.uid).setData(["weddingID":state.weddingID])
    }
    func resume() async {
        guard active,configured,let user = account,user.isEmailVerified else {status = configured ? "Accedi e verifica l’email":"Firebase non configurato";return}
        do {
            if let state = store?.db.cloud {
                guard state.accountID == user.uid else {throw WeddingError.invalid("L’archivio locale appartiene a un altro accesso. Esporta un backup ed esci prima di cambiare account.")}
                if !state.ready {try await ensureRoom(state);await flush()}
                else {listen();await flush()}
            } else if let firestore {
                let profile = try await firestore.collection("profiles").document(user.uid).getDocument(source:.server)
                guard let id = profile.data()?["weddingID"] as? String else {status = "Crea il matrimonio o accetta un invito";return}
                let room = try await firestore.collection("weddings").document(id).getDocument(source:.server)
                guard let owner = room.data()?["ownerID"] as? String,room.data()?["ready"] as? Bool == true else {throw WeddingError.invalid("La condivisione non è ancora pronta. Riapri l’app sul telefono del proprietario.")}
                try store?.connect(CloudState(accountID:user.uid,weddingID:id,ownerID:owner,ready:true),uploadLocal:false)
                listen()
            }
        } catch {status = "Offline o accesso non disponibile: dati locali conservati";message = friendly(error)}
    }
    func makeInvitation(to email:String) async {
        guard !busy,isOwner else {return};busy = true;defer {busy = false}
        do {
            let (db,user) = try requireAccount();guard let state = store?.db.cloud,state.ready else {throw WeddingError.invalid("Attendi il primo invio completo dei dati.")}
            let target = email.trimmingCharacters(in:.whitespacesAndNewlines).lowercased()
            guard target.contains("@"),target != user.email?.lowercased() else {throw WeddingError.invalid("Inserisci l’email personale del partner, diversa dalla tua.")}
            var bytes = [UInt8](repeating:0,count:32)
            guard SecRandomCopyBytes(kSecRandomDefault,bytes.count,&bytes) == errSecSuccess else {throw WeddingError.invalid("Impossibile creare un invito sicuro.")}
            let code = bytes.map {String(format:"%02x",$0)}.joined()
            let batch = db.batch()
            batch.setData(["weddingID":state.weddingID,"ownerID":user.uid,"email":target,"expiresAt":Timestamp(date:Date().addingTimeInterval(172800)),"usedBy":NSNull()],forDocument:db.collection("invites").document(code))
            batch.updateData(["inviteID":code],forDocument:db.collection("weddings").document(state.weddingID))
            try await batch.commit();invitation = code;message = "Invito valido per 48 ore e solo per questa email. Condividi manualmente il codice; l’app non invia messaggi al partner."
        } catch {message = friendly(error)}
    }
    func join(code:String) async {
        guard !busy,!connected else {return};busy = true;defer {busy = false}
        do {
            let (db,user) = try requireAccount()
            let cleaned = code.trimmingCharacters(in:.whitespacesAndNewlines).lowercased()
            guard cleaned.count == 64,cleaned.allSatisfy({$0.isHexDigit}) else {throw WeddingError.invalid("Codice invito non valido.")}
            let result: [String:String] = try await withCheckedThrowingContinuation { continuation in
                db.runTransaction({transaction,errorPointer -> Any? in
                    do {
                        let ref = db.collection("invites").document(cleaned)
                        let invite = try transaction.getDocument(ref)
                        let profile = try transaction.getDocument(db.collection("profiles").document(user.uid))
                        guard let values = invite.data(),let id = values["weddingID"] as? String,let owner = values["ownerID"] as? String else {throw WeddingError.invalid("Invito non disponibile.")}
                        guard profile.data()?["weddingID"] == nil || profile.data()?["weddingID"] as? String == id else {throw WeddingError.invalid("Questo account è già collegato a un altro matrimonio.")}
                        transaction.updateData(["members":FieldValue.arrayUnion([user.uid])],forDocument:db.collection("weddings").document(id))
                        transaction.updateData(["usedBy":user.uid],forDocument:ref)
                        transaction.setData(["weddingID":id],forDocument:db.collection("profiles").document(user.uid))
                        return ["id":id,"owner":owner]
                    } catch {errorPointer?.pointee = error as NSError;return nil}
                }) {result,error in if let error {continuation.resume(throwing:error)} else if let result = result as? [String:String] {continuation.resume(returning:result)} else {continuation.resume(throwing:WeddingError.invalid("Invito non accettato."))}}
            }
            try store?.connect(CloudState(accountID:user.uid,weddingID:result["id"]!,ownerID:result["owner"]!,ready:true),uploadLocal:false)
            listen()
        } catch {message = friendly(error)}
    }
    func signOut(discardPending:Bool = false) throws {
        guard !busy,!syncing else {throw WeddingError.invalid("Attendi il completamento dell’operazione in corso.")}
        guard pendingCount == 0 || discardPending else {throw WeddingError.invalid("Ci sono modifiche non inviate. Attendi la sincronizzazione o esporta un backup prima di uscire.")}
        generation += 1;recordsListener?.remove();recordsListener = nil;roomListener?.remove();roomListener = nil
        if connected {try store?.clearSharedLocal()}
        try Auth.auth().signOut();email = "";verified = false;invitation = "";status = "Solo su questo iPhone"
    }
    func revokePartner() async {
        guard !busy,isOwner else {return};busy = true;defer {busy = false}
        do {let (db,user) = try requireAccount();guard let state = store?.db.cloud else {return};try await db.collection("weddings").document(state.weddingID).updateData(["members":[user.uid],"inviteID":""]);invitation = "";message = "Accesso del partner revocato sul server. Le copie già scaricate, i backup e i dati offline sul suo dispositivo non possono essere cancellati da remoto."} catch {message = friendly(error)}
    }
    func resolve(_ key:String,keepLocal:Bool) {
        do {try store?.cloudUpdate {archive in guard var state = archive.cloud else {return};state.resolve(key,keepLocal:keepLocal);archive = try CloudProjection.materialize(state,reminders:archive.settings.reminders)};localChanged()} catch {message = friendly(error)}
    }
    func localChanged() {objectWillChange.send();Task {await flush()}}
    private func listen() {
        guard recordsListener == nil,let state = store?.db.cloud,let db = firestore,account?.uid == state.accountID,state.ready else {return}
        let myGeneration = generation
        let room = db.collection("weddings").document(state.weddingID)
        roomListener = room.addSnapshotListener {[weak self] snapshot,error in Task {@MainActor in
            guard let self,self.generation == myGeneration else {return}
            if let error {self.status = "Accesso condiviso non disponibile";self.message = self.friendly(error);return}
            self.memberCount = (snapshot?.data()?["members"] as? [String])?.count ?? 1
        }}
        recordsListener = room.collection("records").addSnapshotListener(includeMetadataChanges:true) {[weak self] snapshot,error in Task {@MainActor in
            guard let self,self.generation == myGeneration else {return}
            if let error {self.status = "Offline o accesso non disponibile";self.message = self.friendly(error);return}
            guard let snapshot,!snapshot.metadata.isFromCache else {return}
            do {
                var records:[String:CloudRecord] = [:]
                for document in snapshot.documents {records[document.documentID] = try Self.record(document.documentID,document.data())}
                guard records["settings"] != nil else {throw WeddingError.invalid("Archivio condiviso incompleto. I dati locali sono conservati.")}
                try self.store?.cloudUpdate {archive in guard var state = archive.cloud else {return};state.records = records;state.lastServerSync = Date();archive = try CloudProjection.materialize(state,reminders:archive.settings.reminders)}
                self.updateStatus();await self.flush()
            } catch {self.message = self.friendly(error);self.status = "Dati condivisi non applicati: copia locale conservata"}
        }}
    }
    private struct WriteResult:Codable {var record:CloudRecord;var conflict:Bool}
    nonisolated private static func record(_ id:String,_ data:[String:Any]) throws -> CloudRecord {
        guard let kind = data["kind"] as? String,let fields = data["fields"] as? [String:String],let deleted = data["deleted"] as? Bool,fields.count <= 40,fields.values.reduce(0,{$0 + $1.utf8.count}) < 850_000 else {throw WeddingError.invalid("Formato condiviso non supportato.")}
        return CloudRecord(id:id,kind:kind,fields:fields,deleted:deleted)
    }
    private func write(_ mutation:CloudMutation,state:CloudState) async throws -> WriteResult {
        let (db,user) = try requireAccount();guard user.uid == state.accountID else {throw WeddingError.invalid("Account diverso dall’archivio locale.")}
        let ref = db.collection("weddings").document(state.weddingID).collection("records").document(mutation.key)
        let data:Data = try await withCheckedThrowingContinuation {continuation in
            db.runTransaction({transaction,errorPointer -> Any? in
                do {
                    let snapshot = try transaction.getDocument(ref)
                    let remote = try snapshot.data().map {try Self.record(mutation.key,$0)}
                    if CloudMerge.conflict(mutation,remote:remote) != nil {
                        let current = remote ?? CloudRecord(id:mutation.key,kind:mutation.base?.kind ?? "unknown",fields:[:],deleted:true)
                        return try JSONEncoder().encode(WriteResult(record:current,conflict:true))
                    }
                    let merged = CloudMerge.applying(mutation,to:remote)
                    transaction.setData(["kind":merged.kind,"fields":merged.fields,"deleted":merged.deleted,"updatedBy":user.uid,"updatedAt":FieldValue.serverTimestamp()],forDocument:ref)
                    return try JSONEncoder().encode(WriteResult(record:merged,conflict:false))
                } catch {errorPointer?.pointee = error as NSError;return nil}
            }) {result,error in if let error {continuation.resume(throwing:error)} else if let data = result as? Data {continuation.resume(returning:data)} else {continuation.resume(throwing:WeddingError.invalid("Salvataggio condiviso non confermato."))}}
        }
        return try JSONDecoder().decode(WriteResult.self,from:data)
    }
    func flush() async {
        guard active,!syncing,configured,let state = store?.db.cloud,account?.uid == state.accountID,account?.isEmailVerified == true else {return}
        syncing = true;defer {syncing = false;objectWillChange.send()}
        let myGeneration = generation
        do {
            while active,generation == myGeneration,let current = store?.db.cloud {
                let blocked = Set(current.conflicts.map(\.id))
                guard let mutation = current.pending.first(where:{!blocked.contains($0.key)}) else {break}
                status = "Invio di \(current.pending.count) modifiche…"
                let result = try await write(mutation,state:current)
                guard generation == myGeneration else {return}
                try store?.cloudUpdate {archive in guard var state = archive.cloud else {return};if result.conflict {state.records[mutation.key] = result.record} else {state.acknowledge(mutation,committed:result.record)};archive = try CloudProjection.materialize(state,reminders:archive.settings.reminders)}
            }
            if let state = store?.db.cloud,!state.ready,state.pending.isEmpty,let db = firestore {
                try await db.collection("weddings").document(state.weddingID).updateData(["ready":true])
                try store?.cloudUpdate {$0.cloud?.ready = true};listen()
            }
            updateStatus()
        } catch {status = "Offline / invio sospeso · \(pendingCount) modifiche al sicuro sul telefono"}
    }
    private func updateStatus() {
        if !conflicts.isEmpty {status = "\(conflicts.count) voci da confrontare"}
        else if pendingCount > 0 {status = "\(pendingCount) modifiche da inviare"}
        else {status = "Aggiornato con il server"}
        objectWillChange.send()
    }
    private func friendly(_ error:Error)->String {
        let ns = error as NSError
        if ns.domain == FirestoreErrorDomain && ns.code == 7 {return "Accesso negato. Controlla email verificata, destinatario/scadenza dell’invito e regole Firestore. Nessun dato locale viene cancellato."}
        if ns.domain == FirestoreErrorDomain && ns.code == 8 {return "Quota gratuita raggiunta. Puoi continuare offline; l’invio riprenderà quando la quota sarà disponibile."}
        return error.localizedDescription
    }
}
