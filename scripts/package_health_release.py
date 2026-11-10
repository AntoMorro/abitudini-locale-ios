import pathlib,zipfile,plistlib,hashlib,json,os,re,subprocess
root=pathlib.Path("build")
ipa=root/"QuadernoSalute-v16-unsigned.ipa"
with zipfile.ZipFile(ipa) as z:
    assert z.testzip() is None
    info=plistlib.loads(z.read("Payload/AbitudiniLocale.app/Info.plist"))
    assert info["CFBundleVersion"]=="16" and info["CFBundleIdentifier"]=="local.abitudinilocale.habits"
    binary=z.read("Payload/AbitudiniLocale.app/AbitudiniLocale")
    assert b"--wellness-preview" not in binary and b"Dati dimostrativi" not in binary
log=pathlib.Path("shortcut-core-tests.log").read_text(errors="replace")
counts=re.findall(r"\[(\d+)/(\d+)\] Testing",log)
manifest={"version":info["CFBundleShortVersionString"],"build":16,"bundle":info["CFBundleIdentifier"],"commit":os.environ["GITHUB_SHA"],"ipa_sha256":hashlib.sha256(ipa.read_bytes()).hexdigest(),"ipa_bytes":ipa.stat().st_size,"core_tests":int(counts[-1][1]) if counts else None,"release_preview_data":False,"direct_HealthKit":False,"base_IPA_includes_widgets":False,"XML_import":"local streaming; selected types/period; 10000 samples maximum per batch","phone_tests":"HRV/RHR previously confirmed; new features and Principale phase require phone test","UI_verification":"separate workflow artifact; do not infer UI success from native compile"}
(root/"VERIFICA-RELEASE.json").write_text(json.dumps(manifest,indent=2)+"\n")
subprocess.run(["git","archive","--format=zip","--output",str(root/"QuadernoSalute-Sorgenti-v16.zip"),"HEAD"],check=True)
print(json.dumps(manifest))
