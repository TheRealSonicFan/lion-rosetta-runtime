#!/usr/bin/python
from __future__ import print_function
import hashlib, os, shutil, struct, subprocess, sys, tempfile
ANALYZER_VERSION='1'; AUDIT_CONTRACT='carbon-gui-titlebar-payload-fidelity-v1'
COREUI='/System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/CoreUI'
ARTFILE='/System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/Resources/ArtFile.bin'
LOAD_FROM_ARTFILE='__ZN10CUIElement15LoadFromArtFileEPKh'
LOAD_SNOW='__ZN10CUIElement4LoadEP11_QSIContextPK13CUIDescriptorlll'
LOAD_LION='__ZN10CUIElement4LoadEPvPK13CUIDescriptorlll'
EXPECTED={
'10.6.8':dict(build='10K549',arch='ppc7400',load_symbol=LOAD_SNOW,coreui_slice_sha256='5ee01965d2702b9c05109d17404798509a10ef3d2019b35aefd5bc14199e0839',artfile_size=5946480,artfile_sha256='1ca5d946725e5815cb4fc34ef45006aab7220ef1f8e89128e65a5754359b4ec5',record_count=3324,path_len=8,component_count=182,table_start=0x18,string_pool=0x5c8,index_start=0xc4a,payload_start=0xa81c),
'10.7.5':dict(build='11G63',arch='i386',load_symbol=LOAD_LION,coreui_slice_sha256='5218230aa2920f3aaf4983de76da758b5fb5168ed8a74636312cd1a57a9ab30b',artfile_size=4765184,artfile_sha256='0cc8e1491be49fb015cb8b290fe9c289e4587bde570804a44a43e2b35e4b19f4',record_count=2674,path_len=8,component_count=169,table_start=0x18,string_pool=0x560,index_start=0xb9d,payload_start=0x88f8)}
TARGETS=[
('disabled-clear',('titlebarcontrols','close','colorsryg','disabled','regularwin')),
('disabled-minus',('titlebarcontrols','colorsryg','disabled','minimize','regularwin')),
('disabled-zoom',('titlebarcontrols','colorsryg','disabled','regularwin','zoom')),
('active-clear',('titlebarcontrols','active','close','colorsryg','regularwin')),
('active-minus',('titlebarcontrols','active','colorsryg','minimize','regularwin')),
('active-zoom',('titlebarcontrols','active','colorsryg','regularwin','zoom'))]
def run(cmd):
 p=subprocess.Popen(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT); out=p.communicate()[0]
 if not isinstance(out,str): out=out.decode('utf-8','replace')
 return p.returncode,out
def sha_file(path):
 h=hashlib.sha256(); f=open(path,'rb')
 try:
  while True:
   b=f.read(1048576)
   if not b: break
   h.update(b)
 finally: f.close()
 return h.hexdigest()
def sha_bytes(data):
 h=hashlib.sha256(); h.update(data); return h.hexdigest()
def w(fp,s=''): fp.write(s+'\n')
def bv(ch): return ch if isinstance(ch,int) else ord(ch)
def u16(d,o): return struct.unpack('<H',d[o:o+2])[0]
def u32(d,o): return struct.unpack('<I',d[o:o+4])[0]
def hx(d): return ''.join('%02x'%bv(c) for c in d)
def bs(vals): return ''.join(chr(v) for v in vals)
def cstr(d,o,limit=512):
 if o<0 or o>=len(d): return None
 out=[]
 for p in range(o,min(len(d),o+limit)):
  v=bv(d[p])
  if v==0: return ''.join(out)
  if not 0x20<=v<=0x7e: return None
  out.append(chr(v))
 return None
def header(d):
 if len(d)<24: return None
 return dict(record_count=u16(d,0),path_len=u16(d,2),component_count=u16(d,4),table_start=u32(d,8),string_pool=u32(d,12),index_start=u32(d,16),payload_start=u32(d,20))
def dictionary(d,h):
 byname={}; byid={}
 for ident in range(1,h['component_count']+1):
  e=h['table_start']+(ident-1)*8
  if e+8>h['string_pool'] or e+8>len(d): continue
  t=cstr(d,h['string_pool']+u32(d,e))
  if t is not None: byname[t]=ident; byid[ident]=t
 return byname,byid
