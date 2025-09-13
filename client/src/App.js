import React from 'react';
import logo from './logo.svg';
import './App.css';
import { BrowserRouter as Router, Routes, Route, Link } from 'react-router-dom';
import OtherPage from './OtherPage';
import Fib from './Fib';

function App() {
  return (
    <Router>
      <div className="App">
        <header className="App-header">
          <img src={logo} className="App-logo" alt="logo" />
          <h1 className="App-title">Fib Calculator version Kubernetes!</h1>
          <Link to="/">Home</Link>
          <Link to="/otherpage">Other Page</Link>
        </header>
        <div>
          <Routes>
            <Route path="/" element={<Fib />} />
            <Route path="/otherpage" element={<OtherPage />} />
          </Routes>
        </div>
      </div>
    </Router>
  );
}

export default App;
