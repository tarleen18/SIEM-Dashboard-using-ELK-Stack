Capture a Kibana screenshot (quick)

Steps:

1. Install Node (16+) and npm.
2. From the project root, run:

```powershell
npm init -y
npm install puppeteer
node capture-screenshot.js "http://localhost:5601/app/management/kibana/dataViews" artifacts/screenshots/kibana_data_views.png
```

3. The screenshot will be saved to `artifacts/screenshots/kibana_data_views.png`.

If Puppeteer downloads Chromium slowly, you can set `PUPPETEER_SKIP_DOWNLOAD=1` and use an existing Chrome by modifying `puppeteer.launch({executablePath: 'C:\Program Files\Google\Chrome\Application\chrome.exe'})` in `capture-screenshot.js`.