def index(d,h):
 out=[]; rs=h['path_len']+4
 for i in range(h['record_count']):
  o=h['index_start']+i*rs
  if o+rs>len(d): break
  r=u32(d,o); out.append(dict(index=i,record_off=o,payload_rel=r,payload_off=h['payload_start']+r,key=d[o+4:o+rs]))
 return out
def local_key(sem,byname,path_len):
 ids=[]
 for name in sem:
  if name not in byname: return None
  ids.append(byname[name])
 if len(ids)>path_len: return None
 return bs(ids+[0]*(path_len-len(ids)))
def parse_hex(tok):
 tok=tok.rstrip(':'); tok=tok[2:] if tok.startswith(('0x','0X')) else tok
 if not tok or any(c not in '0123456789abcdefABCDEF' for c in tok): return None
 try: return int(tok,16)
 except ValueError: return None
def symbols(text):
 ordered=[]; by={}
 for line in text.splitlines():
  p=line.split()
  if len(p)<2 or '(__TEXT,__text)' not in line: continue
  a=parse_hex(p[0])
  if a is None: continue
  n=p[-1]; ordered.append((a,n)); by.setdefault(n,a)
 ordered.sort(); return ordered,by
def instructions(text):
 out=[]
 for line in text.splitlines():
  p=line.split(None,1)
  if not p: continue
  a=parse_hex(p[0])
  if a is not None: out.append((a,line))
 return out
def body(rows,syms,name):
 idx=None
 for i,x in enumerate(syms):
  if x[1]==name: idx=i; break
 if idx is None: return []
 start=syms[idx][0]; end=syms[idx+1][0] if idx+1<len(syms) else None
 return [(a,l) for a,l in rows if a>=start and (end is None or a<end)]
def thin(src,arch,dst):
 rc,_=run(['/usr/bin/lipo',src,'-verify_arch',arch])
 if rc!=0:
  rc,_=run(['/usr/bin/lipo','-verify_arch',arch,src])
 if rc!=0: return False
 rc,_=run(['/usr/bin/lipo',src,'-thin',arch,'-output',dst]); return rc==0
def emit_consumer(fp,tmp,e,issues):
 out=os.path.join(tmp,'CoreUI.'+e['arch'])
 w(fp); w(fp,'== CoreUI local ArtFile consumer =='); w(fp,'coreui_path='+COREUI); w(fp,'required_arch='+e['arch'])
 if not thin(COREUI,e['arch'],out): w(fp,'coreui_thin=NO'); issues.append('CoreUI missing required arch'); return
 sh=sha_file(out); w(fp,'coreui_thin=YES'); w(fp,'coreui_slice_sha256='+sh)
 if sh!=e['coreui_slice_sha256']: issues.append('CoreUI slice SHA mismatch')
 rc,nm=run(['/usr/bin/nm','-nm',out]); rc2,dis=run(['/usr/bin/otool','-tvV',out])
 if rc!=0 or rc2!=0: issues.append('CoreUI static tools failed'); w(fp,'coreui_static_tools=FAIL'); return
 syms,by=symbols(nm); rows=instructions(dis); w(fp,'coreui_static_tools=PASS')
 for name in (LOAD_FROM_ARTFILE,e['load_symbol']):
  w(fp); w(fp,'== CoreUI symbol: '+name+' ==')
  if name not in by: w(fp,'present=NO'); issues.append('CoreUI target missing: '+name); continue
  b=body(rows,syms,name); w(fp,'present=YES'); w(fp,'symbol_address=0x%x'%by[name]); w(fp,'instruction_lines=%d'%len(b))
  for _,line in b: w(fp,line)
