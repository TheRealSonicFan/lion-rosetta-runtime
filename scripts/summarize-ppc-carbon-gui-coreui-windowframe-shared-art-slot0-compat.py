#!/usr/bin/python
from __future__ import print_function
import re, sys
ANALYZER_VERSION='1'
AUDIT_CONTRACT='carbon-gui-coreui-windowframe-shared-art-slot0-compat-live-v1'
BUILD_ID='coreui-windowframe-shared-art-slot0-compat-v1'
MAP={0x4e8d:0x4e75,0x4e8e:0x4e76,0x4e8f:0x4e77,0x4e90:0x4e78,0x4e91:0x4e79}
SNOW_ORDER=[0x4e8e,0x4e90,0x4e8d,0x4e8f,0x4e91]
RAW_IDS=set([0x4e8e,0x4e8d])
IMAGEIO_IDS=set([0x4e90,0x4e8f,0x4e91])
R=re.compile(r'^PM_COREUI_SHARED_ART_SLOT0_COMPAT:(PASSTHROUGH|SOURCE_BIND|CALL|RESULT) branch=(RAW|IMAGEIO) legacy_id=(0x[0-9a-fA-F]+) lion_id=(0x[0-9a-fA-F]+)(?: result=([^ ]+))?$')
def emit(f,s=''): f.write(s+'\n')
def main():
    if len(sys.argv)!=3:
        print('usage: %s SUBJECT_LOG OUTPUT'%sys.argv[0],file=sys.stderr); return 64
    lines=open(sys.argv[1],'r').readlines(); product=build=None; items=[]; issues=[]
    for x in lines:
        s=x.strip()
        if s.startswith('product_version='): product=s.split('=',1)[1]
        elif s.startswith('build_version='): build=s.split('=',1)[1]
        m=R.match(s)
        if m: items.append(dict(phase=m.group(1),branch=m.group(2),legacy=int(m.group(3),16),lion=int(m.group(4),16),result=m.group(5)))
    mode='snow' if product=='10.6.8' and build=='10K549' else ('lion' if product=='10.7.5' and build=='11G63' else 'unknown')
    build_count=sum(1 for x in lines if x.strip()=='PM_COREUI_IMAGE_BITMAPINFO_COMPAT_BUILD_ID:'+BUILD_ID)
    runner_pass=any(x.strip()=='RESULT: PASS' for x in lines)
    exact=sum(1 for x in lines if x.startswith('PM_COREUI_IMAGE_BITMAPINFO_COMPAT_CALL:') and ' exact=YES ' in x)
    adapted=sum(1 for x in lines if x.strip()=='PM_COREUI_IMAGE_BITMAPINFO_COMPAT_ADAPTED:from=0x00000002 to=0x00002002')
    passthrough_bm=sum(1 for x in lines if x.strip()=='PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:PASSTHROUGH')
    bitmap_pass=sum(1 for x in lines if x.strip()=='PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:ADAPTER_PASS')
    if mode=='unknown': issues.append('unsupported product/build')
    if build_count!=1: issues.append('build marker count mismatch')
    if not runner_pass: issues.append('underlying runner did not pass')
    if exact!=6: issues.append('bitmapInfo exact-six count mismatch')
    for i in items:
        if MAP.get(i['legacy'])!=i['lion']: issues.append('mapping mismatch for 0x%04x'%i['legacy'])
    pass_items=[i for i in items if i['phase']=='PASSTHROUGH']
    binds=[i for i in items if i['phase']=='SOURCE_BIND']
    calls=[i for i in items if i['phase']=='CALL']
    results=[i for i in items if i['phase']=='RESULT']
    if mode=='snow':
        if adapted!=0 or passthrough_bm!=6 or bitmap_pass!=0: issues.append('Snow bitmapInfo counts mismatch')
        if [i['legacy'] for i in pass_items if i['branch']=='RAW']!=SNOW_ORDER: issues.append('Snow slot0 passthrough order mismatch')
        if binds or calls or results: issues.append('Snow produced slot0 adaptation activity')
    elif mode=='lion':
        if adapted!=6 or passthrough_bm!=0 or bitmap_pass!=6: issues.append('Lion bitmapInfo counts mismatch')
        raw_calls=[i for i in calls if i['branch']=='RAW']; image_calls=[i for i in calls if i['branch']=='IMAGEIO']
        raw_results=[i for i in results if i['branch']=='RAW']; image_results=[i for i in results if i['branch']=='IMAGEIO']
        if set(i['legacy'] for i in raw_calls)!=RAW_IDS or len(raw_calls)!=2: issues.append('Lion raw adaptation ID set mismatch')
        if set(i['legacy'] for i in image_calls)!=IMAGEIO_IDS or len(image_calls)!=3: issues.append('Lion ImageIO adaptation ID set mismatch')
        if set(i['legacy'] for i in binds)!=IMAGEIO_IDS or len(binds)!=3: issues.append('Lion source binding ID set mismatch')
        if len(raw_results)!=2 or len(image_results)!=3: issues.append('Lion result count mismatch')
        for i in results:
            if i.get('result')!='ADAPTER_PASS': issues.append('Lion slot0 adapter non-pass result')
        if any(i.get('result')!='BOUND' for i in binds): issues.append('Lion source bind result mismatch')
        if pass_items: issues.append('Lion unexpected slot0 passthrough marker')
    f=open(sys.argv[2],'w')
    try:
        emit(f,'== PPC Carbon GUI CoreUI shared-art slot0 compatibility summary ==')
        emit(f,'analyzer_version=%s'%ANALYZER_VERSION); emit(f,'audit_contract=%s'%AUDIT_CONTRACT)
        emit(f,'mode=%s'%mode); emit(f,'product_version=%s'%(product or 'UNKNOWN')); emit(f,'build_version=%s'%(build or 'UNKNOWN'))
        emit(f,'build_marker_count=%d'%build_count); emit(f,'runner_result_pass=%s'%('YES' if runner_pass else 'NO'))
        emit(f,'image_bitmapinfo_exact_call_count=%d'%exact); emit(f,'image_bitmapinfo_adapted_count=%d'%adapted); emit(f,'image_bitmapinfo_passthrough_count=%d'%passthrough_bm); emit(f,'image_bitmapinfo_adapter_pass_count=%d'%bitmap_pass)
        emit(f); emit(f,'== Slot0 compatibility activity ==')
        emit(f,'snow_raw_passthrough_count=%d'%len(pass_items)); emit(f,'source_bind_count=%d'%len(binds)); emit(f,'adapter_call_count=%d'%len(calls)); emit(f,'adapter_result_count=%d'%len(results))
        for i in items: emit(f,'activity phase=%s branch=%s legacy_id=0x%04x lion_id=0x%04x result=%s'%(i['phase'],i['branch'],i['legacy'],i['lion'],i.get('result') or 'NONE'))
        emit(f); emit(f,'== Validation ==')
        if issues:
            for issue in issues: emit(f,'validation_issue=%s'%issue)
            emit(f,'RESULT: FAIL')
        else:
            emit(f,'shared_art_slot0_compat_exact=YES'); emit(f,'RESULT: PASS')
    finally: f.close()
    print('Created: %s'%sys.argv[2])
    if issues:
        print('RESULT: FAIL')
        for issue in issues: print('validation_issue=%s'%issue)
        return 1
    print('RESULT: PASS'); return 0
if __name__=='__main__': sys.exit(main())
