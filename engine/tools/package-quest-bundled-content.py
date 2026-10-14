"""Create deduplicated, bounded Godot v2 data packs and APK-ready ZIP assets.

PCK v2 is the documented legacy layout supported by the current engine. Every
virtual name is retained; identical SHA256 payloads share an offset. Source
mesh hashes are verified while reading. Data is private, outside engine source.
"""
import hashlib, json, shutil, struct, sys, zipfile, tarfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path, PurePosixPath

arguments=sys.argv[1:]
from_pcks=None
if '--from-pcks' in arguments:
    option=arguments.index('--from-pcks');from_pcks=Path(arguments[option+1]);del arguments[option:option+2]
plan_path, target = map(Path, arguments[:2])
plan = json.loads(plan_path.read_text())
root = Path(plan['root'])
target.mkdir(parents=True,exist_ok=True)
if (target/'index.json').exists(): raise RuntimeError('Completed bundle exists; choose a fresh output directory')
limit=640*1024*1024
packs=[]
deduplicated={}
pck_locations={}
if from_pcks:
    for pack in json.loads((from_pcks/'index.json').read_text())['packs']:
        path=from_pcks/pack['file']
        with path.open('rb') as source:
            header=source.read(96);magic,version,major,minor,patch,flags,base=struct.unpack('<IIIIIIQ',header[:32])
            assert magic==0x43504447 and version==2 and flags==2
            count=struct.unpack('<I',source.read(4))[0]
            for _ in range(count):
                length=struct.unpack('<I',source.read(4))[0]
                name=source.read(length).rstrip(b'\0').decode()
                offset,size=struct.unpack('<QQ',source.read(16));source.read(20)
                if name.startswith('imported_data/'):pck_locations[name[len('imported_data/'):]]=(path,base+offset,size)

def new_pack():
    number=len(packs)
    p={'number':number,'payload':target/f'payload-{number:02d}.part','records':[],'bytes':0}
    p['stream']=p['payload'].open('wb');packs.append(p)
    return p

current=new_pack()
processed=set()
processed_count=0
def append_record(record, payload=None):
    global current, processed_count
    name=record['file'];parts=PurePosixPath(name)
    if parts.is_absolute() or '..' in parts.parts: raise RuntimeError('Unsafe content path: '+name)
    claimed=record.get('sha256') if name.endswith('.res') else None
    identity=(claimed,record['bytes'])
    if payload is None and claimed and identity in deduplicated:
        number,offset,md5=deduplicated[identity]
        packs[number]['records'].append(('imported_data/'+name,offset,record['bytes'],md5))
        processed.add(name);processed_count+=1;return
    if payload is None:payload=read_payload(record)
    digest=hashlib.sha256(payload).hexdigest()
    if len(payload)!=record['bytes']:raise RuntimeError('Source changed: '+name)
    # Audio metadata's sha256 describes source SPU bytes, not the decoded WAV.
    # Prepared mesh and raw-entry hashes describe the actual packaged files.
    if record.get('sha256') and (name.endswith('.res') or name.startswith('raw/')) and record['sha256']!=digest:raise RuntimeError('Source asset hash mismatch: '+name)
    identity=(digest,len(payload))
    if identity in deduplicated:
        number,offset,md5=deduplicated[identity]
        p=packs[number]
    else:
        if current['bytes'] and current['bytes']+len(payload)>limit:current=new_pack()
        p=current;offset=p['stream'].tell();md5=hashlib.md5(payload).digest()
        p['stream'].write(payload)
        p['stream'].write(b'\0'*((-p['stream'].tell())%16))
        p['bytes']=p['stream'].tell()
        deduplicated[identity]=(p['number'],offset,md5)
    p['records'].append(('imported_data/'+name,offset,len(payload),md5))
    processed.add(name);processed_count+=1
    if processed_count%20000==0:print('PACKED_SOURCE_FILES',processed_count,'unique',len(deduplicated),'payload_bytes',sum(p['bytes'] for p in packs),flush=True)

