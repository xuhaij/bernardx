module.exports = {
  id: 'l1-type-search',
  level: 1,
  levelName: 'Direct Action',
  title: 'Search for a Product',
  description: "Type 'wireless headphones' into the search box and click Search.",
  route: '/scenarios/l1-type-search',
  initialState: { lastSearch: null, searchCount: 0 },
  endpoints: {
    'POST /api/l1-type-search/search': (store, body) => {
      store.set('lastSearch', body.query || null);
      store.set('searchCount', store.get('searchCount') + 1);
      return {
        success: true,
        message: 'Search completed!',
        results: ['Wireless Headphones Pro', 'Bluetooth Earbuds', 'Noise-Cancelling Headphones'],
      };
    },
  },
  verify: (store) => {
    const lastSearch = store.get('lastSearch');
    const passed = lastSearch === 'wireless headphones';
    return {
      passed,
      message: passed
        ? 'Correct search query submitted.'
        : lastSearch
          ? `Wrong search query: "${lastSearch}". Expected "wireless headphones".`
          : 'No search has been performed yet.',
      details: {
        lastSearch: store.get('lastSearch'),
        searchCount: store.get('searchCount'),
      },
    };
  },
  template: 'type-search.html',
};
