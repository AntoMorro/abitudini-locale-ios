import pathlib,plistlib,urllib.request,urllib.error,json,hashlib,struct,ssl,subprocess,time,shutil
root=pathlib.Path('ShortcutFiles');out=pathlib.Path('shortcut-delivery');out.mkdir(exist_ok=True);tmp=pathlib.Path('shortcut-verification');tmp.mkdir(exist_ok=True)
official=urllib.request.urlopen('https://www.apple.com/certificateauthority/AppleRootCA-G3.cer',timeout=20).read();fingerprint=hashlib.sha256(official).hexdigest();assert fingerprint=='63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179'
rootpem=tmp/'apple-root.pem';rootpem.write_text(ssl.DER_cert_to_PEM_cert(official));results=[]
for p in sorted((root/'Unsigned').glob('*.shortcut')):
 raw=p.read_bytes();original=plistlib.loads(raw)
 for attempt in range(2):
  try:
   req=urllib.request.Request('https://sign.shortcuty.app/api/v1/sign',data=raw,headers={'Content-Type':'application/octet-stream','X-Filename':p.name},method='POST')
   with urllib.request.urlopen(req,timeout=60) as response:
    signed=response.read();assert signed.startswith(b'AEA1')
    expected=response.headers.get('X-Shortcut-Input-SHA256');assert not expected or expected==hashlib.sha256(raw).hexdigest()
   break
  except urllib.error.URLError:
   if attempt:raise
   time.sleep(3)
 target=out/p.name;target.write_bytes(signed)
 length=struct.unpack('<I',signed[8:12])[0];chain=plistlib.loads(signed[12:12+length])['SigningCertificateChain'];assert hashlib.sha256(chain[-1]).hexdigest()==fingerprint
 leaf=tmp/'leaf.pem';leaf.write_text(ssl.DER_cert_to_PEM_cert(chain[0]))
 intermediate=tmp/'intermediate.pem';intermediate.write_text(''.join(ssl.DER_cert_to_PEM_cert(c) for c in chain[1:-1]))
 subprocess.run(['openssl','verify','-CAfile',str(rootpem),'-untrusted',str(intermediate),str(leaf)],check=True)
 public=tmp/'public.pem'
 with public.open('wb') as f:subprocess.run(['openssl','x509','-in',str(leaf),'-pubkey','-noout'],stdout=f,check=True)
 archive=tmp/'decoded.aar';subprocess.run(['aea','decrypt','-i',str(target),'-o',str(archive),'-sign-pub',str(public)],check=True,capture_output=True)
 extracted=tmp/'extracted'
 if extracted.exists():shutil.rmtree(extracted)
 extracted.mkdir();subprocess.run(['aa','extract','-i',str(archive),'-d',str(extracted)],check=True,capture_output=True)
 workflows=[]
 for file in extracted.rglob('*'):
  if file.is_file():
   try:
    data=plistlib.loads(file.read_bytes())
    if isinstance(data,dict) and 'WFWorkflowActions' in data:workflows.append(data)
   except Exception:pass
 assert len(workflows)==1
 assert workflows[0]['WFWorkflowActions']==original['WFWorkflowActions'],'Signed workflow actions changed'
 ids=[a['WFWorkflowActionIdentifier'] for a in original['WFWorkflowActions']]
 assert not any(x in ids for x in ['is.workflow.actions.downloadurl','is.workflow.actions.health.quantity.log'])
 results.append({'file':p.name,'actions':len(ids),'sha256':hashlib.sha256(signed).hexdigest(),'unsigned_sha256':hashlib.sha256(raw).hexdigest(),'apple_root_ca_g3_verified':True,'signature_verified_with_aea':True,'actions_identical_to_source':True,'runtime_network_actions':False,'health_data_embedded':False})
 print(json.dumps({'verified':p.name,'actions':len(ids)}),flush=True)
manifest={'files':results,'required_app_build':12,'signer':'Shortcuty free signing API; templates only, no health values','runtime':'Health read through Apple Shortcuts; import into local Quaderno app','device_execution':'not yet verified'}
(out/'VERIFICA-COMANDI.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
shutil.copy2(root/'LEGGIMI.txt',out/'LEGGIMI.txt')
