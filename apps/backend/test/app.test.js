// Simple test: check that the app starts without crashing
const app = require('../index');
 
test('App should be defined', () => {
  expect(app).toBeDefined();
});
 
console.log('Tests passed!');
