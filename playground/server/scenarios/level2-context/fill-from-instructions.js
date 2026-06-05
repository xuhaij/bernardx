module.exports = {
  id: 'l2-fill-from-instructions',
  level: 2,
  levelName: 'Context Understanding',
  title: 'Fill Form from Instructions',
  description: 'Read the instructions on the page and fill out the form accordingly.',
  route: '/scenarios/l2-fill-from-instructions',
  initialState: { fullName: null, email: null, department: null },
  endpoints: {
    'POST /api/l2-fill-from-instructions/submit': (store, body) => {
      store.set('fullName', body.fullName || null);
      store.set('email', body.email || null);
      store.set('department', body.department || null);
      return { success: true, message: 'Form submitted!' };
    },
  },
  verify: (store) => {
    const expected = { fullName: 'Jane Smith', email: 'jane.smith@acme.com', department: 'Engineering' };
    const actual = {
      fullName: store.get('fullName'),
      email: store.get('email'),
      department: store.get('department'),
    };
    const passed = actual.fullName === expected.fullName
      && actual.email === expected.email
      && actual.department === expected.department;
    return {
      passed,
      message: passed
        ? 'All fields match the instructions.'
        : 'Some fields do not match the instructions.',
      details: { expected, actual },
    };
  },
  template: 'fill-from-instructions.html',
};
