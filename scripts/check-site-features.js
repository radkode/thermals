async page => {
  const assert = (condition, message) => { if (!condition) throw new Error(message); };
  const url = page.url(), errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.setViewportSize({width: 1440, height: 1000});
  await page.emulateMedia({reducedMotion: 'reduce'});
  await page.clock.install();
  await page.goto(url);
  await page.evaluate(() => document.fonts.ready);
  await page.locator('#work-session').scrollIntoViewIfNeeded();
  assert((await page.locator('#preview-note').innerText()).includes('Included in Thermals 0.5.0'), 'Identify the features in the published release');
  assert(await page.getByRole('button', {name: 'Start a sample work session', exact: true}).isVisible(), 'Session actions must be exposed to accessibility');
  assert(await page.locator('footer a[href="https://github.com/radkode/thermals"]').isVisible() && await page.locator('.facts a[href="https://github.com/radkode/thermals/security/advisories/new"]').isVisible(), 'Link the public source and private security reporting');
  assert(!await page.locator('#last-session').isVisible(), 'No completed receipt before an explicit session');
  const alignment = await page.locator('#board-heat .stats').evaluate(el => {
    const stats = [...el.querySelectorAll('.stat')].map(s => s.getBoundingClientRect());
    return Math.abs(stats[0].right - stats[2].right) < 1 && Math.abs(stats[1].right - stats[3].right) < 1 && stats[2].top > stats[0].bottom;
  });
  assert(alignment, 'GPU belongs directly below POWER in the two-column header');

  const start = page.getByRole('button', {name: 'Start a sample work session', exact: true});
  const stop = page.getByRole('button', {name: 'Stop the sample work session', exact: true});
  await start.focus();
  await page.keyboard.press('Enter');
  assert(await stop.evaluate(el => el === document.activeElement), 'Starting moves focus to STOP');
  await page.clock.runFor(4500);
  assert(await page.locator('#work-session > .board-line > .label').nth(1).textContent() === '0s', 'HOLD freezes the sample recording clock');
  assert(await page.locator('.falling, .rising').count() === 0, 'Reduced-motion session actions must not animate flaps');
  await page.locator('#hold').click();
  await page.locator('#heat-episodes summary').click();

  const states = [];
  for (let step = 0; step <= 40; step++) {
    states.push(await page.evaluate(() => {
      const text = el => [...el.querySelectorAll('.face')].map(face => face.textContent || ' ').join('').trim();
      const heat = document.getElementById('board-heat'), stats = [...heat.querySelectorAll('.stat .strip')].map(text);
      const arrow = document.querySelector('.menu-trend'), arrowStyle = getComputedStyle(arrow);
      return {
        temperature: parseInt(text(heat.querySelector('.hero-stat .strip'))), watts: stats[0] === '--' ? null : parseInt(stats[0]),
        pressure: stats[3], peak: parseInt(text(document.querySelector('#peak-today > .strip:last-child'))),
        peakTime: text(document.querySelector('#peak-today > .strip')), menu: document.getElementById('menubar-reading').textContent,
        trend: arrowStyle.display === 'none' ? null : arrowStyle.transform.startsWith('matrix(-1,') ? 'down' : 'up',
        arrowColor: arrowStyle.stroke, temperatureColor: getComputedStyle(document.querySelector('.menu-temperature')).color,
        episode: document.querySelector('#heat-episodes summary .label').textContent,
        source: document.getElementById('power-context').textContent,
      };
    }));
    if (step < 40) await page.clock.runFor(1500);
  }
  let pressureSeconds = 0, powerSeconds = 0, estimatedEnergy = 0;
  const pressured = s => ['SERIOUS', 'CRITICAL'].includes(s.pressure);
  for (let i = 1; i < states.length; i++) {
    const before = states[i - 1], after = states[i];
    if (pressured(before) && pressured(after)) pressureSeconds += 6;
    if (before.watts != null && after.watts != null) {
      powerSeconds += 6;
      estimatedEnergy += (before.watts + after.watts) / 2 * 6 / 3600;
    }
    assert(after.peak >= before.peak && after.peak >= after.temperature, 'Daily peak cannot fall or trail the current reading');
    if (after.peak === before.peak) assert(after.peakTime === before.peakTime, 'Same displayed peak keeps its first time');
    if (i >= 10) {
      const values = states.slice(i - 10, i + 1).map(s => s.temperature);
      const slope = values.reduce((sum, value, index) => sum + (index - 5) * value, 0) / 11;
      if (slope > 6) assert(after.trend === 'up', 'A clearly rising last minute must show an up arrow');
      if (slope < -6) assert(after.trend === 'down', 'A clearly falling last minute must show a down arrow');
      if (Math.abs(slope) < 4) assert(after.trend === null, 'A clearly steady last minute must have no arrow');
    }
    assert(after.arrowColor === after.temperatureColor, 'The drawn arrow inherits the native temperature ink');
  }
  assert(states.some(s => s.trend === 'up') && states.some(s => s.trend === 'down'), 'Exercise both drawn menu trend directions');
  assert(states.some(s => s.episode === 'HEAT NOW') && states.some(s => s.episode === 'LAST HEAT'), 'Exercise episode start and sustained recovery');
  assert(states.some(s => s.source.includes('CHARGING')) && states.some(s => s.source.includes('PLUGGED IN')), 'Show charging and plugged-in context');
  assert(states.filter(s => s.source.includes('ON BATTERY')).every(s => !s.source.includes('ADAPTER')), 'No adapter capability while on battery');
  assert(powerSeconds < 240 && pressureSeconds > 0, 'Recording must include missing power and pressure intervals');

  await page.locator('#hold').click();
  await stop.focus();
  await page.keyboard.press('Space');
  assert(await page.locator('#last-session').getAttribute('open') !== null, 'STOP reveals the receipt');
  assert(await page.locator('#last-session summary').evaluate(el => el === document.activeElement), 'STOP moves focus to the completed receipt');
  const receipt = await page.locator('.session-receipt').innerText();
  const duration = seconds => seconds < 60 ? `${seconds}s` : `${Math.floor(seconds / 60)}m ${seconds % 60}s`;
  assert(receipt.includes('SAMPLE SESSION RECEIPT') && receipt.includes('not readings from your Mac'), 'Copied receipts identify synthetic data');
  assert(receipt.includes('Duration: 4m 0s') && receipt.includes('Observed: 4m 0s'), 'Recording uses sample time, not four-times-faster wall time');
  assert(receipt.includes(`Serious/critical pressure: ${duration(pressureSeconds)} observed`), 'Pressure covers only pressured endpoints');
  assert(receipt.includes(`over ${duration(powerSeconds)} of sample power`) && receipt.includes('Missing power intervals excluded'), 'Power coverage must exclude unavailable intervals');
  assert(receipt.includes(`Peak CPU: ${Math.max(...states.map(s => s.temperature))}°C`), 'Receipt peak has explicit units');
  const energy = Number(receipt.match(/energy: ([\d.]+) Wh/)[1]);
  assert(Math.abs(energy - estimatedEnergy) <= powerSeconds / 7200 + 0.0051, 'Watt-hours match the displayed watt range and elapsed sample time');
  assert(receipt.includes('not one build') && !/XCODE|SWIFT|SAFARI|WINDOWSERVER/.test(receipt), 'Do not attribute system energy or copy process names');
  await page.context().grantPermissions(['clipboard-read', 'clipboard-write']);
  await page.getByRole('button', {name: 'Copy the sample session receipt', exact: true}).click();
  assert(await page.evaluate(() => navigator.clipboard.readText()) === receipt, 'COPY writes the exact sample receipt');
  await page.evaluate(() => Object.defineProperty(navigator.clipboard, 'writeText', {configurable: true, value: async () => { throw new Error('Clipboard denied for test'); }}));
  await page.getByRole('button', {name: 'Copy the sample session receipt', exact: true}).click();
  assert((await page.locator('#work-session [role="status"]').innerText()).includes('Copy failed'), 'Clipboard failures explain recovery');
  assert(await page.evaluate(() => getSelection().toString()) === receipt, 'Failed copy selects the full receipt for manual copying');

  await page.setViewportSize({width: 320, height: 900});
  await page.locator('#all-sensors summary').click();
  await page.waitForTimeout(200);
  assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), 'Expanded details must not overflow a 320px page');
  const sizing = await page.locator('#board-heat').evaluate(board => {
    const box = board.getBoundingClientRect(), wrapper = board.parentElement.getBoundingClientRect();
    return {fits: Math.abs(box.height - wrapper.height) < 1,
      targets: [...board.querySelectorAll('button, summary')].filter(el => el.getBoundingClientRect().height > 0).every(el => el.getBoundingClientRect().height >= 43.9),
      textFits: [...board.querySelectorAll('.board-note')].filter(el => el.clientWidth > 0).every(el => el.scrollWidth <= el.clientWidth)};
  });
  assert(sizing.fits && sizing.targets && sizing.textFits, 'Expanded mobile board fits its wrapper, text and touch targets');
  await page.getByRole('button', {name: 'Inspect sample CPU activity', exact: true}).click();
  await page.waitForTimeout(200);
  assert(await page.locator('.tab[aria-pressed="true"]').getAttribute('data-board') === 'cpu', 'HEAT inspection opens CPU');
  assert(await page.locator('#platform-cpu').evaluate(el => el === document.activeElement), 'CPU inspection transfers keyboard focus');
  await page.reload();
  assert(!await page.locator('#last-session').isVisible(), 'Reload clears sample receipts');
  assert(errors.length === 0, `Browser errors: ${errors.join(', ')}`);
  return {states: states.length, header: 'passed', peak: 'passed', trend: 'passed', episodes: 'passed', sessions: 'passed', copyAndRecovery: 'passed', mobile: 'passed', browserErrors: errors};
}
