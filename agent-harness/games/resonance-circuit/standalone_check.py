"""Current self-contained campaign, served through an in-browser route (not file://)."""
from playwright.sync_api import sync_playwright
from campaign_browser import full_run
if __name__=='__main__':
 with sync_playwright() as p:
  browser=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True)
  for w,h,motion in [(360,800,'reduce'),(390,844,'no-preference'),(1280,900,'reduce')]:full_run(browser,w,h,motion,True)
  browser.close()
