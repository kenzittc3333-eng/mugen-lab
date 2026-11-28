(()=>{
const synth=window.speechSynthesis,button=document.getElementById('speak'),stop=document.getElementById('speechStop'),select=document.getElementById('voiceChoice'),status=document.getElementById('speechStatus');
let token=0;
const editor=document.getElementById('speechText');
const readingKey=i=>'mugen-kokoro-reading-v1:'+i;
const savedStatus=document.createElement('p');
savedStatus.setAttribute('aria-live','polite');
editor.insertAdjacentElement('afterend',savedStatus);
const saveButton=document.createElement('button');
saveButton.type='button';saveButton.textContent='💾 読み方を保存';
savedStatus.insertAdjacentElement('afterend',saveButton);
const saveNote=document.createElement('p');
saveNote.textContent='修正は自動保存されます。同じ端末・同じブラウザで次回も使えます。';
saveButton.insertAdjacentElement('afterend',saveNote);
function loadReading(){try{const saved=localStorage.getItem(readingKey(index));return saved===null?(speechTexts[index]||''):saved;}catch(e){return speechTexts[index]||'';}}
function saveReading(){try{localStorage.setItem(readingKey(index),editor.value);savedStatus.textContent='✓ このカードの読み方を保存しました。';return true;}catch(e){savedStatus.textContent='保存できませんでした。ブラウザの保存設定・空き容量を確認してください。';return false;}}
function restoreReading(){editor.value=loadReading();savedStatus.textContent='';}
editor.addEventListener('input',()=>{cancel();saveReading();});
saveButton.onclick=saveReading;
restoreReading();
function voices(){if(!synth)return;const old=select.value;const list=synth.getVoices().filter(v=>/^ja([-_]|$)/i.test(v.lang));list.sort((a,b)=>score(b)-score(a));select.replaceChildren();for(const v of list){const o=document.createElement('option');o.value=v.voiceURI;o.textContent=v.name;select.append(o)}if(list.some(v=>v.voiceURI===old))select.value=old;if(!list.length){const o=document.createElement('option');o.value='';o.textContent='端末の日本語音声';select.append(o)}}
function score(v){return /female|女性|kyoko|haruka|nanami|ayumi|mizuki|shiori|sayaka/i.test(v.name)&&!/otoya|\bmale\b|男性/i.test(v.name)?10:/Google.*日本語|Microsoft.*Nanami/i.test(v.name)?8:0}
function cancel(){token++;if(synth)synth.cancel();button.disabled=false;button.textContent='🔊 読み上げ';}
if(!synth||!window.SpeechSynthesisUtterance){button.disabled=true;status.textContent='このブラウザでは読み上げに対応していません。';return;}
voices();synth.addEventListener('voiceschanged',voices);select.addEventListener('pointerdown',voices);
button.onclick=()=>{cancel();const text=document.getElementById('speechText').value;if(!text||!text.trim()){status.textContent='このカードの文章を読み取れませんでした。';return;}const current=token;const utterance=new SpeechSynthesisUtterance(text);utterance.lang='ja-JP';utterance.rate=.9;utterance.pitch=1.08;const voice=synth.getVoices().find(v=>v.voiceURI===select.value);if(voice)utterance.voice=voice;utterance.onstart=()=>{if(current!==token)return;button.textContent='🔊 読み上げ中';status.textContent='読み上げ中です。';};utterance.onend=()=>{if(current!==token)return;button.textContent='🔊 もう一度聞く';status.textContent='読み上げが終わりました。';};utterance.onerror=e=>{if(current!==token)return;button.textContent='🔊 読み上げ';status.textContent=e.error==='not-allowed'?'もう一度「読み上げ」を押してください。':'読み上げできませんでした。端末の日本語音声設定を確認してください。';};status.textContent='音声を準備しています。';synth.speak(utterance);};
stop.onclick=()=>{cancel();status.textContent='停止しました。';};select.onchange=()=>{cancel();status.textContent='声を変更しました。';};
const originalShow=show;show=function(){cancel();originalShow();restoreReading();status.textContent='女性の声を優先します。声は下の欄で選べます。';};restoreReading();window.addEventListener('pagehide',cancel);
})();
