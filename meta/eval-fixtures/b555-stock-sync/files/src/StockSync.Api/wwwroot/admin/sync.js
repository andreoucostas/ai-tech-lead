const button = document.getElementById('sync-now');
const statusText = document.getElementById('sync-status');

button.addEventListener('click', async () => {
  button.disabled = true;
  statusText.textContent = 'Starting sync...';
  try {
    const response = await fetch('/api/stock-sync', { method: 'POST', credentials: 'same-origin' });
    if (!response.ok) {
      statusText.textContent = `Start failed: ${response.status}`;
      return;
    }
    const { runId } = await response.json();
    let run;
    do {
      await new Promise((resolve) => setTimeout(resolve, 1000));
      const poll = await fetch(`/api/stock-sync/${runId}`, { credentials: 'same-origin' });
      if (!poll.ok) {
        statusText.textContent = `Status check failed: ${poll.status}`;
        return;
      }
      run = await poll.json();
      statusText.textContent = `${run.status} - applied ${run.appliedCount}`;
    } while (run.status === 'Running');
  } finally {
    button.disabled = false;
  }
});
