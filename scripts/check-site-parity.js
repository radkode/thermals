async page => {
  const assert = (condition, message) => { if (!condition) throw new Error(message); };
  const url = page.url();
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.setViewportSize({width: 1440, height: 1000});
  await page.emulateMedia({reducedMotion: 'reduce'});
  await page.clock.install();
  await page.goto(url);
  await page.evaluate(() => document.fonts.ready);
  await page.locator('#track').scrollIntoViewIfNeeded();
  await page.waitForTimeout(200);
  await page.locator('#hold').click();

  const states = [];
  for (let step = 0; step < 41; step++) {
    const state = await page.evaluate(() => {
      const strips = el => [...el.querySelectorAll(':scope > .strip')].map(strip => ({
        text: [...strip.querySelectorAll('.face')].map(face => face.textContent || ' ').join('').trim(),
        ink: strip.style.getPropertyValue('--ink'),
      }));
      const board = id => document.getElementById(`board-${id}`);
      const hero = id => strips(board(id).querySelector('.hero-stat'))[0];
      const stats = id => [...board(id).querySelectorAll('.stat')].map(el => strips(el)[0]);
      const rows = id => [...board(id).querySelectorAll('.departures .cols')].slice(1).map(strips);
      const clipped = [...document.querySelectorAll('.board .cols, .board .meter-head')].some(el => {
        const box = el.getBoundingClientRect();
        return [...el.children].some(child => child.getBoundingClientRect().right > box.right + 1);
      });
      const aligned = [...document.querySelectorAll('.departures')].every(panel => {
        const [head, row] = panel.querySelectorAll('.cols');
        return [2, 3].every(index => Math.abs(head.children[index].getBoundingClientRect().left - row.children[index].getBoundingClientRect().left) < 1);
      });
      return {
        heat: hero('heat'), cpu: hero('cpu'), ram: hero('ram'),
        thermal: stats('heat')[2], cpuThermal: stats('cpu')[1], cpuDie: stats('cpu')[0], memory: stats('ram')[1],
        sensors: rows('heat'), processes: rows('cpu'), apps: rows('ram'),
        cores: [...board('cpu').querySelectorAll('.platforms-pair .cols')].map(el => Number(strips(el)[1].text)),
        menu: document.getElementById('menubar-reading').textContent,
        summaries: ['heat', 'cpu', 'ram'].map(id => document.getElementById(`${id}-summary`).textContent),
        labels: [...document.querySelectorAll('.meter-head')].map(el => el.textContent),
        cpuOrder: [...board('cpu').children].map(el => el.textContent),
        capacity: board('ram').querySelector('.board-note').textContent,
        clipped, aligned,
      };
    });
    assert(!state.clipped, `Clipped board columns at step ${step}`);
    assert(state.aligned, 'Numeric and status headers must align with their rows');
    assert(state.cpuOrder.findIndex(s => s.startsWith('TOP PROCESSES')) < state.cpuOrder.findIndex(s => s.startsWith('PERFORMANCE')), 'Attribution must precede core inventory');
    assert(state.labels.filter(s => s.includes('LAST 3 MIN · NOW →MIN/MAX')).length === 3, 'All histories name observed MIN/MAX and newest-right direction');
    assert(state.summaries.every(s => /Sample:/.test(s) && /Rising|Falling|Steady/.test(s) && /scale adapts/.test(s)), 'Accessible sample summaries must include trend and scale');
    assert(/of 18\.0 GB used/.test(state.capacity), 'Installed RAM capacity must remain visible');
    for (const [name, value, status] of state.sensors) {
      if (!name.text.startsWith('CPU DIE')) {
        assert(status.text === '' && value.ink === '#A7AAAF', `${name.text} must stay unbanded and neutral`);
      }
    }
    const measured = state.processes.slice(0, 5);
    for (const [, value, status] of [...measured, ...state.apps]) {
      assert(['LOW', 'MOD', 'HIGH'].includes(status.text), 'Utilization must never claim HOT/BURN');
      if (Number(value.text) > 100) assert(status.text === 'HIGH' && value.ink === 'rgb(255,227,163)', 'Multi-core process must use the capped utilization palette');
    }
    const estimate = state.processes[5];
    assert(estimate[0].text === 'UNMEASURED EST' && estimate[1].ink === '#A7AAAF' && estimate[2].text === '', 'Estimated remainder must be named, neutral and unbanded');
    const total = parseInt(state.cpu.text);
    assert(Math.abs(state.cores.reduce((sum, value) => sum + value, 0) / 8 - total) <= 1, 'Eight sample cores must agree with whole-system load');
    const accounted = measured.reduce((sum, row) => sum + Number(row[1].text), 0) + Number(estimate[1].text);
    assert(accounted <= (total + 0.5) * 8 + 3 && accounted >= (total - 0.5) * 7, 'Process sample must respect eight-core capacity and leave room for unlisted work');
    assert(state.thermal.text === state.cpuThermal.text && state.heat.ink === state.cpuDie.ink, 'Thermal warnings must agree across boards');
    if (['SERIOUS', 'CRITICAL'].includes(state.thermal.text)) assert(state.menu.startsWith('! '), 'Menu warning must remain explicit');
    if (state.thermal.text === 'CRITICAL' && parseInt(state.heat.text) < 90) assert(state.heat.ink === 'rgb(255,131,85)', 'Critical OS pressure must raise lower-temperature ink');
    if (state.memory.text === 'NORMAL' && parseInt(state.ram.text) >= 90) {
      const rgb = state.ram.ink.match(/\d+/g).map(Number);
      assert(rgb[1] >= 227, 'High RAM under normal pressure must stay below warning colors');
    }
    if (state.memory.text === 'CRITICAL') assert(state.ram.ink === 'rgb(255,131,85)' && state.memory.ink === '#FF7073', 'Critical memory pressure must use the shipped warning tokens');
    states.push(state);
    await page.clock.runFor(1500);
  }
  assert(states.some(s => s.memory.text === 'NORMAL' && parseInt(s.ram.text) >= 90), 'Exercise high RAM with normal OS pressure');
  assert(states.some(s => s.thermal.text === 'CRITICAL' && parseInt(s.heat.text) < 75), 'Exercise low-temperature critical OS pressure');
  assert(states.some(s => s.memory.text === 'WARN') && states.some(s => s.memory.text === 'CRITICAL'), 'Exercise both memory warning states');
  assert(errors.length === 0, `Browser errors: ${errors.join(', ')}`);
  return {samples: states.length, semanticParity: 'passed', coherentCPU: 'passed', mixedPressureStates: 'passed', accessibleDescriptions: 'passed', unclippedColumns: 'passed', browserErrors: errors};
}
