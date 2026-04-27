import React, { useState, useEffect } from 'react';
import axios from 'axios';
 
function App() {
  const [users, setUsers] = useState([]);  // Store list of users
  const [name, setName] = useState('');    // Store new user name input
 
  // Load users when page opens
  useEffect(() => {
    axios.get('http://localhost:3000/users')
      .then(res => setUsers(res.data));
  }, []);
 
  // Add a new user
  const addUser = async () => {
    const res = await axios.post('http://localhost:3000/users', { name });
    setUsers([...users, res.data]);  // Add to list
    setName('');                     // Clear input
  };
 
  return (
    <div>
      <h1>User Manager</h1>
      <input
        value={name}
        onChange={e => setName(e.target.value)}
        placeholder="Enter user name"
      />
      <button onClick={addUser}>Add User</button>
      <ul>
        {users.map(user => <li key={user.id}>{user.name}</li>)}
      </ul>
    </div>
  );
}
 
export default App;