import Foundation

/// Values are canonical JSON fragments. Cloud code never sends a whole archive.
struct CloudRecord: Codable, Equatable, Identifiable {
    var id: String
    var kind: String
    var fields: [String:String]
    var deleted = false
}
struct CloudMutation: Codable, Equatable, Identifiable {
    var id = UUID()
    var key: String
    var base: CloudRecord?
    var desired: CloudRecord?
    var keys: Set<String>
}
struct CloudConflict: Identifiable, Equatable {
    var id: String { mutation.key }
    var mutation: CloudMutation
    var remote: CloudRecord?
    var fields: [String]
}
struct CloudState: Codable, Equatable {
    var accountID: String
    var weddingID: String
    var ownerID: String
    var records: [String:CloudRecord] = [:]
    var pending: [CloudMutation] = []
    var lastServerSync: Date?
    var ready = false
    var conflicts: [CloudConflict] { pending.compactMap { CloudMerge.conflict($0,remote:records[$0.key]) } }
    mutating func capture(before:WeddingArchive, after:WeddingArchive) throws {
        let old = try CloudProjection.records(before), new = try CloudProjection.records(after)
        for key in Set(old.keys).union(new.keys).sorted() where old[key] != new[key] {
            let oldRecord = old[key], newRecord = new[key]
            let delta = CloudMerge.changedKeys(oldRecord,newRecord)
            if let i = pending.firstIndex(where:{$0.key == key}) {
                var mutation = pending[i]
                if var base = mutation.base, let oldRecord {
                    for field in delta.subtracting(mutation.keys) { base.fields[field] = oldRecord.fields[field] }
                    mutation.base = base
                }
                mutation.id = UUID();mutation.desired = newRecord;mutation.keys.formUnion(delta)
                if let base = mutation.base, let desired = mutation.desired {
                    mutation.keys = mutation.keys.filter {base.fields[$0] != desired.fields[$0]}
                }
                if mutation.base == nil && mutation.desired == nil {pending.remove(at:i)}
                else if mutation.base != nil && mutation.desired != nil && mutation.keys.isEmpty {pending.remove(at:i)}
                else {pending[i] = mutation}
            } else {
                pending.append(CloudMutation(key:key,base:oldRecord,desired:newRecord,keys:delta))
            }
        }
    }
    mutating func acknowledge(_ sent:CloudMutation, committed:CloudRecord) {
        if let cached = records[sent.key],!cached.deleted,!committed.deleted {
            var latest = cached
            for key in sent.keys where cached.fields[key] == sent.base?.fields[key] || cached.fields[key] == committed.fields[key] {latest.fields[key] = committed.fields[key]}
            records[sent.key] = latest
        } else if records[sent.key]?.deleted != true {records[sent.key] = committed}
        guard let i = pending.firstIndex(where:{$0.key == sent.key}) else {return}
        if pending[i].id == sent.id {pending.remove(at:i);return}
        // Edits made while a transaction was in flight remain queued, based on our acknowledged write.
        var next = pending[i]
        if next.base != nil {
            for key in sent.keys where next.base?.fields[key] == sent.base?.fields[key] {
                next.base?.fields[key] = committed.fields[key]
            }
        } else if sent.base == nil {next.base = committed}
        if let base = next.base, let desired = next.desired {
            next.keys = next.keys.filter {base.fields[$0] != desired.fields[$0]}
            if next.keys.isEmpty {pending.remove(at:i);return}
        }
        pending[i] = next
    }
    mutating func resolve(_ key:String, keepLocal:Bool) {
        guard let i = pending.firstIndex(where:{$0.key == key}) else {return}
        if !keepLocal {pending.remove(at:i);return}
        pending[i].id = UUID()
        let remote = records[key]
        pending[i].base = remote?.deleted == false ? remote : nil
        if remote == nil || remote?.deleted == true {pending[i].keys = Set(pending[i].desired?.fields.keys.map{$0} ?? [])}
    }
}
enum CloudMerge {
    static func changedKeys(_ lhs:CloudRecord?,_ rhs:CloudRecord?) -> Set<String> {
        let a = lhs?.fields ?? [:], b = rhs?.fields ?? [:]
        return Set(a.keys).union(b.keys).filter {a[$0] != b[$0]}
    }
    static func conflict(_ mutation:CloudMutation,remote:CloudRecord?) -> CloudConflict? {
        let base = mutation.base?.deleted == false ? mutation.base : nil
        let current = remote?.deleted == false ? remote : nil
        let desired = mutation.desired
        if desired == nil {
            guard current != nil && current != base else {return nil}
            return CloudConflict(mutation:mutation,remote:remote,fields:["Eliminazione e modifica contemporanee"])
        }
        if base != nil && current == nil {return CloudConflict(mutation:mutation,remote:remote,fields:["Voce eliminata sull’altro dispositivo"])}
        let fields = mutation.keys.filter {field in
            current?.fields[field] != base?.fields[field] && current?.fields[field] != desired?.fields[field]
        }.sorted()
        return fields.isEmpty ? nil : CloudConflict(mutation:mutation,remote:remote,fields:fields)
    }
    static func applying(_ mutation:CloudMutation,to remote:CloudRecord?) -> CloudRecord {
        guard let desired = mutation.desired else {
            return CloudRecord(id:mutation.key,kind:remote?.kind ?? mutation.base?.kind ?? "unknown",fields:remote?.fields ?? mutation.base?.fields ?? [:],deleted:true)
        }
        var result = remote?.deleted == false ? remote! : desired
        result.deleted = false
        for key in mutation.keys {result.fields[key] = desired.fields[key]}
        return result
    }
}
enum CloudProjection {
    private static func fields<T:Encodable>(_ object:T) throws -> [String:String] {
        let encoded = try JSONEncoder().encode(object)
        guard let raw = try JSONSerialization.jsonObject(with:encoded) as? [String:Any] else {throw WeddingError.invalid("Formato condiviso non valido.")}
        return try raw.mapValues {String(decoding:try JSONSerialization.data(withJSONObject:$0,options:[.fragmentsAllowed,.sortedKeys]),as:UTF8.self)}
    }
    private static func decode<T:Decodable>(_ record:CloudRecord,as type:T.Type) throws -> T {
        let raw = try record.fields.mapValues {try JSONSerialization.jsonObject(with:Data($0.utf8),options:.fragmentsAllowed)}
        return try JSONDecoder().decode(type,from:JSONSerialization.data(withJSONObject:raw,options:.sortedKeys))
    }
    static func records(_ db:WeddingArchive) throws -> [String:CloudRecord] {
        var result:[String:CloudRecord] = [:]
        func add<T:Encodable>(_ value:T,kind:String,id:String) throws {let key = kind + "_" + id;let f = try fields(value);guard f.values.reduce(0,{$0 + $1.utf8.count}) < 800_000 else {throw WeddingError.invalid("Una voce è troppo grande per la condivisione. Riduci le note e riprova.")};result[key] = CloudRecord(id:key,kind:kind,fields:f)}
        var settings = try fields(db.settings);settings.removeValue(forKey:"reminders")
        result["settings"] = CloudRecord(id:"settings",kind:"settings",fields:settings)
        struct Order:Codable {var ids:[UUID]}
        result["order"] = CloudRecord(id:"order",kind:"order",fields:try fields(Order(ids:db.schedule.map(\.id))))
        for t in db.tasks {try add(t,kind:"task",id:t.id.uuidString)}
        for v in db.vendors {try add(v,kind:"vendor",id:v.id.uuidString)}
        for e in db.expenses {
            var copy = e;copy.payments = [];try add(copy,kind:"expense",id:e.id.uuidString)
            for p in e.payments {var f = try fields(p);f["expenseID"] = try fields(ExpenseLink(expenseID:e.id))["expenseID"];let key = "payment_" + p.id.uuidString;result[key] = CloudRecord(id:key,kind:"payment",fields:f)}
        }
        for g in db.guests {try add(g,kind:"guest",id:g.id.uuidString)}
        for t in db.tables {try add(t,kind:"table",id:t.id.uuidString)}
        for s in db.schedule {try add(s,kind:"schedule",id:s.id.uuidString)}
        for n in db.notes {try add(n,kind:"note",id:n.id.uuidString)}
        return result
    }
    private struct ExpenseLink:Codable {var expenseID:UUID}
    static func materialize(_ state:CloudState, reminders:Bool) throws -> WeddingArchive {
        var records = state.records
        for pending in state.pending {records[pending.key] = CloudMerge.applying(pending,to:records[pending.key])}
        var db = WeddingArchive();var payments:[(UUID,Payment)] = [];var order:[UUID] = []
        for r in records.values.filter({!$0.deleted}).sorted(by:{$0.id < $1.id}) {
            switch r.kind {
            case "settings":var f = r;f.fields["reminders"] = reminders ? "true":"false";db.settings = try decode(f,as:WeddingSettings.self)
            case "order":struct Order:Decodable {var ids:[UUID]};order = try decode(r,as:Order.self).ids
            case "task":db.tasks.append(try decode(r,as:WeddingTask.self))
            case "vendor":db.vendors.append(try decode(r,as:Vendor.self))
            case "expense":db.expenses.append(try decode(r,as:Expense.self))
            case "payment":let link = try decode(r,as:ExpenseLink.self);payments.append((link.expenseID,try decode(r,as:Payment.self)))
            case "guest":db.guests.append(try decode(r,as:Guest.self))
            case "table":db.tables.append(try decode(r,as:WeddingTable.self))
            case "schedule":db.schedule.append(try decode(r,as:ScheduleEntry.self))
            case "note":db.notes.append(try decode(r,as:WeddingNote.self))
            default:throw WeddingError.invalid("Voce condivisa di versione non supportata.")
            }
        }
        for i in db.expenses.indices {db.expenses[i].payments = payments.filter {$0.0 == db.expenses[i].id}.map(\.1).sorted {$0.date < $1.date}}
        let indices = Dictionary(order.enumerated().map {($0.element,$0.offset)},uniquingKeysWith:{a,_ in a})
        db.schedule.sort {(indices[$0.id] ?? Int.max,$0.start,$0.id.uuidString) < (indices[$1.id] ?? Int.max,$1.start,$1.id.uuidString)}
        // Cross-record deletes may arrive in separate transactions. Preserve the raw references in
        // state.records; present a valid, detached view until their referenced record is available.
        let vendors = Set(db.vendors.map(\.id)), tables = Set(db.tables.map(\.id))
        for i in db.tasks.indices where db.tasks[i].vendorID.map({!vendors.contains($0)}) == true {db.tasks[i].vendorID = nil}
        for i in db.expenses.indices where db.expenses[i].vendorID.map({!vendors.contains($0)}) == true {db.expenses[i].vendorID = nil}
        for i in db.schedule.indices where db.schedule[i].vendorID.map({!vendors.contains($0)}) == true {db.schedule[i].vendorID = nil}
        for i in db.guests.indices where db.guests[i].tableID.map({!tables.contains($0)}) == true {db.guests[i].tableID = nil}
        for i in db.notes.indices {
            let n = db.notes[i];let exists:Bool
            switch n.kind {case .general:exists = true;case .guest:exists = db.guests.contains {$0.id == n.linkedID};case .vendor:exists = db.vendors.contains {$0.id == n.linkedID};case .task:exists = db.tasks.contains {$0.id == n.linkedID}}
            if !exists {db.notes[i].kind = .general;db.notes[i].linkedID = nil}
        }
        db.cloud = state
        return try db.validated()
    }
}
