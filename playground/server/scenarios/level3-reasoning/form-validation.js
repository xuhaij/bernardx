module.exports = {
  id: 'l3-form-validation',
  level: 3,
  levelName: 'Reasoning',
  title: 'Create Valid Account',
  description: "Create a valid account with username 'testuser' and a compliant password.",
  route: '/scenarios/l3-form-validation',
  initialState: { username: null, password: null, created: false },
  endpoints: {
    'POST /api/l3-form-validation/register': (store, body) => {
      const errors = [];
      if (body.username !== 'testuser') errors.push('Username must be "testuser".');
      if (!body.password || body.password.length < 8) errors.push('Password must be at least 8 characters.');
      if (body.password && !/[A-Z]/.test(body.password)) errors.push('Password must contain an uppercase letter.');
      if (body.password && !/[0-9]/.test(body.password)) errors.push('Password must contain a digit.');
      if (body.password && !/[!@#$%^&*]/.test(body.password)) errors.push('Password must contain a special character (!@#$%^&*).');

      if (errors.length > 0) return { success: false, errors };

      store.set('username', body.username);
      store.set('password', body.password);
      store.set('created', true);
      return { success: true, message: 'Account created!' };
    },
  },
  verify: (store) => {
    const passed = store.get('created') === true && store.get('username') === 'testuser';
    return {
      passed,
      message: passed
        ? 'Account created successfully with valid credentials.'
        : 'No valid account has been created yet.',
      details: { username: store.get('username'), created: store.get('created') },
    };
  },
  template: 'form-validation.html',
};
