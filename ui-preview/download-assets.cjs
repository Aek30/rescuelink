// Run once to refresh vendored assets. The app itself makes no external requests.
const fs = require('node:fs');
const path = require('node:path');
const mapping = {shield:'shield-plus',plus:'plus',home:'house',radar:'radar',chat:'messages-square',alert:'triangle-alert',queue:'list-todo',user:'user-round',people:'users-round',check:'check',double:'check-check',arrow:'chevron-right',back:'chevron-left',down:'chevron-down',bell:'bell',wifi:'wifi',offline:'wifi-off',bluetooth:'bluetooth',location:'map-pin',clock:'clock-3',refresh:'refresh-cw',cloud:'cloud-check',network:'network',sun:'sun',moon:'moon',send:'send',clip:'paperclip',info:'info',settings:'settings-2',heart:'heart',eye:'eye',download:'download',logout:'log-out',phone:'phone',x:'x',image:'image',leaf:'leaf'};
(async () => {
  const result = {};
  const assets = path.join(__dirname,'assets');
  const entries = await Promise.all(Object.entries(mapping).map(async ([key,name]) => {
    const response = await fetch(`https://raw.githubusercontent.com/lucide-icons/lucide/main/icons/${name}.svg`);
    if (!response.ok) throw new Error(`${name}: ${response.status}`);
    const svg = await response.text();
    return [key,svg.slice(svg.indexOf('>')+1,svg.lastIndexOf('</svg>')).trim()];
  }));
  for (const [key,value] of entries) result[key]=value;
  const license = await fetch('https://raw.githubusercontent.com/lucide-icons/lucide/main/LICENSE');
  if (!license.ok) throw new Error('Cannot fetch icon license');
  fs.writeFileSync(path.join(assets,'LICENSE-Lucide.txt'),await license.text());
  fs.writeFileSync(path.join(assets,'lucide-icons.js'),'// Vendored Lucide SVG fragments; license: LICENSE-Lucide.txt\nwindow.RESCUE_ICONS = '+JSON.stringify(result)+';\n');
  console.log(`Vendored ${entries.length} Lucide icons and license.`);
})().catch(error=>{console.error(error);process.exitCode=1;});
