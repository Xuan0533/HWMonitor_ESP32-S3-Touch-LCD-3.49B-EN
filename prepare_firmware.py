"""Download official V2 sources or use local checkout, stage a custom Arduino sketch."""
import argparse, pathlib, shutil, tempfile, urllib.request, zipfile, re
ROOT=pathlib.Path(__file__).resolve().parent
URL='https://codeload.github.com/waveshareteam/ESP32-S3-Touch-LCD-3.49-V2/zip/refs/heads/main'

def _stage(source, dest):
    source=pathlib.Path(source);dest=pathlib.Path(dest)
    src=source/'Arduino'/'examples'/'10_LVGL_V9_Test'
    if not src.is_dir():raise RuntimeError('V2 Arduino/examples/10_LVGL_V9_Test not found')
    cfg=(src/'user_config.h').read_text(encoding='utf-8-sig')
    if not re.search(r'EXAMPLE_PIN_NUM_BK_LIGHT\s+\(GPIO_NUM_42\)',cfg):raise RuntimeError('V2 GPIO42 backlight signature absent; refusing to patch')
    port=(src/'lvgl_port.c').read_text(encoding='utf-8-sig')
    if port.count('lv_demo_widgets();')!=1:raise RuntimeError('Unexpected upstream LVGL entry point; inspect manually')
    cfg,n=re.subn(r'(#define\s+Rotated\s+)USER_DISP_ROT_NONO',r'\g<1>USER_DISP_ROT_90',cfg)
    if n!=1:raise RuntimeError('Unexpected rotation macro')
    port='extern void pc_monitor_ui_init(void);\n'+port.replace('lv_demo_widgets();','pc_monitor_ui_init();')
    if dest.exists():raise RuntimeError(f'{dest} already exists. Rename it first to preserve modifications.')
    dest.mkdir(parents=True);sketch=dest/'PCMonitorV2';shutil.copytree(src,sketch)
    if (source/'LICENSE').exists():shutil.copy2(source/'LICENSE',dest/'Waveshare-LICENSE')
    (sketch/'10_LVGL_V9_Test.ino').rename(sketch/'PCMonitorV2.ino')
    ino=sketch/'PCMonitorV2.ino'
    text=ino.read_text(encoding='utf-8-sig')
    if 'Serial.setRxBufferSize(4096)' not in text:
        text,n=re.subn(r'Serial\.begin\s*\(\s*115200\s*\)\s*;', 'Serial.setRxBufferSize(4096);\\n  Serial.begin(115200);',text)
        if n!=1:raise RuntimeError('Unexpected upstream Serial.begin; inspect before compiling')
    ino.write_text(text,encoding='utf-8')
    (sketch/'user_config.h').write_text(cfg,encoding='utf-8')
    (sketch/'lvgl_port.c').write_text(port,encoding='utf-8')
    shutil.copy2(ROOT/'firmware'/'monitor_ui.cpp',sketch/'monitor_ui.cpp')
    libsource=source/'Arduino'/'libraries';libdest=dest/'libraries';libdest.mkdir()
    found=False
    if libsource.is_dir():
        for prop in libsource.rglob('library.properties'):
            parent=prop.parent; data=prop.read_text(encoding='utf-8-sig',errors='replace');name=re.search(r'^name\s*=\s*(.+)$',data,re.M);version=re.search(r'^version\s*=\s*(.+)$',data,re.M)
            if not name:continue
            libname=name.group(1).strip();ver=version.group(1).strip() if version else ''
            if libname.lower()=='lvgl' or (parent/'src'/'lvgl.h').exists():
                if not ver.startswith('9.3.'):continue
                libname='lvgl';found=True
            elif any(x.lower().startswith('lvgl') for x in parent.parts[len(libsource.parts):]):continue
            out=libdest/libname
            if not out.exists():shutil.copytree(parent,out)
        # Official lv_conf.h is sometimes next to the LVGL library.
        configs=list(libsource.rglob('lv_conf.h'))
        if found and not (libdest/'lvgl'/'lv_conf.h').exists():
            c=next((p for p in configs if any('9' in q and 'lvgl' in q.lower() for q in p.parts)),None)
            if c:shutil.copy2(c,libdest/'lv_conf.h')
    if not found:raise RuntimeError('Official LVGL 9.3 library not found.')
    return sketch

def stage(source, dest):
    dest=pathlib.Path(dest).resolve()
    if dest.exists(): raise RuntimeError(f'{dest} already exists. Rename it first to preserve modifications.')
    dest.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(dir=dest.parent,prefix='.stage-') as work:
        staged=pathlib.Path(work)/'build'
        _stage(source,staged)
        staged.rename(dest)
    print('Sketch:', dest/'PCMonitorV2'/'PCMonitorV2.ino');print('Official libraries:',dest/'libraries')
    return dest/'PCMonitorV2'

def main():
    p=argparse.ArgumentParser();p.add_argument('--source',type=pathlib.Path);p.add_argument('--dest',type=pathlib.Path,default=ROOT/'build');a=p.parse_args()
    if a.source:stage(a.source,a.dest);return
    with tempfile.TemporaryDirectory() as tmp:
        tmp=pathlib.Path(tmp);archive=tmp/'v2.zip';print('Downloading official Waveshare V2 repository ...');
        with urllib.request.urlopen(URL,timeout=60) as response, archive.open('wb') as out: shutil.copyfileobj(response,out)
        with zipfile.ZipFile(archive) as z:
            for n in z.namelist():
                if not (tmp/n).resolve().is_relative_to(tmp.resolve()):raise RuntimeError('Unsafe zip path')
            z.extractall(tmp)
        source=next(p for p in tmp.iterdir() if p.is_dir());stage(source,a.dest)
if __name__=='__main__':main()
