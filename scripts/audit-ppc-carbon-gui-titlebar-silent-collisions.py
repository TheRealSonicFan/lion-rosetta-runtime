#!/usr/bin/python
from __future__ import print_function
import hashlib, os, struct, subprocess, sys

ANALYZER_VERSION="1"
AUDIT_CONTRACT="carbon-gui-titlebar-silent-collision-inventory-v1"
ARTFILE="/System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/Resources/ArtFile.bin"
EXPECTED={
"10.6.8":dict(build="10K549",size=5946480,sha256="1ca5d946725e5815cb4fc34ef45006aab7220ef1f8e89128e65a5754359b4ec5",record_count=3324,path_len=8,component_count=182,table_start=0x18,string_pool=0x5c8,index_start=0xc4a,payload_start=0xa81c),
"10.7.5":dict(build="11G63",size=4765184,sha256="0cc8e1491be49fb015cb8b290fe9c289e4587bde570804a44a43e2b35e4b19f4",record_count=2674,path_len=8,component_count=169,table_start=0x18,string_pool=0x560,index_start=0xb9d,payload_start=0x88f8)}
KNOWN_SIX={
"titlebarcontrols.close.colorsryg.disabled.regularwin":("a613161f7a000000","9914172272000000"),
"titlebarcontrols.colorsryg.disabled.minimize.regularwin":("a6161f567a000000","9917225572000000"),
"titlebarcontrols.colorsryg.disabled.regularwin.zoom":("a6161f7ab6000000","99172272a9000000"),
"titlebarcontrols.active.close.colorsryg.regularwin":("a60113167a000000","9901141772000000"),
"titlebarcontrols.active.colorsryg.minimize.regularwin":("a60116567a000000","9901175572000000"),
"titlebarcontrols.active.colorsryg.regularwin.zoom":("a601167ab6000000","99011772a9000000")}

def run(cmd):
 p=subprocess.Popen(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT); out=p.communicate()[0]
 if not isinstance(out,str): out=out.decode("utf-8","replace")
 return p.returncode,out
def sha256(path):
 h=hashlib.sha256(); f=open(path,"rb")
 try:
  while True:
   b=f.read(1048576)
   if not b: break
   h.update(b)
 finally: f.close()
 return h.hexdigest()
def w(fp,s=""): fp.write(s+"\n")
def bv(ch): return ch if isinstance(ch,int) else ord(ch)
def hx(data): return "".join("%02x"%bv(ch) for ch in data)
def bs(vals): return "".join(chr(v) for v in vals)
def u16(d,o): return struct.unpack("<H",d[o:o+2])[0]
def u32(d,o): return struct.unpack("<I",d[o:o+4])[0]
def cstr(d,o,limit=512):
 if o<0 or o>=len(d): return None
 out=[]
 for p in range(o,min(len(d),o+limit)):
  v=bv(d[p])
  if v==0: return "".join(out)
  if v<0x20 or v>0x7e: return None
  out.append(chr(v))
 return None
def header(d):
 if len(d)<24: return None
 return dict(record_count=u16(d,0),path_len=u16(d,2),component_count=u16(d,4),table_start=u32(d,8),string_pool=u32(d,12),index_start=u32(d,16),payload_start=u32(d,20))
def dictionary(d,h):
 byid={}; byname={}
 for ident in range(1,h["component_count"]+1):
  e=h["table_start"]+(ident-1)*8
  if e+8>h["string_pool"] or e+8>len(d): break
  name=cstr(d,h["string_pool"]+u32(d,e))
  if name is not None:
   byid[ident]=name
   if name not in byname: byname[name]=ident
 return byid,byname
def index(d,h):
 out=[]; rs=h["path_len"]+4
 for i in range(h["record_count"]):
  o=h["index_start"]+i*rs
  if o+rs>len(d): break
  rel=u32(d,o)
  out.append(dict(index=i,record_off=o,payload_rel=rel,payload_off=h["payload_start"]+rel,key=d[o+4:o+rs]))
 return out
def decode(key,byid):
 names=[]
 for ch in key:
  ident=bv(ch)
  if ident==0: break
  if ident not in byid: return None
  names.append(byid[ident])
 return tuple(names)
def encode(names,byname,path_len):
 ids=[]
 for name in names:
  if name not in byname or byname[name]>255: return None
  ids.append(byname[name])
 if len(ids)>path_len: return None
 return bs(ids+[0]*(path_len-len(ids)))
def validate(product,build,data,artsha,h,recs,issues):
 e=EXPECTED.get(product)
 if e is None: issues.append("unsupported product version: "+product); return
 if build!=e["build"]: issues.append("unexpected build version")
 if len(data)!=e["size"]: issues.append("ArtFile size mismatch")
 if artsha!=e["sha256"]: issues.append("ArtFile SHA mismatch")
 if h is None: issues.append("ArtFile header unavailable"); return
 for k in ("record_count","path_len","component_count","table_start","string_pool","index_start","payload_start"):
  if h.get(k)!=e[k]: issues.append("ArtFile header %s mismatch"%k)
 if len(recs)!=h["record_count"]: issues.append("ArtFile index record count mismatch")
