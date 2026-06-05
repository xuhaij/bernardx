module.exports = {
  id: 'l2-navigate-dropdown',
  level: 2,
  levelName: 'Context Understanding',
  title: 'Navigate to Headphones Category',
  description: 'Navigate to the Headphones category page using the navigation menu.',
  route: '/scenarios/l2-navigate-dropdown',
  initialState: { currentCategory: 'home', navigatedCategories: [] },
  endpoints: {
    'POST /api/l2-navigate-dropdown/navigate': (store, body) => {
      const current = store.get('navigatedCategories') || [];
      store.set('currentCategory', body.category || 'home');
      store.set('navigatedCategories', [...current, body.category || 'home']);
      return { success: true, category: body.category };
    },
  },
  verify: (store) => {
    const nav = store.get('navigatedCategories') || [];
    const passed = nav.includes('headphones');
    return {
      passed,
      message: passed
        ? 'Successfully navigated to Headphones category.'
        : 'You have not navigated to the Headphones category yet.',
      details: { currentCategory: store.get('currentCategory'), navigatedCategories: nav },
    };
  },
  template: 'navigate-dropdown.html',
};
