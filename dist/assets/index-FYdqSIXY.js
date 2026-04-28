(function(){const t=document.createElement("link").relList;if(t&&t.supports&&t.supports("modulepreload"))return;for(const n of document.querySelectorAll('link[rel="modulepreload"]'))r(n);new MutationObserver(n=>{for(const o of n)if(o.type==="childList")for(const p of o.addedNodes)p.tagName==="LINK"&&p.rel==="modulepreload"&&r(p)}).observe(document,{childList:!0,subtree:!0});function i(n){const o={};return n.integrity&&(o.integrity=n.integrity),n.referrerPolicy&&(o.referrerPolicy=n.referrerPolicy),n.crossOrigin==="use-credentials"?o.credentials="include":n.crossOrigin==="anonymous"?o.credentials="omit":o.credentials="same-origin",o}function r(n){if(n.ep)return;n.ep=!0;const o=i(n);fetch(n.href,o)}})();const m={audio:[],video:[]},I=new Map,y=new Map,w=new Map,c=new Audio;c.preload="metadata";const l=document.createElement("video");l.preload="metadata";l.playsInline=!0;const a={activeView:"home",activeTab:"audio",searchQuery:"",selectedIndex:0,volume:70,playerMode:"paused",repeatMode:"all",shuffleEnabled:!1,dataDirectoryLabel:"Not selected yet",libraryDirectoryLabel:"Not selected yet",actionLog:"Ready."};let g=null,S=null,v=null;const $=xe();h();se();le();E();ce();function h(){if(T(),a.activeView==="player"){$.innerHTML=`
      <div class="fumic-shell player-mode">
        <div class="backdrop player-backdrop" ${te()}></div>
        <button id="nav-home" class="chip back-btn" type="button">Close</button>
        
        <main class="player-center">
          ${ie()}
        </main>

        ${F()}
      </div>
    `;return}$.innerHTML=`
    <div class="fumic-shell" data-active-tab="${a.activeTab}" data-active-view="${a.activeView}">
      <div class="backdrop"></div>

      <header class="chrome-bar">
        <div class="brand-lockup">
          <h1>Fumic</h1>
        </div>

        <nav class="primary-nav" aria-label="Views">
          <button id="nav-home" class="chip ${a.activeView==="home"?"active":""}" type="button">Home</button>
          <button id="nav-settings" class="chip ${a.activeView==="settings"?"active":""}" type="button">Settings</button>
          <button id="nav-info" class="chip ${a.activeView==="info"?"active":""}" type="button">Info</button>
        </nav>

        <div class="search-wrap">
          <input id="global-search" type="text" placeholder="Search media (Ctrl + K)" value="${u(a.searchQuery)}" />
        </div>

        <div class="tab-pills" role="tablist" aria-label="Library Tabs">
          <button id="tab-audio" class="tab-pill ${a.activeTab==="audio"?"active":""}" type="button" role="tab" aria-selected="${a.activeTab==="audio"}">Audio</button>
          <button id="tab-video" class="tab-pill ${a.activeTab==="video"?"active":""}" type="button" role="tab" aria-selected="${a.activeTab==="video"}">Video</button>
        </div>
      </header>

      <main class="view-root">
        ${ae()}
      </main>

      ${F()}
    </div>
  `,be()}function F(){const e=f(),t=e?y.get(e.filePath):null,i=t!=null&&t.pictureBase64?`style="background-image: url('${t.pictureBase64}')"`:"";return`
    <footer class="transport-dock transport-spotify">
      <div class="progress-bar-wrap">
        <span class="progress-time">1:04</span>
        <div class="progress-bar">
          <div class="progress-fill" id="transport-progress" style="width: 0%;">
            <div class="progress-thumb"></div>
          </div>
        </div>
        <span class="progress-time">${u(e?P(e):"0:00")}</span>
      </div>

      <div class="dock-bottom">
        <div class="dock-section now-playing">
          <div class="now-playing-thumb" ${i}></div>
          <div class="now-playing-text">
            <p class="dock-value" id="now-playing-title">${u(j()??"None")}</p>
            <p class="runtime-badge" id="now-playing-meta">${u(G())}</p>
          </div>
        </div>

        <div class="dock-section controls spotify-controls">
          <button id="toggle-shuffle" class="transport-icon ${a.shuffleEnabled?"active":""}" type="button" aria-label="Shuffle" title="Shuffle">🔀</button>
          <button id="transport-prev" class="transport-icon" type="button" aria-label="Previous" title="Previous">⏮</button>
          <button id="toggle-play" class="transport-icon transport-primary" type="button" aria-label="Play or pause" title="Play/Pause">
            ${a.playerMode==="playing"?"⏸":"▶"}
          </button>
          <button id="transport-next" class="transport-icon" type="button" aria-label="Next" title="Next">⏭</button>
          <button id="cycle-repeat" class="transport-icon ${a.repeatMode!=="off"?"active":""}" type="button" aria-label="Repeat" title="Repeat Mode">🔁</button>
        </div>

        <div class="dock-section status">
          <div class="status-grid">
            <span class="volume-icon">🔊</span>
            <div class="volume-bar">
              <div class="volume-fill" style="width: ${a.volume}%;"></div>
            </div>
            <strong id="volume-label">${a.volume}%</strong>
          </div>
          <button id="toggle-player-mode" class="transport-icon fs-btn" type="button" title="Full Screen Player (Ctrl + F)">⛶</button>
        </div>
      </div>
    </footer>
  `}function te(){const e=f();if(e){const t=y.get(e.filePath);if(t!=null&&t.pictureBase64)return`style="background-image: url('${t.pictureBase64}'); opacity: 0.15"`}return""}function ie(){const e=f();if(!e)return'<div class="empty-player"><h2>No media selected</h2></div>';const t=y.get(e.filePath);return`
    <div class="fullscreen-player">
      <div class="fs-art" ${t!=null&&t.pictureBase64?`style="background-image: url('${t.pictureBase64}')"`:""}></div>
      <h1 class="fs-title">${u(N(e))}</h1>
      <h2 class="fs-subtitle">${u(A(e))}</h2>
      <p class="fs-duration">${u(P(e))}</p>
    </div>
  `}function ae(){return a.activeView==="settings"?ne():a.activeView==="info"?oe():re()}function re(){return`
    <div class="home-layout">
      <section class="collection-surface">
        <div class="section-title">
          <h2>${a.activeTab==="audio"?"Audio Collection":"Video Collection"}</h2>
          <p>Real files from your selected library folder. Ctrl + Enter plays highlighted media.</p>
        </div>
        <div id="collection-root" class="collection-root">
          ${z()}
        </div>
      </section>
    </div>
  `}function ne(){return`
    <section class="panel-view">
      <div class="section-title">
        <h2>Settings</h2>
        <p>Configure local paths and refresh the file index. Everything remains offline.</p>
      </div>

      <div class="settings-grid">
        <article class="setting-card">
          <p class="meta-label">Storage</p>
          <p class="meta-value">Current data directory:</p>
          <p class="meta-value strong" id="data-directory">${u(a.dataDirectoryLabel)}</p>
          <button id="pick-data-dir" class="button secondary" type="button">Change Data Directory</button>
        </article>

        <article class="setting-card">
          <p class="meta-label">Media Library</p>
          <p class="meta-value">Current library folder:</p>
          <p class="meta-value strong" id="library-directory">${u(a.libraryDirectoryLabel)}</p>
          <button id="pick-library-dir" class="button secondary" type="button">Change Media Folder</button>
          <button id="manual-refresh" class="button secondary" type="button">Manual Refresh</button>
        </article>

        <article class="setting-card">
          <p class="meta-label">Privacy</p>
          <p class="meta-value">Telemetry is disabled. Fumic does not upload analytics or media data.</p>
        </article>
      </div>
    </section>
  `}function oe(){return`
    <section class="panel-view">
      <div class="section-title">
        <h2>Info</h2>
        <p>Build details, supported formats, and keyboard-first map.</p>
      </div>

      <div class="info-grid">
        <article class="setting-card">
          <p class="meta-label">Runtime</p>
          <p class="meta-value strong">${u($e())}</p>
        </article>

        <article class="setting-card">
          <p class="meta-label">Formats (Current)</p>
          <p class="meta-value">MP4, MP3, Opus, WAV</p>
        </article>

        <article class="setting-card">
          <p class="meta-label">Indexed Files</p>
          <p class="meta-value">Audio: ${m.audio.length} | Video: ${m.video.length}</p>
        </article>
      </div>
    </section>
  `}function z(){const e=k();if(e.length===0)return'<p class="empty-state">No matching files found in the selected media folder.</p>';const t=new Map;for(const i of e){const r=i.item.fileName.charAt(0).toUpperCase(),n=/[A-Z]/.test(r)?r:"#",o=t.get(n);o?o.push(i):t.set(n,[i])}return Array.from(t.entries()).map(([i,r])=>{const n=r.map(o=>{const p=o.index===a.selectedIndex,ee=o.item.id===v;let K=`style="--thumb-hue: ${_(o.item.fileName)};"`;const L=y.get(o.item.filePath);return L!=null&&L.pictureBase64&&(K=`style="background-image: url('${L.pictureBase64}'); background-size: cover; background-position: center; box-shadow: none;"`),`
              <button class="media-card ${p?"selected":""} ${ee?"playing":""}" type="button" data-row-index="${o.index}">
                <span class="media-thumb" ${K}></span>
                <span class="media-body">
                  <span class="media-title">${u(N(o.item))}</span>
                  <span class="media-subtitle">${u(A(o.item))}</span>
                  <span class="media-duration">${u(P(o.item))}</span>
                </span>
              </button>
            `}).join("");return`
          <section class="alpha-group">
            <h3>${i}</h3>
            <div class="media-grid">${n}</div>
          </section>
        `}).join("")}function se(){document.addEventListener("keydown",ye),$.addEventListener("click",e=>{const i=e.target.closest("button");if(!i)return;if(i.id==="nav-home"){b("home");return}if(i.id==="nav-settings"){b("settings");return}if(i.id==="nav-info"){b("info");return}if(i.id==="tab-audio"){D("audio");return}if(i.id==="tab-video"){D("video");return}if(i.id==="toggle-play"){H();return}if(i.id==="transport-prev"){J();return}if(i.id==="transport-next"){Z();return}if(i.id==="cycle-repeat"){de();return}if(i.id==="toggle-shuffle"){ue();return}if(i.id==="pick-data-dir"){fe();return}if(i.id==="pick-library-dir"){pe();return}if(i.id==="manual-refresh"){V("Manual refresh complete.");return}if(i.id==="toggle-player-mode"){b(a.activeView==="player"?"home":"player");return}const r=Number(i.dataset.rowIndex);Number.isNaN(r)||(a.selectedIndex=r,M(),s(`Highlighted ${Q()??"item"}.`))}),$.addEventListener("dblclick",e=>{const i=e.target.closest("button.media-card");if(i){const r=Number(i.dataset.rowIndex);Number.isNaN(r)||(a.selectedIndex=r,q(),M())}}),$.addEventListener("input",e=>{const t=e.target;t.id==="global-search"&&(a.searchQuery=t.value,a.selectedIndex=0,a.activeView!=="home"&&(a.activeView="home",h()),x())})}function le(){c.addEventListener("loadedmetadata",()=>{const e=f();e&&Number.isFinite(c.duration)&&c.duration>0&&(I.set(e.filePath,c.duration),x()),d()}),l.addEventListener("loadedmetadata",()=>{const e=f();e&&Number.isFinite(l.duration)&&l.duration>0&&(I.set(e.filePath,l.duration),x()),d()}),c.addEventListener("play",()=>{a.playerMode="playing",d()}),l.addEventListener("play",()=>{a.playerMode="playing",d()}),c.addEventListener("pause",()=>{a.playerMode="paused",d()}),l.addEventListener("pause",()=>{a.playerMode="paused",d()}),c.addEventListener("ended",()=>{U()}),l.addEventListener("ended",()=>{U()})}async function ce(){S=window.appApi.onMainMessage(e=>{s(e)}),g=await window.appApi.getBootstrap(),a.dataDirectoryLabel=g.dataDirectory,a.libraryDirectoryLabel=g.libraryDirectory,await V("Library indexed.")}function b(e){a.activeView!==e&&(a.activeView=e,h(),s(`Switched to ${e} view.`))}function D(e){a.activeTab===e&&a.activeView==="home"||(a.activeTab=e,a.activeView="home",a.selectedIndex=0,h(),s(`Switched to ${e} tab.`))}async function V(e){s("Scanning media library...");try{const t=await window.appApi.scanLibrary();m.audio=t.items.filter(i=>i.kind==="audio"),m.video=t.items.filter(i=>i.kind==="video"),a.libraryDirectoryLabel=t.rootDirectory,T(),h(),d(),s(e)}catch{s("Library scan failed. Please check folder permissions and try again.")}}async function H(){const e=X();if(e&&v){e.paused?await e.play():e.pause();return}await q()}function de(){const e=["all","one","off"],t=e.indexOf(a.repeatMode);a.repeatMode=e[(t+1)%e.length],d(),s(`Repeat mode is now ${a.repeatMode}.`)}function ue(){a.shuffleEnabled=!a.shuffleEnabled,d(),s(`Shuffle is now ${a.shuffleEnabled?"on":"off"}.`)}async function fe(){const e=await window.appApi.pickDataDirectory();if(!e){s("Data directory selection canceled.");return}a.dataDirectoryLabel=e;const t=document.querySelector("#data-directory");t&&(t.textContent=e),s("Data directory updated.")}async function pe(){const e=await window.appApi.pickLibraryDirectory();if(!e){s("Media folder selection canceled.");return}a.libraryDirectoryLabel=e,await V("Media folder updated and indexed.")}function x(){T();const e=document.querySelector("#collection-root");e&&(e.innerHTML=z()),M()}function M(){const e=document.querySelector("#collection-root");if(e){const t=e.querySelectorAll(".media-card");for(const i of Array.from(t))parseInt(i.dataset.rowIndex??"-1",10)===a.selectedIndex?(i.classList.add("selected"),i.scrollIntoView({block:"nearest",behavior:"smooth"})):i.classList.remove("selected")}d()}function d(){const e=document.querySelector("#mode-label"),t=document.querySelector("#volume-label"),i=document.querySelector("#toggle-play"),r=document.querySelector("#cycle-repeat"),n=document.querySelector("#toggle-shuffle"),o=document.querySelector("#now-playing-title"),p=document.querySelector("#now-playing-meta");e&&(e.textContent=a.playerMode),t&&(t.textContent=`${a.volume}%`),i&&(i.textContent=a.playerMode==="playing"?"Pause":"Play"),r&&(r.textContent=`Repeat: ${a.repeatMode}`,r.classList.toggle("active",a.repeatMode!=="off")),n&&n.classList.toggle("active",a.shuffleEnabled),o&&(o.textContent=j()??"None"),p&&(p.textContent=G())}function s(e){a.actionLog=e;const t=document.querySelector("#action-log");t&&(t.textContent=e)}function ye(e){const t=e.target,i=(t==null?void 0:t.tagName)==="INPUT"||(t==null?void 0:t.tagName)==="TEXTAREA";if(e.ctrlKey&&e.key.toLowerCase()==="h"){e.preventDefault(),b("home");return}if(e.ctrlKey&&e.key.toLowerCase()==="i"){e.preventDefault(),b("info");return}if(e.ctrlKey&&e.key.toLowerCase()==="s"){e.preventDefault(),b("settings");return}if(e.ctrlKey&&e.key.toLowerCase()==="a"){e.preventDefault(),D("audio");return}if(e.ctrlKey&&e.key.toLowerCase()==="v"){e.preventDefault(),D("video");return}if(e.ctrlKey&&e.key.toLowerCase()==="k"){e.preventDefault(),a.activeView!=="home"&&(a.activeView="home",h());const r=document.querySelector("#global-search");r==null||r.focus(),r==null||r.select(),s("Focused search input.");return}if(e.ctrlKey&&e.key.toLowerCase()==="f"){e.preventDefault(),a.activeView!=="player"?b("player"):b("home");return}if(e.ctrlKey&&e.key.toLowerCase()==="b"){e.preventDefault(),s(`Added ${Q()??"item"} to Liked Music.`);return}if(e.ctrlKey&&e.key.toLowerCase()==="p"){e.preventDefault(),s("Ctrl + P captured for user playlist target flow.");return}if(e.ctrlKey&&e.key==="ArrowUp"){e.preventDefault(),a.volume=Math.min(100,a.volume+5),E(),d(),s(`Volume set to ${a.volume}%.`);return}if(e.ctrlKey&&e.key==="ArrowDown"){e.preventDefault(),a.volume=Math.max(0,a.volume-5),E(),d(),s(`Volume set to ${a.volume}%.`);return}if(e.ctrlKey&&e.key==="ArrowRight"){e.preventDefault(),Z();return}if(e.ctrlKey&&e.key==="ArrowLeft"){e.preventDefault(),J();return}if(e.ctrlKey&&e.key==="Enter"){e.preventDefault(),q();return}if(!i){if(e.code==="Space"){e.preventDefault(),H();return}if(e.key==="ArrowUp"){e.preventDefault(),O(-1);return}if(e.key==="ArrowDown"){e.preventDefault(),O(1);return}if(e.key==="ArrowRight"||e.key==="ArrowLeft"){e.preventDefault();const r=e.shiftKey?10:5;he(e.key==="ArrowRight"?r:-r)}}}function O(e){a.activeView!=="home"&&(a.activeView="home",h());const t=k();if(t.length===0){a.selectedIndex=0,M();return}const i=a.selectedIndex+e;a.selectedIndex=Math.max(0,Math.min(t.length-1,i)),M()}function k(){const e=m[a.activeTab],t=a.searchQuery.trim().toLowerCase();return t?e.map((i,r)=>({item:i,index:r})).filter(i=>i.item.fileName.toLowerCase().includes(t)):e.map((i,r)=>({item:i,index:r}))}function T(){const e=k();if(e.length===0){a.selectedIndex=0;return}a.selectedIndex>e.length-1&&(a.selectedIndex=e.length-1),a.selectedIndex<0&&(a.selectedIndex=0)}function C(){var t;return((t=k()[a.selectedIndex])==null?void 0:t.item)??null}function f(){return v?m.audio.find(e=>e.id===v)??m.video.find(e=>e.id===v)??null:null}function Q(){var e;return((e=C())==null?void 0:e.fileName)??null}function j(){const e=f();return e?N(e):null}function G(){const e=f();return e?`${A(e)} - ${P(e)}`:"Select media and press Play."}function N(e){const t=y.get(e.filePath);return t!=null&&t.title?t.title:e.fileName}function A(e){const t=y.get(e.filePath);return t!=null&&t.artist?t.artist:e.kind.toUpperCase()}function me(e,t){const i=y.get(t.filePath);i!=null&&i.pictureBase64?(e.style.backgroundImage=`url("${i.pictureBase64}")`,e.style.backgroundSize="cover",e.style.backgroundPosition="center",e.style.boxShadow="none"):(e.style.backgroundImage="",e.style.setProperty("--thumb-hue",String(_(t.fileName))))}function P(e){const t=I.get(e.filePath);return t?we(t):"Loading duration..."}function be(){const e=k().slice(0,40);for(const t of e)!y.has(t.item.filePath)&&!w.has(t.item.filePath)&&W(t.item).then(()=>{const i=document.querySelector(`[data-row-index="${t.index}"]`);if(i){const r=i.querySelector(".media-duration");r&&(r.textContent=P(t.item));const n=i.querySelector(".media-title");n&&(n.textContent=N(t.item));const o=i.querySelector(".media-subtitle");o&&(o.textContent=A(t.item));const p=i.querySelector(".media-thumb");p&&me(p,t.item)}})}async function W(e){if(y.has(e.filePath))return y.get(e.filePath)??null;const t=w.get(e.filePath);if(t)return t;const i=window.appApi.getMediaMetadata(e.filePath).then(n=>(w.delete(e.filePath),n&&(n.duration&&n.duration>0&&I.set(e.filePath,n.duration),y.set(e.filePath,n)),v===e.id&&d(),n)).catch(()=>(w.delete(e.filePath),null));w.set(e.filePath,i);const r=await i;return x(),r}async function q(){const e=C();if(!e){s("No media item selected.");return}await R(e)}async function R(e){const t=ve(e.filePath);c.pause(),l.pause(),e.kind==="audio"?(l.removeAttribute("src"),l.load(),c.src!==t&&(c.src=t),await c.play()):(c.removeAttribute("src"),c.load(),l.src!==t&&(l.src=t),await l.play()),v=e.id,a.playerMode="playing",await W(e),d(),x(),s(`Playing ${e.fileName}.`)}function X(){const e=f();return e?e.kind==="audio"?c:l:null}function he(e){const t=X();if(!t||!Number.isFinite(t.duration))return;const i=Math.max(0,Math.min(t.duration,t.currentTime+e));t.currentTime=i;const r=e>=0?"forward":"backward";s(`Seeked ${r} ${Math.abs(e)}s.`)}async function Z(){const e=f()??C(),t=(e==null?void 0:e.kind)??a.activeTab,i=m[t];if(i.length===0){s("No media available in this tab.");return}const r=e?i.findIndex(o=>o.id===e.id):-1,n=Y(i.length,r);await B(t,n)}async function J(){const e=f()??C(),t=(e==null?void 0:e.kind)??a.activeTab,i=m[t];if(i.length===0){s("No media available in this tab.");return}const r=e?i.findIndex(o=>o.id===e.id):-1,n=ge(i.length,r);await B(t,n)}async function B(e,t){const r=m[e][t];r&&(a.activeTab=e,a.activeView="home",a.searchQuery="",a.selectedIndex=t,h(),await R(r))}async function U(){if(a.repeatMode==="one"){const n=f();n&&await R(n);return}const e=f();if(!e){a.playerMode="paused",d();return}const t=m[e.kind],i=t.findIndex(n=>n.id===e.id);if(i<0){a.playerMode="paused",d();return}if(i===t.length-1&&a.repeatMode==="off"&&!a.shuffleEnabled){a.playerMode="paused",d();return}const r=Y(t.length,i);await B(e.kind,r)}function Y(e,t){if(a.shuffleEnabled){if(e===1)return 0;let i=Math.floor(Math.random()*e);for(;i===t;)i=Math.floor(Math.random()*e);return i}return t<0||t>=e-1?0:t+1}function ge(e,t){if(a.shuffleEnabled){if(e===1)return 0;let i=Math.floor(Math.random()*e);for(;i===t;)i=Math.floor(Math.random()*e);return i}return t<=0?e-1:t-1}function E(){const e=a.volume/100;c.volume=e,l.volume=e}function ve(e){return`file:///${e.replace(/\\/g,"/").split("/").map(r=>encodeURIComponent(r)).join("/").replace(/%3A/i,":")}`}function we(e){const t=Math.max(0,Math.floor(e)),i=Math.floor(t/3600),r=Math.floor(t%3600/60),n=t%60;return i>0?`${i}:${String(r).padStart(2,"0")}:${String(n).padStart(2,"0")}`:`${r}:${String(n).padStart(2,"0")}`}function _(e){let t=0;for(let i=0;i<e.length;i+=1)t=(t<<5)-t+e.charCodeAt(i),t|=0;return Math.abs(t)%360}function u(e){return e.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&#39;")}function $e(){return g?`${g.appName} ${g.appVersion} on ${g.platform}`:"Loading runtime info..."}function xe(){const e=document.querySelector("#app");if(!e)throw new Error("Application root #app was not found in DOM.");return e}window.addEventListener("beforeunload",()=>{S==null||S(),c.pause(),l.pause()});