def main():
 report=sys.argv[1] if len(sys.argv)>1 else './ppc-carbon-gui-titlebar-payload-fidelity.txt'; issues=[]; tmp=tempfile.mkdtemp(prefix='ppc-carbon-titlebar-fidelity.')
 try:
  _,po=run(['/usr/bin/sw_vers','-productVersion']); product=po.strip(); _,bo=run(['/usr/bin/sw_vers','-buildVersion']); build=bo.strip(); e=EXPECTED.get(product)
  if e is None: e=EXPECTED['10.7.5']; issues.append('unsupported product version: '+product)
  data=open(ARTFILE,'rb').read() if os.path.isfile(ARTFILE) else b''
  if not data: issues.append('ArtFile.bin missing')
  h=header(data)
  if h is None: h=dict(record_count=0,path_len=0,component_count=0,table_start=0,string_pool=0,index_start=0,payload_start=0); issues.append('ArtFile header unavailable')
  artsha=sha_file(ARTFILE) if os.path.isfile(ARTFILE) else 'MISSING'
  if build!=e['build']: issues.append('unexpected build version')
  if len(data)!=e['artfile_size']: issues.append('ArtFile size mismatch')
  if artsha!=e['artfile_sha256']: issues.append('ArtFile SHA mismatch')
  for k in ('record_count','path_len','component_count','table_start','string_pool','index_start','payload_start'):
   if h.get(k)!=e[k]: issues.append('ArtFile header %s mismatch'%k)
  byname,_=dictionary(data,h); recs=index(data,h)
  if len(recs)!=h['record_count']: issues.append('ArtFile index record count mismatch')
  results=[]
  for label,sem in TARGETS:
   key=local_key(sem,byname,h['path_len']); hits=[r for r in recs if key is not None and r['key']==key]
   if key is None: issues.append(label+' local semantic key unresolved')
   if len(hits)!=1: issues.append('%s local semantic key hit count %d'%(label,len(hits)))
   results.append((label,sem,key,hits))
  with open(report,'w') as fp:
   w(fp,'== PPC Carbon GUI titlebar payload fidelity audit =='); w(fp,'analyzer_version='+ANALYZER_VERSION); w(fp,'audit_contract='+AUDIT_CONTRACT); w(fp,'analyzer_script_path='+os.path.realpath(__file__)); w(fp,'product_version='+product); w(fp,'build_version='+build); w(fp,'required_arch='+e['arch']); w(fp,'artfile_path='+ARTFILE); w(fp,'artfile_size=%d'%len(data)); w(fp,'artfile_sha256='+artsha)
   w(fp); w(fp,'== Legacy ArtFile geometry ==')
   for k in ('record_count','path_len','component_count','table_start','string_pool','index_start','payload_start'): w(fp,'%s=0x%x'%(k,h[k]) if k not in ('record_count','path_len','component_count') else '%s=%d'%(k,h[k]))
   w(fp); w(fp,'== Six rendered-titlebar semantic payloads ==')
   unique=sorted(set(r['payload_off'] for r in recs if 0<=r['payload_off']<=len(data)))
   for label,sem,key,hits in results:
    w(fp,'path='+label); w(fp,'semantic_path='+'.'.join(sem)); w(fp,'local_key='+(hx(key) if key is not None else 'UNRESOLVED')); w(fp,'local_index_hits=%d'%len(hits))
    for r in hits:
     start=r['payload_off']; nxt=[x for x in unique if x>start]; end=nxt[0] if nxt else len(data); span=data[start:end] if 0<=start<=end<=len(data) else b''; p68=span[:0x68]; p100=span[:0x100]
     w(fp,'index=%d'%r['index']); w(fp,'record_off=0x%x'%r['record_off']); w(fp,'payload_rel=0x%x'%r['payload_rel']); w(fp,'payload_off=0x%x'%start); w(fp,'payload_span_end=0x%x'%end); w(fp,'payload_span_length=%d'%len(span)); w(fp,'payload_span_sha256='+sha_bytes(span)); w(fp,'payload_prefix_0x68_length=%d'%len(p68)); w(fp,'payload_prefix_0x68_sha256='+sha_bytes(p68)); w(fp,'payload_prefix_0x68_hex='+hx(p68)); w(fp,'payload_prefix_0x100_hex='+hx(p100))
    w(fp)
   emit_consumer(fp,tmp,e,issues)
   w(fp); w(fp,'== Audit validation ==')
   if issues:
    for x in issues: w(fp,'validation_issue='+x)
    w(fp,'RESULT: FAIL')
   else: w(fp,'six_payload_records_exact=YES'); w(fp,'RESULT: PASS')
   w(fp); w(fp,'== Audit integrity =='); w(fp,'The analyzer opened only local CoreUI and ArtFile.bin for reading.'); w(fp,'It created only a temporary architecture slice for disassembly.'); w(fp,'No PowerPC subject was launched.'); w(fp,'No process was attached.'); w(fp,'No framework, ArtFile, Rosetta cache, service, WindowServer, or XNU state was modified.')
  print('Created: %s'%report)
  if issues:
   print('RESULT: FAIL')
   for x in issues: print('validation_issue='+x)
   return 1
  print('RESULT: PASS'); return 0
 finally: shutil.rmtree(tmp,ignore_errors=True)
if __name__=='__main__': sys.exit(main())