def inventory(recs,byid):
 out=[]
 for r in recs:
  sem=decode(r["key"],byid)
  if sem and sem[0]=="titlebarcontrols":
   row=dict(r); row["semantic"]=sem; out.append(row)
 return out
def parse_snow_report(path,issues):
 entries=[]; meta={}
 if not os.path.isfile(path): issues.append("Snow inventory report missing"); return entries,meta
 f=open(path,"r")
 try:
  for raw in f:
   line=raw.strip()
   if line.startswith("TITLEBAR_ENTRY:"):
    fields={}
    for tok in line[len("TITLEBAR_ENTRY:"):].strip().split():
     if "=" in tok:
      k,v=tok.split("=",1); fields[k]=v
    try:
     entries.append(dict(index=int(fields["index"]),raw_key=fields["raw_key"].lower(),semantic_path=fields["semantic_path"],payload_off=int(fields["payload_off"],16),known_exact_six=fields.get("known_exact_six","NO")))
    except (KeyError,ValueError): issues.append("malformed Snow inventory entry")
   elif "=" in line and not line.startswith("validation_issue="):
    k,v=line.split("=",1); meta[k]=v
 finally: f.close()
 if meta.get("audit_contract")!=AUDIT_CONTRACT: issues.append("Snow inventory audit contract mismatch")
 if meta.get("product_version")!="10.6.8": issues.append("Snow inventory product mismatch")
 if meta.get("build_version")!=EXPECTED["10.6.8"]["build"]: issues.append("Snow inventory build mismatch")
 if meta.get("artfile_sha256")!=EXPECTED["10.6.8"]["sha256"]: issues.append("Snow inventory ArtFile SHA mismatch")
 if meta.get("RESULT")!="PASS": issues.append("Snow inventory did not pass")
 try: declared=int(meta.get("inventory_entry_count","-1"))
 except ValueError: declared=-1
 if declared!=len(entries): issues.append("Snow inventory entry count mismatch")
 return entries,meta
def validation(fp,issues):
 w(fp); w(fp,"== Audit validation ==")
 if issues:
  for issue in issues: w(fp,"validation_issue="+issue)
  w(fp,"RESULT=FAIL"); w(fp,"RESULT: FAIL")
 else:
  w(fp,"RESULT=PASS"); w(fp,"RESULT: PASS")

