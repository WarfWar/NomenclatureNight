import json
from pathlib import Path
d=json.loads(Path("data/story.json").read_text(encoding="utf-8"))
nodes=d["nodes"]
assert d["entry"] in nodes
for key,n in nodes.items():
    assert n["title"] and n["text"],key
    assert n["world"] and n["hero"],key
    assert n["choices"],key
    for c in n["choices"]:
        assert c["next"] in nodes,(key,c["next"])
        assert int(c["cost"])>=0,key
        for k,v in c.get("effects",{}).items():
            assert k in {"insight","resolve","trust","heat"}
            assert isinstance(v,int)
seen=set()
def walk(x):
    if x in seen:return
    seen.add(x)
    for c in nodes[x]["choices"]:walk(c["next"])
walk(d["entry"])
assert set(nodes)==seen,{"unreachable":list(set(nodes)-seen)}
assert sum(x.startswith("ending_") for x in nodes)>=4
assert {"qing","player","both"}<= {n["hero"] for n in nodes.values()}
print(f"Verified {len(nodes)} connected scenes, {sum(len(n['choices']) for n in nodes.values())} choices, 4 endings.")
