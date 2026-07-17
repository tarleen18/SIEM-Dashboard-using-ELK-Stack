const puppeteer = require('puppeteer');
const url = process.argv[2] || 'http://localhost:5601/app/management/kibana/dataViews';
const out = process.argv[3] || 'artifacts/screenshots/kibana_data_views.png';
(async () => {
  try {
    const browser = await puppeteer.launch({ args: ['--no-sandbox', '--disable-setuid-sandbox'] });
    const page = await browser.newPage();
    await page.setViewport({ width: 1366, height: 768 });
    await page.goto(url, { waitUntil: 'networkidle2', timeout: 60000 });
    await new Promise(resolve => setTimeout(resolve, 1000));
    await page.screenshot({ path: out, fullPage: true });
    await browser.close();
    console.log('Saved screenshot to', out);
  } catch (err) {
    console.error('Failed to capture screenshot:', err);
    process.exit(1);
  }
})();
