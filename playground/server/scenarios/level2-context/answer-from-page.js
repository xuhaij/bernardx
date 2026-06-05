module.exports = {
  id: 'l2-answer-from-page',
  level: 2,
  levelName: 'Context Understanding',
  title: 'Extract Data from Dashboard',
  description: 'What is the temperature in Tokyo? Type it into the answer field and submit.',
  route: '/scenarios/l2-answer-from-page',
  initialState: { answer: null },
  endpoints: {
    'POST /api/l2-answer-from-page/submit': (store, body) => {
      store.set('answer', body.answer || null);
      return { success: true, message: 'Answer submitted!' };
    },
  },
  verify: (store) => {
    const answer = store.get('answer');
    const numAnswer = answer ? parseFloat(answer) : null;
    const passed = numAnswer !== null && numAnswer >= 21 && numAnswer <= 23;
    return {
      passed,
      message: passed
        ? `Correct! Tokyo temperature is 22°C. Your answer: "${answer}"`
        : answer
          ? `"${answer}" is incorrect. Check the Tokyo temperature on the dashboard.`
          : 'No answer has been submitted.',
      details: { answer: store.get('answer') },
    };
  },
  template: 'answer-from-page.html',
};
