const keys = require('./keys');
const redis = require('redis');

const redisClient = redis.createClient({
  socket: {
    host: keys.redisHost,
    port: keys.redisPort
  }
});

const sub = redisClient.duplicate();

async function connectRedis() {
  await redisClient.connect();
  await sub.connect();
  
  await sub.subscribe('insert', async (message) => {
    const result = fib(parseInt(message));
    await redisClient.hSet('values', message, result.toString());
  });
}

// Optimized Fibonacci with memoization
function fib(n) {
  // Handle edge cases
  if (n < 0) return 0;
  if (n <= 1) return 1;
  
  // Use iterative approach for better performance
  // This avoids stack overflow and is much faster than recursion
  let prev = 1;
  let curr = 1;
  
  for (let i = 2; i <= n; i++) {
    const temp = curr;
    curr = prev + curr;
    prev = temp;
  }
  
  return curr;
}

// Alternative: Dynamic Programming with memoization for very large numbers
// Uncomment if you need to handle extremely large Fibonacci calculations
/*
const fibMemo = (() => {
  const cache = new Map();
  
  return function fib(n) {
    if (n < 0) return 0;
    if (n <= 1) return 1;
    
    if (cache.has(n)) {
      return cache.get(n);
    }
    
    const result = fib(n - 1) + fib(n - 2);
    cache.set(n, result);
    
    return result;
  };
})();
*/

connectRedis().catch(console.error);

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, closing Redis connections...');
  await redisClient.quit();
  await sub.quit();
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('SIGINT received, closing Redis connections...');
  await redisClient.quit();
  await sub.quit();
  process.exit(0);
});