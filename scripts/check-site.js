async page => {
  const url = page.url();
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  const assert = (condition, message) => { if (!condition) throw new Error(message); };
  const selected = () => page.locator('.tab[aria-pressed="true"]').getAttribute('data-board');
  const waitForSelection = name => page.waitForFunction(name =>
    document.querySelector('.tab[aria-pressed="true"]')?.dataset.board === name, name);
  const results = [];

  await page.emulateMedia({reducedMotion: 'no-preference'});
  for (const width of [320, 390, 768, 820, 1024, 1180, 1200, 1440]) {
    await page.setViewportSize({width, height: 900});
    await page.goto(url);
    await page.evaluate(() => document.fonts.ready);
    assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), `Page overflows at ${width}px`);
    const tabsVisible = await page.locator('#tabs').isVisible();
    assert(tabsVisible === (width < 1196), `Picker visibility at ${width}px`);
    if (tabsVisible) {
      for (const name of ['cpu', 'ram', 'heat', 'ram', 'cpu']) {
        await page.locator(`.tab[data-board="${name}"]`).click();
        await page.waitForTimeout(750);
        assert(await selected() === name, `${width}px: clicking ${name} selected ${await selected()}`);
        const visible = await page.locator(`#platform-${name}`).evaluate(el => {
          const rect = el.getBoundingClientRect();
          return rect.left >= -1 && rect.right <= innerWidth + 1;
        });
        assert(visible, `${width}px: ${name} is not fully in view`);
      }
    }
    results.push({width, picker: tabsVisible ? 'passed' : 'hidden with all boards visible'});
  }

  await page.setViewportSize({width: 390, height: 900});
  await page.goto(url);
  await page.locator('.tab[data-board="ram"]').focus();
  await page.keyboard.press('Enter');
  await page.waitForTimeout(750);
  assert(await selected() === 'ram', 'Keyboard RAM selection');
  await page.locator('.tab[data-board="cpu"]').focus();
  await page.keyboard.press('Space');
  await page.waitForTimeout(750);
  assert(await selected() === 'cpu', 'Keyboard CPU selection');
  await page.evaluate(() => {
    for (const name of ['ram', 'heat', 'cpu', 'ram']) document.querySelector(`.tab[data-board="${name}"]`).click();
  });
  await page.waitForTimeout(750);
  assert(await selected() === 'ram', 'Rapid selection must end at RAM');
  await page.locator('#track').evaluate(el => el.scrollTo({left: 0, behavior: 'instant'}));
  await waitForSelection('heat');
  await page.locator('#track').evaluate(el => el.scrollTo({left: el.scrollWidth, behavior: 'instant'}));
  await waitForSelection('ram');
  results.push({keyboard: 'passed', rapidClicks: 'passed', scrollSelection: 'passed'});

  await page.locator('.tab[data-board="heat"]').click();
  await page.waitForTimeout(750);
  await page.locator('#track').scrollIntoViewIfNeeded();
  await page.waitForTimeout(900);
  assert(await selected() === 'heat', 'Runtime check must start on HEAT');
  await page.evaluate(() => {
    window.siteMutations = {};
    document.querySelectorAll('.board').forEach(board => {
      siteMutations[board.id] = 0;
      new MutationObserver(records => siteMutations[board.id] += records.length)
        .observe(board, {subtree: true, childList: true, attributes: true, characterData: true});
    });
  });
  await page.waitForTimeout(3200);
  const mutations = await page.evaluate(() => siteMutations);
  assert(mutations['board-heat'] > 0, 'Visible board must update');
  assert(mutations['board-cpu'] === 0 && mutations['board-ram'] === 0, 'Offscreen boards must not render');
  await page.locator('#hold').click();
  await page.waitForTimeout(900);
  const held = await page.locator('#track').innerHTML();
  await page.waitForTimeout(1700);
  assert(await page.locator('#track').innerHTML() === held, 'HOLD must stop updates');
  await page.locator('#hold').click();
  await page.waitForFunction(previous => document.getElementById('track').innerHTML !== previous, held);
  results.push({offscreenMutations: mutations, holdRun: 'passed'});

  await page.emulateMedia({reducedMotion: 'reduce'});
  await page.goto(url);
  assert(await page.locator('#hold').getAttribute('aria-pressed') === 'true', 'Reduce Motion must start held');
  await page.locator('.tab[data-board="ram"]').click();
  await page.waitForTimeout(200);
  assert(await selected() === 'ram', 'Reduced-motion picker');
  assert(await page.locator('.falling, .rising').count() === 0, 'Reduce Motion must not animate flaps');
  assert(await page.locator('.meter i').count() === 720, 'Three complete history meters');
  await page.context().grantPermissions(['clipboard-read', 'clipboard-write']);
  for (const id of ['brew', 'brew-2']) {
    await page.locator(`[data-copy="${id}"]`).click();
    assert(await page.evaluate(() => navigator.clipboard.readText()) === 'brew install --cask radkode/thermals/thermals', 'Install command copied exactly');
  }
  assert(await page.locator('a.download').getAttribute('href') === 'https://github.com/radkode/homebrew-thermals/releases/latest', 'Release destination preserved');
  const fonts = await page.evaluate(() => performance.getEntriesByType('resource').filter(r => /\.(woff2|ttf)$/.test(r.name)).map(r => r.name));
  assert(fonts.length === 2 && fonts.every(name => name.endsWith('.woff2')), 'Load each WOFF2 font once');
  assert(errors.length === 0, `Browser errors: ${errors.join(', ')}`);
  results.push({reducedMotion: 'passed', copyButtons: 'passed', download: 'passed', fonts: 'passed', browserErrors: errors});
  return results;
}
