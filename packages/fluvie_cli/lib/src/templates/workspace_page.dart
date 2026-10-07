/// Browser shell for the package-owned authoring session. Authored Dart remains
/// the source of truth; this page displays evidence and submits render requests.
const workspacePage = '''
<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>Fluvie workspace</title>
<style>
:root{color-scheme:dark;font:16px system-ui;background:#10141c;color:#edf1fa}
body{max-width:1200px;margin:auto;padding:24px}button,input,select{font:inherit;padding:8px;margin:4px;border:1px solid #607087;border-radius:6px}
button{cursor:pointer}button:disabled{opacity:.5}header,p{line-height:1.5}
.frames{display:flex;gap:16px;flex-wrap:wrap}figure{margin:0;flex:1;min-width:240px}img,video{max-width:100%;max-height:65vh;background:#000}
pre{white-space:pre-wrap;overflow-wrap:anywhere;padding:16px;background:#1b2432;border-radius:8px}
a{color:#96c9ff}figcaption{font-size:14px;padding:8px}summary{cursor:pointer;padding:12px}
</style>
<body><header><h1>Fluvie workspace</h1><p>Inspect the Dart composition, compare frames and export through the same Flutter capture worker.</p></header>
<p id="status" role="status" aria-live="polite">Connecting…</p>
<form id="controls">
<label>Frame <input id="frame" type="number" min="0" value="0" required></label>
<button type="submit">Capture frame</button><button type="button" id="review">Review + repeatability</button>
<label>Aspect <select id="aspect"><option value="">Authored</option><option>reels</option><option>square</option><option>landscape</option><option>portrait45</option></select></label>
<label>Format <select id="format"><option>mp4</option><option>gif</option><option>transparent</option></select></label>
<label>Draft frames <input id="count" type="number" min="1" placeholder="Full video"></label>
<button type="button" id="render">Export</button>
</form>
<div class="frames"><figure><img id="current" alt="Current captured video frame" hidden><figcaption id="currentLabel"></figcaption></figure>
<figure><img id="previous" alt="Previous captured frame for comparison" hidden><figcaption id="previousLabel"></figcaption></figure></div>
<div id="samples" class="frames"></div><video id="video" controls hidden></video><img id="gif" alt="Exported animated GIF" hidden><p><a id="download" hidden>Open exported artifact</a></p>
<section id="quality" hidden aria-labelledby="qualityTitle"><h2 id="qualityTitle">Review findings</h2><p id="qualityScope"></p><ul id="findings"></ul></section>
<details open><summary>Diagnostics and provenance</summary><pre id="result">Capture a frame or run a review.</pre></details>
<details><summary>Dart source</summary><pre id="source"></pre></details>
<script>
const token=location.hash.slice(1);history.replaceState(null,'',location.pathname);
const el=id=>document.getElementById(id);
const artifact=path=>'/artifact?'+new URLSearchParams({path,token});
async function api(path,body){const response=await fetch(path,{method:body?'POST':'GET',headers:{'X-Fluvie-Token':token,'Content-Type':'application/json'},body:body?JSON.stringify(body):undefined});const data=await response.json();if(!response.ok)throw Error(data.error||response.statusText);return data}
function showFrame(id,label,result){el(id).src=artifact(result.filePath);el(id).hidden=false;el(label).textContent='Frame '+result.frame+' · '+result.backend+' · '+result.sourceRevision}
function showQuality(quality,revision) {
  el('quality').hidden=false;
  el('qualityScope').textContent=quality.scope||quality.audio?.scope||'See diagnostics for check scope.';
  el('findings').replaceChildren();
  for(const finding of quality.findings||[]) {
    const item=document.createElement('li'),message=document.createElement('p');
    message.textContent=finding.code+': '+finding.message+(finding.allowed?' (explicitly allowed)':'');
    item.append(message);
    if(finding.remedy){const remedy=document.createElement('p');remedy.textContent=finding.remedy;item.append(remedy)}
    if(Number.isInteger(finding.startFrame)) {
      const jump=document.createElement('button');jump.type='button';
      jump.textContent='Inspect frame '+finding.startFrame;
      jump.onclick=()=>{el('frame').value=finding.startFrame;job('frame',{frameIndex:finding.startFrame,sourceRevision:revision})};
      item.append(jump);
    }
    el('findings').append(item);
  }
  if(quality.audio?.error){const item=document.createElement('li');item.textContent='Audio check unavailable: '+quality.audio.error;el('findings').append(item)}
}
async function job(operation,options={}){const buttons=[...document.querySelectorAll('button')];buttons.forEach(b=>b.disabled=true);el('status').textContent='Rendering '+operation+'…';try{
const input={operation,...options};if(el('aspect').value)input.aspect=el('aspect').value;
if(operation==='frame')input.frameIndex=options.frameIndex??Number(el('frame').value);
if(operation==='review')input.reviewDeterminism=true;
if(operation==='render'){input.format=el('format').value;if(el('count').value)input.frameCount=Number(el('count').value)}
const result=await api('/jobs',input);el('result').textContent=JSON.stringify(result,null,2);
if(result.quality)showQuality(result.quality,result.sourceRevision);
el('status').textContent=result.backend+' · '+result.elapsedMilliseconds+' ms request · '+result.captureMilliseconds+' ms capture · source '+result.sourceRevision;
if(operation==='frame'){showFrame('current','currentLabel',result);if(result.comparison)showFrame('previous','previousLabel',result.comparison)}
if(operation==='review'){el('samples').replaceChildren();for(const sample of result.report.samples||[]){const figure=document.createElement('figure'),img=document.createElement('img'),caption=document.createElement('figcaption');img.src=artifact(sample.filePath);img.alt='Review sample at frame '+sample.frame;caption.textContent='Frame '+sample.frame+' · '+sample.timeSeconds+' seconds';figure.append(img,caption);el('samples').append(figure)}}
if(operation==='render'){const gif=input.format==='gif';el('gif').hidden=!gif;el('video').hidden=gif;el(gif?'gif':'video').src=artifact(result.filePath);el('download').href=artifact(result.filePath);el('download').hidden=false}
el('source').textContent=(await api('/source')).source;
}catch(error){el('status').textContent=error.message}finally{document.querySelectorAll('button').forEach(b=>b.disabled=false)}}
el('controls').onsubmit=event=>{event.preventDefault();job('frame')};el('review').onclick=()=>job('review');el('render').onclick=()=>job('render');
api('/status').then(data=>{el('result').textContent=JSON.stringify(data,null,2);el('status').textContent='Ready · '+data.backend}).catch(error=>el('status').textContent=error.message);
</script></body></html>''';