def main():
 report=sys.argv[1] if len(sys.argv)>1 else "./ppc-carbon-gui-titlebar-silent-collision-inventory.txt"
 peer=sys.argv[2] if len(sys.argv)>2 else None
 issues=[]
 _,po=run(["/usr/bin/sw_vers","-productVersion"]); product=po.strip()
 _,bo=run(["/usr/bin/sw_vers","-buildVersion"]); build=bo.strip()
 data=open(ARTFILE,"rb").read() if os.path.isfile(ARTFILE) else ""
 artsha=sha256(ARTFILE) if os.path.isfile(ARTFILE) else "MISSING"
 if not data: issues.append("ArtFile.bin missing")
 h=header(data)
 if h is None:
  safe=dict(record_count=0,path_len=0,component_count=0,table_start=0,string_pool=0,index_start=0,payload_start=0); byid={}; byname={}; recs=[]
 else:
  safe=h; byid,byname=dictionary(data,h); recs=index(data,h)
 validate(product,build,data,artsha,h,recs,issues)
 with open(report,"w") as fp:
  w(fp,"== PPC Carbon GUI titlebar silent-collision inventory ==")
  w(fp,"analyzer_version="+ANALYZER_VERSION); w(fp,"audit_contract="+AUDIT_CONTRACT); w(fp,"analyzer_script_path="+os.path.realpath(__file__))
  w(fp,"product_version="+product); w(fp,"build_version="+build); w(fp,"artfile_size=%d"%len(data)); w(fp,"artfile_sha256="+artsha)
  w(fp,"record_count=%d"%safe["record_count"]); w(fp,"path_len=%d"%safe["path_len"]); w(fp,"component_count=%d"%safe["component_count"])
  if product=="10.6.8":
   if peer is not None: issues.append("Snow mode must not take a peer report")
   rows=inventory(recs,byid); known=0; seen={}
   w(fp); w(fp,"mode=snow-source-inventory"); w(fp,"inventory_entry_count=%d"%len(rows))
   for row in rows:
    sem=".".join(row["semantic"]); raw=hx(row["key"]); isknown=sem in KNOWN_SIX
    if isknown:
     known+=1
     if raw!=KNOWN_SIX[sem][0]: issues.append("known-six Snow source mismatch: "+sem)
    seen[sem]=seen.get(sem,0)+1
    w(fp,"TITLEBAR_ENTRY: index=%d raw_key=%s semantic_path=%s payload_off=0x%x known_exact_six=%s"%(row["index"],raw,sem,row["payload_off"],"YES" if isknown else "NO"))
   dup=sum(1 for count in seen.values() if count!=1)
   w(fp,"known_exact_six_source_count=%d"%known); w(fp,"duplicate_semantic_path_count=%d"%dup)
   if not rows: issues.append("Snow titlebar inventory is empty")
   if known!=6: issues.append("Snow known-six source count mismatch")
   if dup: issues.append("Snow titlebar semantic paths are not unique")
  elif product=="10.7.5":
   w(fp); w(fp,"mode=lion-cross-release-collision-check")
   snowrows=[]
   if peer is None: issues.append("Lion mode requires Snow inventory report")
   else: snowrows,_=parse_snow_report(peer,issues)
   bykey={}
   for r in recs: bykey.setdefault(r["key"],[]).append(r)
   counts=dict((name,0) for name in ("IDENTITY_SAME_SEMANTIC","SILENT_COLLISION","TRANSLATION_REQUIRED","MISSING_EQUIVALENT","UNRESOLVED_COMPONENT","AMBIGUOUS"))
   outside_collision=0; outside_translation=0; known_translation=0
   for src in snowrows:
    sem=tuple(src["semantic_path"].split("."))
    try: skey=bs([int(src["raw_key"][i:i+2],16) for i in range(0,len(src["raw_key"]),2)])
    except ValueError: issues.append("invalid Snow raw key"); continue
    rawhits=bykey.get(skey,[]); rawsem=decode(rawhits[0]["key"],byid) if len(rawhits)==1 else None
    eqkey=encode(sem,byname,safe["path_len"]); eqhits=bykey.get(eqkey,[]) if eqkey is not None else []
    if len(rawhits)>1 or len(eqhits)>1: cls="AMBIGUOUS"
    elif eqkey is None: cls="UNRESOLVED_COMPONENT"
    elif len(rawhits)==1: cls="IDENTITY_SAME_SEMANTIC" if rawsem==sem else "SILENT_COLLISION"
    elif len(eqhits)==1: cls="TRANSLATION_REQUIRED"
    else: cls="MISSING_EQUIVALENT"
    counts[cls]+=1
    isknown=src["semantic_path"] in KNOWN_SIX
    eqhex=hx(eqkey) if eqkey is not None else "UNRESOLVED"; rawsemtext=".".join(rawsem) if rawsem is not None else "NONE"
    if isknown:
     esrc,etgt=KNOWN_SIX[src["semantic_path"]]
     if src["raw_key"]!=esrc: issues.append("known-six Snow source mismatch in peer report: "+src["semantic_path"])
     if cls!="TRANSLATION_REQUIRED": issues.append("known-six classification changed: "+src["semantic_path"])
     if eqhex!=etgt: issues.append("known-six Lion target mismatch: "+src["semantic_path"])
     if len(eqhits)!=1: issues.append("known-six Lion target hit count mismatch: "+src["semantic_path"])
     if cls=="TRANSLATION_REQUIRED": known_translation+=1
    else:
     if cls=="SILENT_COLLISION": outside_collision+=1
     if cls=="TRANSLATION_REQUIRED": outside_translation+=1
    w(fp,"CROSS_ENTRY: source_index=%d source_raw_key=%s source_semantic_path=%s raw_hit_count=%d raw_lion_semantic=%s equivalent_key=%s equivalent_hit_count=%d classification=%s known_exact_six=%s"%(src["index"],src["raw_key"],src["semantic_path"],len(rawhits),rawsemtext,eqhex,len(eqhits),cls,"YES" if isknown else "NO"))
   w(fp); w(fp,"snow_inventory_entry_count=%d"%len(snowrows))
   w(fp,"identity_same_semantic_count=%d"%counts["IDENTITY_SAME_SEMANTIC"]); w(fp,"silent_collision_count=%d"%counts["SILENT_COLLISION"]); w(fp,"translation_required_count=%d"%counts["TRANSLATION_REQUIRED"])
   w(fp,"missing_equivalent_count=%d"%counts["MISSING_EQUIVALENT"]); w(fp,"unresolved_component_count=%d"%counts["UNRESOLVED_COMPONENT"]); w(fp,"ambiguous_count=%d"%counts["AMBIGUOUS"])
   w(fp,"known_exact_six_translation_count=%d"%known_translation); w(fp,"outside_six_silent_collision_count=%d"%outside_collision); w(fp,"outside_six_translation_required_count=%d"%outside_translation)
   if not snowrows: issues.append("Snow inventory contains no entries")
   if known_translation!=6: issues.append("known-six cross-release translation count mismatch")
  else: issues.append("unsupported execution mode")
  validation(fp,issues)
  w(fp); w(fp,"== Audit integrity =="); w(fp,"The analyzer opened only local ArtFile.bin and, on Lion, the returned Snow text report."); w(fp,"No PowerPC subject was launched."); w(fp,"No process was attached."); w(fp,"No compatibility artifact was built or installed."); w(fp,"No framework, ArtFile, Rosetta cache, service, WindowServer, or XNU state was modified.")
 print("Created: %s"%report)
 if issues:
  print("RESULT: FAIL")
  for issue in issues: print("validation_issue="+issue)
  return 1
 print("RESULT: PASS"); return 0
if __name__=="__main__": sys.exit(main())
