module.exports = {
  id: 'l5-form-errors',
  level: 5,
  levelName: 'Exception Handling',
  title: 'Fix Form Errors',
  description: "Fill out the contact form. The server will reject the first submission — read the errors, fix them, and resubmit until it's accepted.",
  route: '/scenarios/l5-form-errors',
  initialState: {
    attempts: 0,
    name: null,
    email: null,
    message: null,
    submitted: false,
  },
  endpoints: {
    'POST /api/l5-form-errors/submit': (store, body) => {
      const attempts = store.get('attempts') + 1;
      store.set('attempts', attempts);

      if (attempts === 1) {
        return {
          success: false,
          errors: [
            'Name must be at least 2 characters.',
            'Email must be a valid email address.',
            'Message must be at least 20 characters.',
          ],
          hint: 'Please fix these errors and try again.',
        };
      }

      const errors = [];
      if (!body.name || body.name.length < 2) errors.push('Name must be at least 2 characters.');
      if (!body.email || !body.email.includes('@') || !body.email.includes('.')) {
        errors.push('Email must be a valid email address.');
      }
      if (!body.message || body.message.length < 20) {
        errors.push('Message must be at least 20 characters.');
      }
      if (errors.length > 0) return { success: false, errors };

      store.set('name', body.name);
      store.set('email', body.email);
      store.set('message', body.message);
      store.set('submitted', true);
      return { success: true, message: 'Contact form submitted successfully!' };
    },
  },
  verify: (store) => {
    const passed = store.get('submitted') === true && store.get('attempts') >= 2;
    return {
      passed,
      message: passed
        ? `Form submitted after ${store.get('attempts')} attempts!`
        : 'The form has not been successfully submitted yet.',
      details: {
        attempts: store.get('attempts'),
        name: store.get('name'),
        email: store.get('email'),
        submitted: store.get('submitted'),
      },
    };
  },
  template: 'form-errors.html',
};
