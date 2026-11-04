const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch({ args: ['--use-gl=swiftshader','--enable-unsafe-swiftshader'] });
  const p = await b.newPage({ viewport: { width: 1400, height: 800 }, deviceScaleFactor: 2 });
  for (const [name, cam] of [['chateau_vue','-95,85,-110,0,0,5'],['chateau_cour','0,7,-14,0,12,40'],['chateau_porte','0,9,-105,0,9,-50']]) {
    await p.goto('http://localhost:8765/index.html?cam=' + cam);
    await p.waitForFunction(() => document.title === 'done', null, { timeout: 60000 });
    await p.screenshot({ path: name + '.png' });
  }
  await b.close();
})();
