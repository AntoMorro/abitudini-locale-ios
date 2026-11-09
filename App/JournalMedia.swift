import SwiftUI
import AVFoundation
import LocalAuthentication
import PencilKit

struct JournalClip:Equatable {var data:Data;var duration:Double}
@MainActor final class JournalVoiceRecorder:NSObject,ObservableObject,AVAudioRecorderDelegate {
    @Published var recording=false
    @Published var error:String?
    @Published var clip:JournalClip?
    private var recorder:AVAudioRecorder?
    private var file:URL?
    private var started:Date?
    var elapsed:Double{min(120,Date().timeIntervalSince(started ?? Date()))}
    func start()async {
        guard !recording else{return}
        let granted=await withCheckedContinuation{c in AVAudioSession.sharedInstance().requestRecordPermission{c.resume(returning:$0)}}
        guard granted else{error="Abilita il microfono nelle impostazioni per registrare una nota vocale.";return}
        do{let session=AVAudioSession.sharedInstance();try session.setCategory(.playAndRecord,mode:.default,options:[.defaultToSpeaker]);try session.setActive(true)
            let file=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".m4a");self.file=file
            let r=try AVAudioRecorder(url:file,settings:[AVFormatIDKey:kAudioFormatMPEG4AAC,AVSampleRateKey:22050,AVNumberOfChannelsKey:1,AVEncoderBitRateKey:64000]);r.delegate=self;recorder=r;started=Date();guard r.record(forDuration:120) else{throw HabitError.storage};recording=true
        }catch{self.error=error.localizedDescription;cancel()}
    }
    @discardableResult func finish()->(Data,Double)? {
        guard let r=recorder,let file=file else{return nil};let duration=elapsed;recorder=nil;r.stop();recording=false
        defer{try? FileManager.default.removeItem(at:file);self.file=nil;try? AVAudioSession.sharedInstance().setActive(false,options:.notifyOthersOnDeactivation)}
        do{let data=try Data(contentsOf:file);guard !data.isEmpty,data.count<=3_000_000 else{throw HabitError.invalid};clip=JournalClip(data:data,duration:duration);return(data,duration)}catch{self.error=error.localizedDescription;return nil}
    }
    func cancel(){let r=recorder;recorder=nil;r?.stop();recording=false;if let file=file{try? FileManager.default.removeItem(at:file)};file=nil;try? AVAudioSession.sharedInstance().setActive(false,options:.notifyOthersOnDeactivation)}
    nonisolated func audioRecorderDidFinishRecording(_ recorder:AVAudioRecorder,successfully flag:Bool){Task{@MainActor in if flag{_ = self.finish()}else{self.error="Registrazione interrotta.";self.cancel()}}}
}
@MainActor final class JournalPrivacy {
    static let shared=JournalPrivacy()
    private var shield:UIView?
    private var unlocked=false
    func update(enabled:Bool,active:Bool) {
        if !enabled{shield?.removeFromSuperview();shield=nil;unlocked=false;return}
        if !active{unlocked=false;show()}else if !unlocked{show()}
    }
    private func show(){
        guard shield==nil,let window=UIApplication.shared.connectedScenes.compactMap({$0 as? UIWindowScene}).flatMap(\.windows).first(where:{$0.isKeyWindow}) else{return}
        let view=UIView(frame:window.bounds);view.autoresizingMask=[.flexibleWidth,.flexibleHeight];view.backgroundColor = .systemBackground;view.accessibilityViewIsModal=true
        let title=UILabel();title.text="Il tuo spazio personale";title.font = .systemFont(ofSize:25,weight:.semibold);title.textAlignment = .center
        let description=UILabel();description.text="Sblocca con Face ID, Touch ID o il codice del dispositivo.";description.numberOfLines=0;description.textAlignment = .center;description.textColor = .secondaryLabel
        let button=UIButton(type:.system);button.setTitle("Sblocca quaderno",for:.normal);button.titleLabel?.font = .systemFont(ofSize:20,weight:.semibold)
        let stack=UIStackView(arrangedSubviews:[title,description,button]);stack.axis = .vertical;stack.spacing=24;stack.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(stack)
        NSLayoutConstraint.activate([stack.centerYAnchor.constraint(equalTo:view.centerYAnchor),stack.leadingAnchor.constraint(equalTo:view.leadingAnchor,constant:28),stack.trailingAnchor.constraint(equalTo:view.trailingAnchor,constant:-28)])
        button.addAction(UIAction{[weak self] _ in Task{@MainActor in let context=LAContext();do{let ok=try await context.evaluatePolicy(.deviceOwnerAuthentication,localizedReason:"Accedi al tuo diario personale");if ok{self?.unlocked=true;self?.shield?.removeFromSuperview();self?.shield=nil}}catch{description.text=error.localizedDescription}}},for:.touchUpInside)
        window.addSubview(view);shield=view
    }
}
@MainActor enum JournalExport {
    static func pdf(_ db:JournalDatabase)throws->URL {
        let url=FileManager.default.temporaryDirectory.appendingPathComponent("Quaderno-\(UUID().uuidString).pdf")
        let renderer=UIGraphicsPDFRenderer(bounds:CGRect(x:0,y:0,width:595,height:842))
        try renderer.writePDF(to:url){context in
            var y:CGFloat=55,pageNumber=0
            func newPage(){context.beginPage();pageNumber+=1;y=55;("Quaderno Locale · \(pageNumber)" as NSString).draw(at:CGPoint(x:44,y:810),withAttributes:[.font:UIFont.systemFont(ofSize:9),.foregroundColor:UIColor.gray])}
            func write(_ text:String,size:CGFloat=12,bold:Bool=false){
                let font=bold ? UIFont.boldSystemFont(ofSize:size):UIFont.systemFont(ofSize:size)
                let attributes:[NSAttributedString.Key:Any]=[.font:font,.foregroundColor:UIColor.black]
                var rest=text as NSString
                while rest.length>0 {
                    if y>740{newPage()}
                    let height=760-y;var low=1,high=rest.length,best=1
                    while low<=high{let n=(low+high)/2;let slice=rest.substring(to:n) as NSString;let rect=slice.boundingRect(with:CGSize(width:507,height:.greatestFiniteMagnitude),options:[.usesLineFragmentOrigin,.usesFontLeading],attributes:attributes,context:nil);if rect.height<=height{best=n;low=n+1}else{high=n-1}}
                    // Respect UTF-16 composed sequences when a paragraph crosses a page.
                    let range=rest.rangeOfComposedCharacterSequences(for:NSRange(location:0,length:best));let chunk=rest.substring(with:range) as NSString
                    let h=chunk.boundingRect(with:CGSize(width:507,height:.greatestFiniteMagnitude),options:[.usesLineFragmentOrigin,.usesFontLeading],attributes:attributes,context:nil).height
                    chunk.draw(in:CGRect(x:44,y:y,width:507,height:h+3),withAttributes:attributes);y+=h+14;rest=rest.substring(from:range.length) as NSString;if rest.length>0{newPage()}
                }
            }
            func picture(_ image:UIImage){if y+220>760{newPage()};let width=min(507,image.size.width),height=min(210,width*image.size.height/max(1,image.size.width));let actualWidth=min(width,height*image.size.width/max(1,image.size.height));image.draw(in:CGRect(x:44,y:y,width:actualWidth,height:height));y+=height+18}
            newPage();write("Il mio quaderno",size:26,bold:true)
            for p in db.pages.sorted(by:{$0.date<$1.date}){
                if y>620{newPage()};write(p.title,size:19,bold:true);write(JournalEngine.label(p.date)+" · pagina \(p.number)",size:10);write(p.body)
                for photo in p.photos{if let image=UIImage(data:photo.data){picture(image)};if !photo.caption.isEmpty{write(photo.caption,size:10)}}
                if let data=p.ink,let ink=try? PKDrawing(data:data),!ink.bounds.isEmpty{let bounds=ink.bounds.insetBy(dx:-10,dy:-10);let scale=min(2,1600/max(bounds.width,bounds.height));picture(ink.image(from:bounds,scale:scale))}
                if p.audio != nil{write("Nota vocale disponibile nel backup completo.",size:10)}
            }
            if !db.bullets.isEmpty{newPage();write("Registro rapido",size:22,bold:true);for b in db.bullets.sorted(by:{$0.date<$1.date}){write((b.status == .done ? "×":b.status == .migrated ? ">":b.kind.glyph)+" "+JournalEngine.label(b.date)+" · "+b.text)}}
        };return url
    }
}
