const registry = require('../scenarios/registry');

function createAdminRouter() {
  const router = require('express').Router();

  router.post('/api/admin/reset', (req, res) => {
    registry.reset();
    res.json({ success: true, message: 'All scenarios reset' });
  });

  router.post('/api/admin/reset/:scenarioId', (req, res) => {
    const scenario = registry.get(req.params.scenarioId);
    if (!scenario) {
      return res.status(404).json({ error: 'Scenario not found' });
    }

    registry.reset(req.params.scenarioId);
    res.json({ success: true, message: `Scenario ${req.params.scenarioId} reset` });
  });

  return router;
}

module.exports = createAdminRouter;
