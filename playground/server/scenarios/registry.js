const path = require('path');
const fs = require('fs');
const MemoryStore = require('../store/memory-store');

class ScenarioRegistry {
  constructor() {
    this._scenarios = new Map();
    this._stores = new Map();
  }

  register(scenario) {
    if (!scenario.id) throw new Error('Scenario must have an id');

    const store = new MemoryStore(scenario.initialState || {});
    this._scenarios.set(scenario.id, scenario);
    this._stores.set(scenario.id, store);
  }

  get(id) {
    return this._scenarios.get(id);
  }

  getStore(id) {
    return this._stores.get(id);
  }

  all() {
    return Array.from(this._scenarios.values()).map((s) => ({
      id: s.id,
      level: s.level,
      levelName: s.levelName,
      title: s.title,
      description: s.description,
      route: s.route,
    }));
  }

  reset(id) {
    if (id) {
      const store = this._stores.get(id);
      if (store) store.reset();
      return;
    }
    for (const [, store] of this._stores) {
      store.reset();
    }
  }

  autoDiscover(scenariosDir) {
    const entries = fs.readdirSync(scenariosDir, { withFileTypes: true });
    for (const entry of entries) {
      if (!entry.isDirectory()) continue;
      const dir = path.join(scenariosDir, entry.name);
      const files = fs.readdirSync(dir).filter((f) => f.endsWith('.js'));
      for (const file of files) {
        const scenario = require(path.join(dir, file));
        this.register(scenario);
      }
    }
  }
}

module.exports = new ScenarioRegistry();
