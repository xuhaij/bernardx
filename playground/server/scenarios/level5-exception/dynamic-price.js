module.exports = {
  id: 'l5-dynamic-price',
  level: 5,
  levelName: 'Exception Handling',
  title: 'Buy at the Right Price',
  description: 'The product price changes every few seconds. Wait until the price drops below $30, then click Buy.',
  route: '/scenarios/l5-dynamic-price',
  initialState: {
    purchased: false,
    purchasePrice: null,
  },
  endpoints: {
    'POST /api/l5-dynamic-price/buy': (store, body) => {
      const price = parseFloat(body.price);
      if (isNaN(price)) return { success: false, errors: ['Invalid price.'] };
      if (price >= 30) {
        return { success: false, errors: [`Price $${price.toFixed(2)} is too high! Wait for it to drop below $30.`] };
      }
      store.set('purchased', true);
      store.set('purchasePrice', price);
      return { success: true, message: `Purchased at $${price.toFixed(2)}! Great deal!` };
    },
  },
  verify: (store) => {
    const passed = store.get('purchased') === true && store.get('purchasePrice') < 30;
    return {
      passed,
      message: passed
        ? `Bought at $${store.get('purchasePrice')?.toFixed(2)} — under the $30 threshold!`
        : 'The product has not been purchased at the right price yet.',
      details: {
        purchased: store.get('purchased'),
        purchasePrice: store.get('purchasePrice'),
      },
    };
  },
  template: 'dynamic-price.html',
};
