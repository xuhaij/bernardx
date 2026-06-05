module.exports = {
  id: 'l1-toggle-checkbox',
  level: 1,
  levelName: 'Direct Action',
  title: 'Enable Auto-save',
  description: "Check the 'Auto-save' checkbox.",
  route: '/scenarios/l1-toggle-checkbox',
  initialState: { autosave: false },
  endpoints: {
    'POST /api/l1-toggle-checkbox/toggle': (store, body) => {
      store.set('autosave', body.checked === true);
      return {
        success: true,
        autosave: store.get('autosave'),
        message: store.get('autosave') ? 'Auto-save enabled.' : 'Auto-save disabled.',
      };
    },
  },
  verify: (store) => {
    const passed = store.get('autosave') === true;
    return {
      passed,
      message: passed
        ? 'Auto-save has been enabled.'
        : 'Auto-save is not enabled yet.',
      details: { autosave: store.get('autosave') },
    };
  },
  template: 'toggle-checkbox.html',
};
