"""Select the Quest VR runtime data without changing its assets or fidelity."""
import collections, json, pathlib, sys

root=pathlib.Path(sys.argv[1]).absolute()
output=pathlib.Path(sys.argv[2]).absolute()
overrides=output.parent/'quest3-slim-overrides'
overrides.mkdir(exist_ok=True)
records={r['file']:r for p in sys.argv[3:] for r in json.loads(pathlib.Path(p).read_text())['files']}
manifest=json.loads((root/'manifest.json').read_text())
portals={int(e['scene_id']) for e in manifest['cutsceneSequencePortalCaches'] if int(e.get('revision',0))==1}
assert portals=={int(e['scene_id']) for e in manifest['cutsceneSequenceCaches']}
overridden={}
def save_override(name,value):
    source=overrides/name;source.parent.mkdir(parents=True,exist_ok=True)
    source.write_text(json.dumps(value,separators=(',',':')))
    overridden[name]=source

manifest['cutsceneSequenceImages']=[]
manifest['quest3Optimized']={'schema':1,'presentation':'prepared_vr_portals','audio':'original_compressed_streams'}
for field in ['cutsceneAudio','cutsceneSequenceAudio']:
    for entry in manifest[field]:
        assert entry.get('compressedFile')
        entry.pop('file',None)
save_override('manifest.json',manifest)
music=json.loads((root/manifest['musicIndex']).read_text())
for stream in music['streams']:
    assert stream.get('compressedFile');stream.pop('file',None)
save_override(manifest['musicIndex'],music)

# The prepared portal path uses the legacy cache only for identity, part sizes,
# frame counts and offsets. It never reads its per-frame mesh/pass references.
# Keep these checks while avoiding large duplicate geometry descriptors in RAM.
for entry in manifest['cutsceneSequenceCaches']:
    descriptor=json.loads((root/entry['file']).read_text())
    for part in descriptor['parts']:
        part['frames']=[{'index':i,'h':frame.get('h',480)} for i,frame in enumerate(part['frames'])]
    descriptor['quest3MetadataOnly']=True
    save_override(entry['file'],descriptor)

removed=collections.defaultdict(lambda:{'files':0,'bytes':0})
kept=[]
for name,record in records.items():
    reason=None
    if name.startswith('raw/'):reason='source_archive_backups'
    elif name.endswith('.wav') and (name.startswith('music/') or name.startswith('audio/cutscene-')):reason='decoded_music_and_movie_audio'
    elif name.endswith('.cfi') or '-images/' in name:reason='desktop_movie_images'
    elif name.endswith('.res') and name.startswith('resources/sequence-') and '-portals-' not in name:reason='desktop_movie_meshes'
    if reason:
        removed[reason]['files']+=1;removed[reason]['bytes']+=record['bytes'];continue
    item=record.copy()
    if name in overridden:
        item['source']=str(overridden[name]);item['bytes']=overridden[name].stat().st_size;item.pop('sha256',None)
    kept.append(item)
plan={'root':str(root),'target':'quest3','requiresOpenXR':True,'files':kept,'bytes':sum(r['bytes'] for r in kept),'removed':dict(removed)}
output.write_text(json.dumps(plan,separators=(',',':')))
print(json.dumps({'files':len(kept),'bytes':plan['bytes'],'removed':dict(removed)},indent=2))
