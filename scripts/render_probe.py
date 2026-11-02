import json,os,pathlib,subprocess,time

device=os.environ['SIMULATOR_ID']
app=pathlib.Path('build/probe/Build/Products/Debug-iphonesimulator/AbitudiniLocale.app')
output=pathlib.Path('build/render-probe');output.mkdir(parents=True,exist_ok=True)
subprocess.run(['xcrun','simctl','install',device,str(app)],check=True)
with (output/'console.log').open('w',encoding='utf-8') as log:
    process=subprocess.Popen(['xcrun','simctl','launch','--terminate-running-process','--console',device,'local.abitudinilocale.habits','--ui-testing','--render-probe'],stdout=log,stderr=subprocess.STDOUT)
    try:
        time.sleep(10)
        container=pathlib.Path(subprocess.check_output(['xcrun','simctl','get_app_container',device,'local.abitudinilocale.habits','data'],text=True).strip())
        markers=list((container/'Library/Application Support').rglob('probe-ready'))
        subprocess.run(['xcrun','simctl','io',device,'screenshot',str(output/'detail.png')],check=True)
        assert process.poll() is None and markers, 'Detail did not remain alive and render. See console.log.'
        (output/'result.json').write_text(json.dumps({'status':'passed','screen':'habit_detail','layout_container':'scroll','process_alive':True,'render_marker_present':True}),encoding='utf-8')
        print('Native detail rendering passed without UI automation.')
    finally:
        if process.poll() is None: process.terminate();process.wait(timeout=10)
