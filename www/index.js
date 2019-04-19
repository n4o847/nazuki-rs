const nazuki = import('nazuki');

nazuki
  .then(m => {
    m.greet('world');
  })
  .catch(console.error);
