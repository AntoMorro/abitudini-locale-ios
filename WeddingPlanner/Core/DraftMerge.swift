import Foundation

/// Editors keep a draft while live updates arrive. Apply only the fields that the user
/// actually changed, rejecting edits to fields changed remotely in the meantime.
enum DraftMerge {
    private static func object<T:Encodable>(_ value:T) throws -> [String:Any] {
        guard let object = try JSONSerialization.jsonObject(with:JSONEncoder().encode(value)) as? [String:Any] else {throw WeddingError.invalid("Modifica non valida.")}
        return object
    }
    private static func same(_ a:Any?,_ b:Any?) -> Bool {
        guard let a,let b else {return a == nil && b == nil}
        return (try? JSONSerialization.data(withJSONObject:a,options:[.sortedKeys,.fragmentsAllowed])) == (try? JSONSerialization.data(withJSONObject:b,options:[.sortedKeys,.fragmentsAllowed]))
    }
    static func merge<T:Codable>(_ original:T,edited:T,current:T) throws -> T {
        let base = try object(original),local = try object(edited)
        var remote = try object(current)
        for key in Set(base.keys).union(local.keys) where !same(base[key],local[key]) {
            if key == "payments",let a = base[key] as? [[String:Any]],let b = local[key] as? [[String:Any]],let c = remote[key] as? [[String:Any]] {
                remote[key] = try payments(a,b,c);continue
            }
            guard same(remote[key],base[key]) || same(remote[key],local[key]) else {throw WeddingError.invalid("La voce è cambiata su un altro dispositivo mentre la modificavi (\(key)). Annulla e riaprila per confrontare i dati aggiornati.")}
            remote[key] = local[key]
        }
        return try JSONDecoder().decode(T.self,from:JSONSerialization.data(withJSONObject:remote,options:.sortedKeys))
    }
    private static func payments(_ base:[[String:Any]],_ local:[[String:Any]],_ remote:[[String:Any]]) throws -> [[String:Any]] {
        func byID(_ list:[[String:Any]]) -> [String:[String:Any]] {Dictionary(list.compactMap {row in (row["id"] as? String).map {($0,row)}},uniquingKeysWith:{first,_ in first})}
        let a = byID(base),b = byID(local);var c = byID(remote)
        for key in Set(a.keys).union(b.keys) where !same(a[key],b[key]) {
            guard same(c[key],a[key]) || same(c[key],b[key]) else {throw WeddingError.invalid("Un pagamento è cambiato su un altro dispositivo. Riapri la spesa prima di salvarla.")}
            c[key] = b[key]
        }
        return c.keys.sorted().compactMap {c[$0]}
    }
    static func upsert<T:Codable & Identifiable>(_ edited:T,original:T?,in list:inout [T]) throws {
        if let i = list.firstIndex(where:{$0.id == edited.id}) {
            if let original {list[i] = try merge(original,edited:edited,current:list[i])} else {throw WeddingError.invalid("Identificativo già presente. Riapri la voce.")}
        } else {
            guard original == nil else {throw WeddingError.invalid("Questa voce è stata eliminata durante la modifica. Annulla e aggiorna l’elenco.")}
            list.append(edited)
        }
    }
}
