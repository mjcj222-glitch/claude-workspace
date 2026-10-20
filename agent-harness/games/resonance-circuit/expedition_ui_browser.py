from campaign_browser import setup,ROOT
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
 b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True);page=b.new_page();setup(page,False)
 assert page.locator('#expeditionNew').count()==1,'탐험 시작 선택이 아직 없음'
 page.locator('#expeditionNew').click();assert page.locator('#journey').is_visible()
 assert page.locator('[data-room]').count()==10
 b.close()
