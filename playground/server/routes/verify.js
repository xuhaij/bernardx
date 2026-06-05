const registry = require('../scenarios/registry');

function createVerifyRouter() {
  const router = require('express').Router();

  router.get('/verify/:scenarioId', (req, res) => {
    const scenario = registry.get(req.params.scenarioId);
    if (!scenario) {
      return res.status(404).json({ error: 'Scenario not found' });
    }

    const store = registry.getStore(req.params.scenarioId);
    const result = scenario.verify(store);

    res.json({
      scenarioId: req.params.scenarioId,
      ...result,
      timestamp: new Date().toISOString(),
    });
  });

  return router;
}

module.exports = createVerifyRouter;
