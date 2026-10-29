"""Independent read-only coverage, config, grouping and range verification."""
import argparse
import collections
import itertools
import json
from pathlib import Path
checks=0;failures=[]
def require(ok,label):
    global checks
    checks+=1
    if not ok:failures.append(label)
def canon(x):return json.dumps(x,sort_keys=True,separators=(',',':'))
# Read-only verifier: a malformed input is a failure, never a fresh report.
parser = argparse.ArgumentParser(description="Verify the bounded starter-recipe audit")
parser.add_argument("report", type=Path)
args = parser.parse_args()
d = json.loads(args.report.read_text(encoding="utf-8"))
# The server challenge adds save metadata in v19 without changing this catalog.
# Accept both independently compared versions; future schema changes need review.
require((d['format'],d['algorithm_version'],d['starter_rank'])==(1,1,1)
        and type(d['game_schema_version']) is int
        and d['game_schema_version'] in (18,19),'supported catalog audit metadata')
require(not d['failures'],'producer zero failures')
contexts=d['contexts'];ctxids=[c['id'] for c in contexts]
require(ctxids==['clear_light','rich_hearty','spicy_soft'],'three fixed context identities')
metrics=['profile_'+x for x in ['rich','salt','aroma','chew','spice']]+['compat_total','score_dohyun','score_hayoung','score_maru','average_score','unit_cost','prep_seconds']
taste=metrics[:-2]
require(d['metrics']['numeric_order']==metrics and d['metrics']['taste_signature_order']==taste,'numeric fields/order explicit, recipe text excluded')
# Build the expected formula sets independently with Python's combinations
# and product, rather than trusting the writer's enumeration totals.
rawids=['pork_bone','chicken_bone','kelp','onion','ginger','garlic'];base=set(rawids[:3]);broth=set()
for n in range(1,4):
    for ids in itertools.combinations_with_replacement(sorted(rawids),n):
        if base.intersection(ids):
            for method in ['standard','gentle']:broth.add(canon({'ingredients':list(ids),'method':method}))
noodle={canon(dict(zip(['flour','water','cut','method'],v))) for v in itertools.product(['wheat','strong'],['clear','alkaline'],['thin','medium','thick'],['standard','moist'])}
require(len(broth)==128 and len(noodle)==24,'independent exact mathematical starter sets')
for family,expected in [('broth',broth),('noodle',noodle)]:
    rows=d[family]['candidates'];analysis=d[family]['analysis'];seen={canon(c['formula']) for c in rows}
    require(seen==expected and len(rows)==len(expected),'complete unique canonical formula coverage '+family)
    require(analysis['candidate_count']==len(rows),'analysis candidate count '+family)
    for index,c in enumerate(rows):
        require(c['index']==index and set(c['configs'])==set(ctxids) and set(c['outcomes'])==set(ctxids),'complete indexed three-context row '+family)
        for ctx in contexts:
            key=ctx['id'];cfg=c['configs'][key];values=c['outcomes'][key]
            require(cfg['price']==9000 and all(cfg[k]==ctx[k] for k in ['tare','oil','toppings','cook']),'fixed context unchanged '+family)
            require(cfg['broth_recipe']==(c['formula'] if family=='broth' else ctx['companion_broth']),'actual varied/fixed broth '+family)
            require(cfg['noodle_recipe']==(c['formula'] if family=='noodle' else ctx['companion_noodle']),'actual varied/fixed noodle '+family)
            require(set(values)==set(metrics) and all(type(x) is int for x in values.values()),'all fields strictly numeric '+family)
            require(all(0<=values['profile_'+axis]<=10 for axis in ['rich','salt','aroma','chew','spice']),'bounded profile '+family)
            require(all(0<=values['score_'+p]<=100 for p in ['dohyun','hayoung','maru']),'bounded actual customer points '+family)
    # Rebuild each partition from every actual metric in all three contexts.
    for kind,names in [('full',metrics),('taste',taste)]:
        groups={}
        for c in rows:
            signature=tuple(c['outcomes'][ctx][m] for ctx in ctxids for m in names)
            if signature not in groups:groups[signature]=[]
            group=list(groups).index(signature);groups[signature].append(c['index'])
            require(c['signature_group'][kind]==group,'actual numeric group index '+family+'/'+kind)
        collisions=[(i,members) for i,members in enumerate(groups.values()) if len(members)>1]
        observed=analysis[kind];hist=dict(collections.Counter(str(len(v)) for v in groups.values()))
        expected_counts={'unique_signatures':len(groups),'collision_groups':len(collisions),'candidates_in_collision_groups':sum(len(m) for _,m in collisions),'largest_group_size':max(map(len,groups.values())),'group_size_histogram':hist,'signature_metric_order':names}
        require(all(observed[k]==v for k,v in expected_counts.items()),'independent whole numeric partition '+family+'/'+kind)
        collisions.sort(key=lambda pair:(-len(pair[1]),pair[0]))
        examples=[{'group':i,'size':len(m),'member_indexes':m[:8],'members':[rows[j]['key'] for j in m[:8]],'members_omitted':max(0,len(m)-8)} for i,m in collisions[:10]]
        require(observed['representative_collisions']==examples,'exact collision examples '+family+'/'+kind)
    for ctx in ctxids:
        for m in metrics:
            v=[r['outcomes'][ctx][m] for r in rows]
            require(analysis['metric_ranges'][ctx][m]=={'min':min(v),'max':max(v),'distinct_values':len(set(v))},'independent metric range '+family+'/'+ctx+'/'+m)
print('INDEPENDENT DIVERSITY checks=%d failures=%d'%(checks,len(failures)))
for failure in failures:print('FAIL:',failure)
raise SystemExit(1 if failures else 0)
