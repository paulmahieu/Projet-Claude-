const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch({ args: ['--use-gl=swiftshader','--enable-unsafe-swiftshader'] });
  const p = await b.newPage({ viewport: { width: 1400, height: 800 }, deviceScaleFactor: 2 });
  for (const [name, cam] of [['hub_portails','0,9,-6,0,7,22'],['hub_vue','-30,26,-34,0,2,4'],['autel','54,8,-10,40,5,-10']]) {
    await p.goto('http://localhost:8765/index.html?cam=' + cam);
    await p.waitForFunction(() => document.title === 'done', null, { timeout: 60000 });
    await p.screenshot({ path: name + '.png' });
  }
  await b.close();
})();
