import pathlib,plistlib,struct,hashlib,ssl,subprocess,json
base=pathlib.Path('ShortcutFiles'); tmp=pathlib.Path('shortcut-check');tmp.mkdir(exist_ok=True)
root=base/'AppleRootCA-G3.cer'; assert hashlib.sha256(root.read_bytes()).hexdigest()=='63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179'
rootpem=tmp/'root.pem';rootpem.write_text(ssl.DER_cert_to_PEM_cert(root.read_bytes()))
results=[]
for index,p in enumerate(sorted((base/'Signed').glob('*.shortcut'))):
 work=tmp/str(index);work.mkdir(exist_ok=True)
 signed=p.read_bytes();assert signed[:4]==b'AEA1';n=struct.unpack('<I',signed[8:12])[0]
 chain=plistlib.loads(signed[12:12+n])['SigningCertificateChain'];assert chain[-1]==root.read_bytes()
 leaf=work/'leaf.pem';leaf.write_text(ssl.DER_cert_to_PEM_cert(chain[0]))
 inter=work/'intermediate.pem';inter.write_text(''.join(ssl.DER_cert_to_PEM_cert(c) for c in chain[1:-1]))
 subprocess.run(['openssl','verify','-CAfile',str(rootpem),'-untrusted',str(inter),str(leaf)],check=True)
 public=work/'public.pem'
 with public.open('wb') as f:subprocess.run(['openssl','x509','-in',str(leaf),'-pubkey','-noout'],stdout=f,check=True)
 aar=work/'decoded.aar';subprocess.run(['aea','decrypt','-i',str(p),'-o',str(aar),'-sign-pub',str(public)],check=True)
 extracted=work/'extracted';extracted.mkdir();subprocess.run(['aa','extract','-i',str(aar),'-d',str(extracted)],check=True)
 candidates=[]
 for f in extracted.rglob('*'):
  if f.is_file():
   try:
    item=plistlib.loads(f.read_bytes())
    if isinstance(item,dict) and 'WFWorkflowActions' in item:candidates.append(item)
   except Exception:pass
 assert len(candidates)==1
 source=plistlib.loads((base/'Unsigned'/p.name).read_bytes())
 assert source['WFWorkflowActions']==candidates[0]['WFWorkflowActions'],'Actions differ from prepared source'
 ids=[a['WFWorkflowActionIdentifier'] for a in source['WFWorkflowActions']]
 assert not any(x in ids for x in ['is.workflow.actions.downloadurl','is.workflow.actions.health.quantity.log'])
 results.append({'file':p.name,'sha256':hashlib.sha256(signed).hexdigest(),'actions':len(ids),'apple_certificate_chain_verified':True,'aea_signature_verified':True,'actions_identical_to_source':True,'device_execution':'not yet tested'})
 print(json.dumps(results[-1]),flush=True)
(tmp/'VERIFICA-COMANDI.json').write_text(json.dumps(results,indent=2)+'\n')
