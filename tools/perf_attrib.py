import csv,sys,collections,statistics as st
rows=list(csv.DictReader(open(sys.argv[1])))[5:]
thr=float(sys.argv[2])
def pct(a,p): a=sorted(a); return a[max(0,int(len(a)*p/100)-1)]
ft=[float(r['frame_us'])/1000 for r in rows]
print('frames',len(rows),'secs',round(sum(ft)/1000,1),'mean',round(st.mean(ft),2),'p50',round(pct(ft,50),2),'p99',round(pct(ft,99),2),'max',round(max(ft),1),'fps avg',round(len(ft)/(sum(ft)/1000)))
sp=[(i,r) for i,r in enumerate(rows) if float(r['frame_us'])/1000>thr]
print('spikes >',thr,'ms:',len(sp))
c=collections.Counter(); ca=collections.Counter()
for i,r in sp:
    # attribute: nodes added this frame or previous frame
    a=(r['added']+'|'+rows[i-1]['added']).strip('|')
    keys=sorted(set(k.split('*')[0] for k in a.split('|') if k))
    for k in keys: c[k]+=1
for r in rows:
    for k in set(x.split('*')[0] for x in (r['added'] or '').split('|') if x): ca[k]+=1
print('added-near-spike (count, spikes/frames-with-it):')
for k,v in c.most_common(25): print(f'  {k:40s} {v:4d} / {ca[k]:5d} = {v/ca[k]:.0%}')
base=len(sp)/len(rows); print('base spike rate',f'{base:.2%}')
# frames with no additions
print('spikes with nothing added (this or prev frame):',sum(1 for i,r in sp if not (r['added'] or rows[i-1]['added'])))
for i,r in sp[:40]:
    print(r['frame'],r['scene'],r['px'],round(float(r['frame_us'])/1000,1),'ts',r['ts'],'|',r['added'][:120],'<<',rows[i-1]['added'][:80])
