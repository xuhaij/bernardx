const express = require('express');
const path = require('path');
const registry = require('./scenarios/registry');
const createPagesRouter = require('./routes/pages');
const createVerifyRouter = require('./routes/verify');
const createScenariosRouter = require('./routes/scenarios');
const createAdminRouter = require('./routes/admin');

function createApp() {
  const app = express();

  app.use(express.json());
  app.use(express.static(path.join(__dirname, '..', 'public')));

  const scenariosDir = path.join(__dirname, 'scenarios');
  registry.autoDiscover(scenariosDir);

  for (const [, scenario] of registry._scenarios) {
    if (!scenario.endpoints) continue;
    for (const [routeDef, handler] of Object.entries(scenario.endpoints)) {
      const [method, route] = routeDef.split(' ');
      const store = registry.getStore(scenario.id);
      const methodLower = method.toLowerCase();
      app[methodLower](route, (req, res) => {
        const result = handler(store, req.body);
        res.json(result);
      });
    }
  }

  app.use(createPagesRouter());
  app.use(createVerifyRouter());
  app.use(createScenariosRouter());
  app.use(createAdminRouter());

  app.get('/', (req, res) => {
    res.redirect('/api/scenarios');
  });

  return app;
}

module.exports = createApp();
