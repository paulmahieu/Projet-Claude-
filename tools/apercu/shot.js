const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch({ args: ['--use-gl=swiftshader','--enable-unsafe-swiftshader'] });
  const p = await b.newPage({ viewport: { width: 1400, height: 800 } });
  p.on('console', m => console.log('console:', m.text()));
  for (const [name, cam] of [['overview','0,60,-120,0,6,5'],['resources','-8,12,-60,-8,5,-40'],['mats','15,9,-55,17,1.5,-40'],['buildings','-10,30,-25,0,6,25'],['core','8,10,-34,0,4,-20']]) {
    await p.goto('http://localhost:8765/index.html?cam=' + cam);
    await p.waitForFunction(() => document.title === 'done', null, { timeout: 30000 });
    await p.screenshot({ path: name + '.png' });
  }
  await b.close();
})();
