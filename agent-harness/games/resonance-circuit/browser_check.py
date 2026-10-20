"""Compatibility entry point for current campaign browser verification."""
from playwright.sync_api import sync_playwright
from campaign_browser import full_run

def run(cases=None):
 with sync_playwright() as p:
  browser=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True)
  for w,h,motion in (cases or [(360,800,'reduce'),(1280,900,'reduce'),(360,800,'no-preference')]):
   full_run(browser,w,h,motion,False)
  browser.close()
if __name__=='__main__':run()
