module.exports = {
  id: 'l3-conditional-action',
  level: 3,
  levelName: 'Reasoning',
  title: 'Cancel Processing Order',
  description: 'Cancel the order that is still being processed.',
  route: '/scenarios/l3-conditional-action',
  initialState: {
    orders: [
      { id: 'ORD-001', status: 'Shipped', name: 'Wireless Mouse' },
      { id: 'ORD-002', status: 'Processing', name: 'USB-C Hub' },
      { id: 'ORD-003', status: 'Delivered', name: 'Desk Lamp' },
    ],
  },
  endpoints: {
    'POST /api/l3-conditional-action/cancel': (store, body) => {
      const orders = store.get('orders').map((o) =>
        o.id === body.orderId ? { ...o, status: 'Cancelled' } : { ...o }
      );
      store.set('orders', orders);
      const cancelled = orders.find((o) => o.id === body.orderId);
      return { success: true, order: cancelled };
    },
  },
  verify: (store) => {
    const orders = store.get('orders');
    const target = orders.find((o) => o.id === 'ORD-002');
    const passed = target && target.status === 'Cancelled';
    return {
      passed,
      message: passed
        ? 'Correct! ORD-002 (Processing) has been cancelled.'
        : 'The processing order (ORD-002) has not been cancelled.',
      details: { orders },
    };
  },
  template: 'conditional-action.html',
};
