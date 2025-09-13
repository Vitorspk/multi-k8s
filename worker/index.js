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
    await redisClient.hSet('values', message, fib(parseInt(message)).toString());
  });
}

function fib(index) {
  if (index < 2) return 1;
  return fib(index - 1) + fib(index - 2);
}

connectRedis().catch(console.error);
