const path = require('path');
const fs = require('fs');
const registry = require('../scenarios/registry');

function createPagesRouter() {
  const router = require('express').Router();

  router.get('/scenarios/:scenarioId', (req, res) => {
    const scenario = registry.get(req.params.scenarioId);
    if (!scenario) {
      return res.status(404).send('Scenario not found');
    }

    const scenariosDir = path.join(__dirname, '..', 'scenarios');
    const entries = fs.readdirSync(scenariosDir, { withFileTypes: true });
    let htmlPath = null;

    for (const entry of entries) {
      if (!entry.isDirectory()) continue;
      const candidate = path.join(scenariosDir, entry.name, scenario.template);
      if (fs.existsSync(candidate)) {
        htmlPath = candidate;
        break;
      }
    }

    if (!htmlPath || !fs.existsSync(htmlPath)) {
      return res.status(500).send('Template not found');
    }

    res.type('html').sendFile(htmlPath);
  });

  return router;
}

module.exports = createPagesRouter;
