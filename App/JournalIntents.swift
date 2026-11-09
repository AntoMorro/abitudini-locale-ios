import AppIntents
import Foundation

struct JournalCaptureIntent:AppIntent {
    static var title:LocalizedStringResource="Annota nel quaderno"
    static var description=IntentDescription("Aggiunge il testo al registro rapido di oggi, conservando l'archivio locale.")
    static var openAppWhenRun=true
    @Parameter(title:"Testo") var text:String
    @MainActor func perform()async throws->some IntentResult {
        guard !text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,text.count<=4000 else{throw HabitError.invalid}
        try HabitEnvironment.repository.update{db in var j=db.journal ?? JournalDatabase();j.bullets.append(JournalBullet(text:text,kind:.note));db.journal=j}
        NotificationCenter.default.post(name:.habitDataChanged,object:nil);return .result()
    }
}
