import SwiftUI

struct SharingView:View {
    @EnvironmentObject var store:WeddingStore
    @EnvironmentObject var sharing:SharingService
    @State private var email = "",password = "",partnerEmail = "",code = ""
    @State private var register = false,creating = false,joining = false,leaving = false
    @State private var revoking = false
    var body:some View {
        List {
            Section {
                Label("Il vostro matrimonio, insieme",systemImage:"person.2.fill").font(.title2.bold())
                Text("Due accessi personali, gli stessi dati. Le modifiche restano sul telefono anche senza rete e vengono inviate quando riapri l’app con una connessione.").foregroundStyle(.secondary)
                Label(sharing.status,systemImage:sharing.pendingCount > 0 ? "arrow.triangle.2.circlepath":"checkmark.icloud")
                if let sync = store.db.cloud?.lastServerSync {Text("Ultimo contatto con il server: \(sync.formatted(date:.abbreviated,time:.shortened))").font(.caption)}
                if sharing.pendingCount > 0 {Text("\(sharing.pendingCount) modifiche ancora da inviare. Non disinstallare l’app prima dell’invio o di un backup.").font(.caption).foregroundStyle(.orange)}
            }
            if !sharing.configured {Section {Text("La build non contiene ancora il file di configurazione Firebase. Il resto dell’app funziona in locale.").foregroundStyle(.orange)}}
            else if sharing.account == nil {
                Section("Il tuo accesso personale") {
                    TextField("Email",text:$email).textContentType(.username).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("sharingEmail")
                    SecureField("Password",text:$password).textContentType(register ? .newPassword:.password).accessibilityIdentifier("sharingPassword")
                    Toggle("Crea un nuovo account",isOn:$register)
                    if register {Text("Almeno 12 caratteri. Creando l’account richiedi l’invio di un’email di verifica da Firebase.").font(.caption).foregroundStyle(.secondary)}
                    Button(register ? "Crea account e invia verifica":"Accedi") {let secret = password;password = "";Task {await sharing.signIn(email:email,password:secret,register:register)}}.disabled(sharing.busy || email.isEmpty || password.isEmpty).accessibilityIdentifier("sharingLogin")
                    Button("Recupera password via email") {Task {await sharing.resetPassword(email)}}.disabled(email.isEmpty || sharing.busy)
                }
            } else {
                Section("Account") {LabeledContent("Email",value:sharing.email);LabeledContent("Verificata",value:sharing.verified ? "Sì":"Non ancora");if !sharing.verified {Button("Ho verificato l’email") {Task {await sharing.verifyAgain()}};Button("Invia di nuovo l’email di verifica") {Task {await sharing.resendVerification()}}}}
                if sharing.verified {
                    if !sharing.connected {
                        Section("Collega il matrimonio") {
                            Button("Condividi i dati presenti su questo iPhone") {creating = true}.disabled(sharing.busy)
                            Text("Da eseguire solo sul primo telefono. L’app conserva un backup locale prima del collegamento.").font(.caption).foregroundStyle(.secondary)
                            TextField("Codice invito ricevuto",text:$code,axis:.vertical).textInputAutocapitalization(.never).autocorrectionDisabled()
                            Button("Accetta invito del partner") {joining = true}.disabled(code.isEmpty || sharing.busy)
                            Button("Aggiorna accesso esistente") {Task {await sharing.resume()}}.disabled(sharing.busy)
                        }
                    } else {
                        Section("Matrimonio condiviso") {
                            LabeledContent("Partecipanti",value:"\(sharing.memberCount) / 2")
                            Button("Aggiorna adesso") {Task {await sharing.resume()}}.disabled(sharing.busy)
                            if sharing.isOwner {
                                TextField("Email personale del partner",text:$partnerEmail).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                                Button("Crea / rinnova invito privato") {Task {await sharing.makeInvitation(to:partnerEmail)}}.disabled(partnerEmail.isEmpty || sharing.busy || sharing.memberCount >= 2)
                                if sharing.memberCount > 1 {Button("Revoca accesso del partner",role:.destructive) {revoking = true}.disabled(sharing.busy)}
                                if !sharing.invitation.isEmpty {Text(sharing.invitation).font(.caption.monospaced()).textSelection(.enabled);ShareLink(item:sharing.invitation) {Label("Condividi codice invito",systemImage:"square.and.arrow.up")};Text("Solo l’email indicata e verificata può accettarlo, una sola volta entro 48 ore. Un nuovo invito invalida il precedente.").font(.caption).foregroundStyle(.secondary)}
                            }
                        }
                    }
                }
                if !sharing.conflicts.isEmpty {
                    Section("Modifiche da confrontare") {ForEach(sharing.conflicts) {conflict in NavigationLink {ConflictView(conflict:conflict)} label:{VStack(alignment:.leading) {Text(conflict.mutation.desired?.kind ?? "Eliminazione").font(.headline);Text(conflict.fields.joined(separator:", ")).font(.caption).foregroundStyle(.orange)}}}}
                }
                Section {
                    Button("Esci dall’account",role:.destructive) {leaving = true}.disabled(sharing.busy)
                    Text("Uscendo, la copia condivisa e la coda vengono rimosse da questo telefono. I dati sul server e il collegamento del tuo account restano disponibili al prossimo accesso. Esporta prima un backup se hai modifiche non inviate.").font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Privacy e piano gratuito") {Text("Dati di matrimonio, contatti, preferenze e allergie inseriti vengono salvati anche su Google Cloud Firestore e sono leggibili dai due account autorizzati. Le credenziali sono gestite da Firebase Authentication. Nessun analytics o assistente AI. Piano Spark senza fatturazione: al raggiungimento delle quote la sincronizzazione può sospendersi; la copia locale resta utilizzabile.").font(.footnote).foregroundStyle(.secondary)}
        }.navigationTitle("Condividi Promessa").overlay {if sharing.busy {ProgressView().padding().background(.regularMaterial,in:RoundedRectangle(cornerRadius:16))}}
        .alert("Condividere questo archivio?",isPresented:$creating) {Button("Annulla",role:.cancel) {};Button("Condividi") {Task {await sharing.createWedding()}}} message:{Text("I dati presenti su questo iPhone verranno caricati su Firebase. Il partner potrà leggerli e modificarli dopo un tuo invito. Un backup locale viene conservato prima del collegamento.")}
        .alert("Accettare il matrimonio condiviso?",isPresented:$joining) {Button("Annulla",role:.cancel) {};Button("Accetta e collega") {Task {await sharing.join(code:code)}}} message:{Text("La vista corrente sarà sostituita dai dati condivisi, senza unire due matrimoni. Prima viene salvato un backup dell’archivio locale. Entrambi potrete modificare gli stessi dati.")}
        .alert("Uscire dall’account?",isPresented:$leaving) {Button("Annulla",role:.cancel) {};Button(sharing.pendingCount > 0 ? "Esci e scarta modifiche non inviate":"Esci",role:.destructive) {do {try sharing.signOut(discardPending:true)} catch {sharing.message = error.localizedDescription}}} message:{Text(sharing.pendingCount > 0 ? "Ci sono \(sharing.pendingCount) modifiche non inviate: uscire le scarta da questo telefono. Esporta prima un backup dalle Impostazioni.":"La copia condivisa locale sarà rimossa; i dati sul server non verranno cancellati.")}
        .alert("Revocare l’accesso del partner?",isPresented:$revoking) {Button("Annulla",role:.cancel) {};Button("Revoca",role:.destructive) {Task {await sharing.revokePartner()}}} message:{Text("Il partner non potrà più leggere o modificare i dati sul server. Questa azione non cancella copie offline e backup già in suo possesso. Potrai invitarlo nuovamente.")}
        .alert("Condivisione",isPresented:Binding(get:{sharing.message != nil},set:{if !$0 {sharing.message = nil}})) {Button("OK") {sharing.message = nil}} message:{Text(sharing.message ?? "")}
    }
}
struct ConflictView:View {
    @EnvironmentObject var sharing:SharingService
    @Environment(\.dismiss) private var dismiss
    let conflict:CloudConflict
    @State private var keep:Bool?,confirming = false
    var body:some View {
        List {
            Section {Text("Avete modificato lo stesso campo o eliminato una voce mentre l’altro la modificava. Nessuna delle due versioni è stata sovrascritta automaticamente.");Text("Campi: " + conflict.fields.joined(separator:", ")).foregroundStyle(.orange)}
            Section("La tua versione non inviata") {record(conflict.mutation.desired)}
            Section("Versione condivisa ricevuta") {record(conflict.remote?.deleted == true ? nil:conflict.remote)}
            Section {Button("Mantieni le mie modifiche") {keep = true;confirming = true};Button("Usa la versione condivisa") {keep = false;confirming = true}}
        }.navigationTitle("Confronta modifiche").confirmationDialog("Confermare la scelta per questa voce?",isPresented:$confirming,titleVisibility:.visible) {Button("Conferma") {sharing.resolve(conflict.id,keepLocal:keep ?? false);dismiss()}}
    }
    @ViewBuilder private func record(_ record:CloudRecord?) -> some View {
        if let record {ForEach(record.fields.keys.sorted(),id:\.self) {key in VStack(alignment:.leading,spacing:4) {Text(key).font(.caption).foregroundStyle(.secondary);Text(display(record.fields[key] ?? "")).textSelection(.enabled)}}} else {Text("Voce eliminata")}
    }
    private func display(_ fragment:String)->String {if let text = try? JSONDecoder().decode(String.self,from:Data(fragment.utf8)) {return text};return fragment}
}