# Existing archives avoid hundreds of thousands of random small-file reads.
# Only use an archived mesh when its bytes match the CURRENT manifest SHA256.
lookup={r['file']:r for r in plan['files']}
for archive in arguments[2:]:
    print('READING_VERIFIED_MESH_ARCHIVE',archive,flush=True)
    with tarfile.open(archive,'r|gz') as source:
        for member in source:
            name=member.name.removeprefix('./');record=lookup.get(name)
            if name in processed or not member.isfile() or not name.endswith('.res') or not record or not record.get('sha256'):continue
            if member.size!=record['bytes']:continue
            identity=(record['sha256'],record['bytes'])
            if identity in deduplicated:append_record(record);continue
            payload=source.extractfile(member).read()
            if hashlib.sha256(payload).hexdigest()==record['sha256']:append_record(record,payload)
    print('VERIFIED_ARCHIVE_FILES',processed_count,flush=True)
def read_payload(record):
    if record.get('source'):return Path(record['source']).read_bytes()
    if record['file'] in pck_locations:
        path,offset,size=pck_locations[record['file']]
        with path.open('rb') as source:source.seek(offset);return source.read(size)
    return (root/record['file']).read_bytes()
def read_pending(record):
    if record['file'].endswith('.res') and (record.get('sha256'),record['bytes']) in deduplicated:return record,None
    return record,read_payload(record)
remaining=[r for r in plan['files'] if r['file'] not in processed]
# Bounded prefetch avoids serial Windows small-file latency without retaining
# the complete dataset in RAM. Only the main thread modifies pack metadata.
from collections import deque
with ThreadPoolExecutor(max_workers=8) as readers:
    pending=deque()
    records=iter(remaining)
    for record in records:
        pending.append(readers.submit(read_pending,record))
        if len(pending)>=16:
            item,payload=pending.popleft().result();append_record(item,payload)
    while pending:
        item,payload=pending.popleft().result();append_record(item,payload)

results=[]
for p in packs:
    p['stream'].close()
    directory=bytearray(struct.pack('<I',len(p['records'])))
    for name,offset,size,md5 in p['records']:
        encoded=name.encode();encoded+=b'\0'*((-len(encoded))%4)
        directory+=struct.pack('<I',len(encoded))+encoded+struct.pack('<QQ',offset,size)+md5+struct.pack('<I',0)
    # V2 directory immediately follows the 96-byte header; offsets are relative
    # to file_base. All individual packs stay comfortably below 2 GiB.
    base=(96+len(directory)+15)//16*16
    header=struct.pack('<IIIIIIQ',0x43504447,2,4,7,2,2,base)+b'\0'*64
    name=f'quest-data-{p["number"]:02d}.pck'
    file=target/name
    with file.open('wb') as output,p['payload'].open('rb') as source:
        output.write(header);output.write(directory);output.write(b'\0'*(base-output.tell()))
        shutil.copyfileobj(source,output,1024*1024)
    hash_context=hashlib.sha256()
    with file.open('rb') as source:
        for block in iter(lambda:source.read(1024*1024),b''):hash_context.update(block)
    archive=target/(name+'.zip')
    with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6,allowZip64=False) as package:
        package.write(file,name)
    results.append({'file':name,'archive':archive.name,'bytes':file.stat().st_size,'sha256':hash_context.hexdigest(),'files':len(p['records']),'archiveBytes':archive.stat().st_size})
    print('FINISHED_PACK',json.dumps(results[-1]),flush=True)
    p['payload'].unlink()

index={'schema':1,'files':len(plan['files']),'sourceBytes':plan['bytes'],'uniquePayloads':len(deduplicated),'packs':results}
for field in ['target','requiresOpenXR']:
    if field in plan:index[field]=plan[field]
index['identity']=hashlib.sha256(json.dumps(results,separators=(',',':')).encode()).hexdigest()
(target/'index.json').write_text(json.dumps(index,indent=2))
print('BUNDLE_COMPLETE',json.dumps({'files':index['files'],'packs':len(results),'archiveBytes':sum(p['archiveBytes'] for p in results),'identity':index['identity']}),flush=True)
