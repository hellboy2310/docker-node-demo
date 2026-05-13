exports.handler = async (event) => {
  const rawPath = event.rawPath || '/';
  const path = rawPath.endsWith('/health') ? '/health' : '/';
  if (path === '/health') {
    return {
      statusCode: 200,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ status: 'ok' }),
    };
  }

  if (path === '/') {
    return {
      statusCode: 200,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: 'Hello from Bhavesh!' }),
    };
  }

  return {
    statusCode: 404,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ error: 'Not found' }),
  };
};
