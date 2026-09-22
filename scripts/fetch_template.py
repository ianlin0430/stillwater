"""Fetch only macos.zip from the official range-readable template archive."""
import urllib.request, struct, zipfile, io, zlib, pathlib
url='https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/Godot_v4.6.3-stable_export_templates.tpz'
size=1255918323

def read_range(start, end):
    request=urllib.request.Request(url,headers={'Range':f'bytes={start}-{end}'})
    with urllib.request.urlopen(request,timeout=120) as response:
        if response.status != 206:
            raise RuntimeError(f'Expected partial content, received {response.status}')
        data=response.read()
        if len(data)!=end-start+1:
            raise RuntimeError(f'Unexpected length {len(data)} expected {end-start+1}')
        return data

tail=read_range(size-65536,size-1)
pos=tail.rfind(b'PK\x05\x06')
_,_,_,_,_,cdsize,cdoffset,_=struct.unpack('<4s4H2LH',tail[pos:pos+22])
central=read_range(cdoffset,cdoffset+cdsize-1)
pos=0
while pos<len(central):
    fields=struct.unpack('<4s6H3L5H2L',central[pos:pos+46])
    method,compressed,fn,extra,comment,offset=fields[4],fields[8],fields[10],fields[11],fields[12],fields[16]
    name=central[pos+46:pos+46+fn].decode()
    if name.endswith('macos.zip'):
        header=read_range(offset,offset+29)
        local=struct.unpack('<4s5H3L2H',header)
        begin=offset+30+local[-2]+local[-1]
        print(f'Fetching {name}: {compressed/1e6:.1f} MB',flush=True)
        packed=read_range(begin,begin+compressed-1)
        data=zlib.decompress(packed,-15) if method==8 else packed
        zipfile.ZipFile(io.BytesIO(data)).testzip()
        dest=pathlib.Path.home()/'Library/Application Support/Godot/export_templates/4.6.3.stable'
        dest.mkdir(parents=True,exist_ok=True)
        (dest/'macos.zip').write_bytes(data)
        (dest/'version.txt').write_text('4.6.3.stable')
        print(f'Installed {dest}/macos.zip',flush=True)
        break
    pos+=46+fn+extra+comment
else:
    raise RuntimeError('macos.zip missing')
