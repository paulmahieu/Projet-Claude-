const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch({ args: ['--use-gl=swiftshader','--enable-unsafe-swiftshader'] });
  const p = await b.newPage({ viewport: { width: 1400, height: 800 }, deviceScaleFactor: 2 });
  for (const [name, cam] of [['detail_scierie','-12,12,8,-28,5,25']]) {
    await p.goto('http://localhost:8765/index.html?cam=' + cam);
    await p.waitForFunction(() => document.title === 'done', null, { timeout: 60000 });
    await p.screenshot({ path: name + '.png' });
  }
  await b.close();
})();
