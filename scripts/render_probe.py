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
        commands=subprocess.check_output(['ps','-axo','pid=,command='],text=True)
        app_pids=[int(line.strip().split(maxsplit=1)[0]) for line in commands.splitlines() if 'AbitudiniLocale.app/AbitudiniLocale' in line and '--render-probe' in line]
        subprocess.run(['xcrun','simctl','io',device,'screenshot',str(output/'detail.png')],check=True)
        assert len(app_pids)==1, 'Expected one live detail app process. See console.log and screenshot.'
        os.kill(app_pids[0],0)
        assert 'Fatal error:' not in (output/'console.log').read_text(encoding='utf-8',errors='replace')
        (output/'result.json').write_text(json.dumps({'status':'passed','screen':'habit_detail','layout_container':'scroll','process_alive':True,'render_marker_present':bool(markers)}),encoding='utf-8')
        print('Native detail process is alive; screenshot captured. Readiness marker is diagnostic only.')
    finally:
        if process.poll() is None: process.terminate();process.wait(timeout=10)
