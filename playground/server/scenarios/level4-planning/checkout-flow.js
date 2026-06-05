module.exports = {
  id: 'l4-checkout-flow',
  level: 4,
  levelName: 'Multi-step Planning',
  title: 'Complete Checkout Flow',
  description: 'Add a wireless mouse to cart, fill in shipping details, and complete the order.',
  route: '/scenarios/l4-checkout-flow',
  initialState: {
    currentStep: 1,
    cartItem: null,
    cartPrice: null,
    shippingName: null,
    shippingAddress: null,
    shippingCity: null,
    orderPlaced: false,
  },
  endpoints: {
    'POST /api/l4-checkout-flow/add-to-cart': (store, body) => {
      store.set('cartItem', body.productName || null);
      store.set('cartPrice', body.price || null);
      store.set('currentStep', 2);
      return { success: true, message: `${body.productName} added to cart!`, step: 2 };
    },
    'POST /api/l4-checkout-flow/shipping': (store, body) => {
      if (!body.name || !body.address || !body.city) {
        return { success: false, errors: ['All shipping fields are required.'] };
      }
      store.set('shippingName', body.name);
      store.set('shippingAddress', body.address);
      store.set('shippingCity', body.city);
      store.set('currentStep', 3);
      return { success: true, message: 'Shipping info saved!', step: 3 };
    },
    'POST /api/l4-checkout-flow/place-order': (store) => {
      if (!store.get('cartItem') || !store.get('shippingName')) {
        return { success: false, errors: ['Cart or shipping info missing.'] };
      }
      store.set('orderPlaced', true);
      store.set('currentStep', 4);
      return { success: true, message: 'Order placed successfully!', step: 4 };
    },
  },
  verify: (store) => {
    const passed = store.get('orderPlaced') === true
      && store.get('cartItem') === 'Wireless Mouse'
      && store.get('shippingName') !== null
      && store.get('shippingCity') !== null;
    return {
      passed,
      message: passed
        ? 'Checkout flow completed successfully!'
        : 'The checkout has not been completed yet.',
      details: {
        cartItem: store.get('cartItem'),
        shippingName: store.get('shippingName'),
        shippingCity: store.get('shippingCity'),
        orderPlaced: store.get('orderPlaced'),
      },
    };
  },
  template: 'checkout-flow.html',
};
