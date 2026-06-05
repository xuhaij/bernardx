const registry = require('../scenarios/registry');

function createScenariosRouter() {
  const router = require('express').Router();

  router.get('/api/scenarios', (req, res) => {
    res.json({ scenarios: registry.all() });
  });

  router.get('/api/scenarios/:scenarioId', (req, res) => {
    const scenario = registry.get(req.params.scenarioId);
    if (!scenario) {
      return res.status(404).json({ error: 'Scenario not found' });
    }

    res.json({
      id: scenario.id,
      level: scenario.level,
      levelName: scenario.levelName,
      title: scenario.title,
      description: scenario.description,
      route: scenario.route,
      verifyUrl: `/verify/${scenario.id}`,
    });
  });

  return router;
}

module.exports = createScenariosRouter;
