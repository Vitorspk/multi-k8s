// react-router v7 references TextEncoder/TextDecoder at import time, which the
// CRA (jsdom) test environment does not provide by default. Polyfill them from
// Node's util so the test suite can load react-router under react-scripts/jest.
import { TextEncoder, TextDecoder } from 'util';

if (typeof global.TextEncoder === 'undefined') {
  global.TextEncoder = TextEncoder;
}
if (typeof global.TextDecoder === 'undefined') {
  global.TextDecoder = TextDecoder;
}