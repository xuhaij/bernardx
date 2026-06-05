var playground = {
  submit: function(endpoint, data, callback) {
    fetch(endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    })
    .then(function(resp) { return resp.json(); })
    .then(function(result) {
      if (callback) callback(result);
    })
    .catch(function(err) {
      playground.showResult('Request failed: ' + err.message, false);
    });
  },

  showResult: function(message, success) {
    var el = document.getElementById('result');
    if (!el) return;
    el.textContent = message;
    el.className = 'result ' + (success ? 'success' : 'error');
    el.style.display = 'block';
  },
};
